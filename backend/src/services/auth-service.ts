import { users } from '@prisma/client';
import admin from '../config/firebase';
import { env } from '../config/env';
import { prisma } from '../db/prisma-client';
import { UserRepository } from '../repositories/user-repository';
import { conflict, forbidden, unauthorized } from '../utils/errors';
import { AuthVerifier } from './auth/auth-verifier';
import { LoginInput, RegisterInput } from './auth/types';
import { PermanentChatService } from './permanent-chat-service';
import { SpeedDatingService } from './speed-dating-service';
import { deleteFilesByPrefix } from './storage.service';
import { socketServer } from '../websocket/socket-server';

export class AuthService {
  private readonly permanentChatService = new PermanentChatService();
  private readonly speedDatingService = new SpeedDatingService();

  constructor(
    private readonly userRepository: UserRepository,
    private readonly authVerifier: AuthVerifier,
  ) {}

  async register(input: RegisterInput): Promise<users> {
    const identity = await this.authVerifier.verifyIdToken(input.idToken, input.provider);

    const byUid = await this.userRepository.findByFirebaseUid(identity.uid);
    if (byUid) {
      conflict('User already exists', 'USER_ALREADY_EXISTS');
    }

    const byEmail = await this.userRepository.findByEmail(identity.email);
    if (byEmail) {
      conflict('Email already registered', 'EMAIL_ALREADY_EXISTS');
    }

    const created = await this.userRepository.createFromIdentity(identity);
    return created;
  }

  async login(input: LoginInput): Promise<users> {
    const identity = await this.authVerifier.verifyIdToken(input.idToken, input.provider);

    let user = await this.userRepository.findByFirebaseUid(identity.uid);
    if (!user) {
      const byEmail = await this.userRepository.findByEmail(identity.email);
      if (!byEmail) {
        user = await this.userRepository.createFromIdentity(identity);
      } else if (!byEmail.firebase_uid) {
        user = await this.userRepository.linkFirebaseIdentity(byEmail.id, identity);
      } else {
        user = byEmail;
      }
    }

    if (!user) {
      unauthorized('Unable to login with provided token', 'LOGIN_FAILED');
    }

    if (user.is_banned) {
      forbidden('User is banned', 'USER_BANNED');
    }

    await this.userRepository.touchLastActive(user.id);
    return user;
  }

  async me(idToken: string): Promise<users> {
    const identity = await this.authVerifier.verifyIdToken(idToken);
    const user = (await this.userRepository.findByFirebaseUid(identity.uid))
      ?? (await this.userRepository.findByEmail(identity.email));

    if (!user) {
      unauthorized('User not found', 'USER_NOT_FOUND');
    }

    if (user.is_banned) {
      forbidden('User is banned', 'USER_BANNED');
    }

    return user;
  }

  async logout(_idToken: string): Promise<void> {
    return;
  }

  async deleteAccount(idToken: string): Promise<void> {
    const identity = await this.authVerifier.verifyIdToken(idToken);
    const user = (await this.userRepository.findByFirebaseUid(identity.uid))
      ?? (await this.userRepository.findByEmail(identity.email));

    if (!user) {
      unauthorized('User not found', 'USER_NOT_FOUND');
    }

    const permanentMatchRows = await prisma.matches.findMany({
      where: {
        OR: [{ user_a_id: user.id }, { user_b_id: user.id }],
      },
      select: {
        id: true,
        user_a_id: true,
        user_b_id: true,
      },
    });

    const speedDatingSessionRows = await prisma.speed_dating_sessions.findMany({
      where: {
        OR: [{ user_a_id: user.id }, { user_b_id: user.id }],
      },
      select: {
        id: true,
        user_a_id: true,
        user_b_id: true,
      },
    });

    socketServer.disconnectUser(user.id);
    await this.userRepository.deleteById(user.id);

    const counterpartIds = new Set<string>();

    for (const match of permanentMatchRows) {
      const counterpartId = match.user_a_id === user.id ? match.user_b_id : match.user_a_id;
      if (!counterpartId) continue;

      counterpartIds.add(counterpartId);
      if (socketServer.getIO()) {
        socketServer.notifyUser(counterpartId, 'permanent.match.removed', {
          v: 1,
          data: {
            matchId: match.id,
          },
        });
      }
    }

    for (const session of speedDatingSessionRows) {
      const counterpartId = session.user_a_id === user.id ? session.user_b_id : session.user_a_id;
      if (!counterpartId) continue;

      counterpartIds.add(counterpartId);
      if (socketServer.getIO()) {
        socketServer.notifyUser(counterpartId, 'speed_dating.session.ended', {
          v: 1,
          data: {
            sessionId: session.id,
          },
        });
      }
    }

    const storageCleanup = await deleteFilesByPrefix(`users/${user.id}/photos/`);
    if (storageCleanup.failedPaths.length > 0) {
      console.warn('Some user photo files could not be deleted during account removal', {
        userId: user.id,
        attemptedCount: storageCleanup.attemptedCount,
        deletedCount: storageCleanup.deletedCount,
        failedPaths: storageCleanup.failedPaths,
      });
    }


    await this.publishBadgeUpdatesForUsers(counterpartIds);
    if (env.authProviderMode === 'firebase') {
      try {
        await admin.auth().deleteUser(identity.uid);
      } catch (error) {
        console.error('Failed to delete Firebase auth user during account removal', {
          userId: user.id,
          firebaseUid: identity.uid,
          error,
        });
      }
    }
  }

  private async publishBadgeUpdatesForUsers(userIds: Set<string>): Promise<void> {
    await Promise.all(
      [...userIds].map(async (targetUserId) => {
        const [speedDatingUnread, matchesUnread] = await Promise.all([
          this.speedDatingService.getUnreadCount(targetUserId),
          this.permanentChatService.getUnreadCount(targetUserId),
        ]);

        if (socketServer.getIO()) {
          socketServer.notifyUser(targetUserId, 'chat.badge.updated', {
            v: 1,
            data: {
              speedDatingUnread,
              matchesUnread,
              totalUnread: speedDatingUnread + matchesUnread,
            },
          });
        }
      }),
    );
  }
}
