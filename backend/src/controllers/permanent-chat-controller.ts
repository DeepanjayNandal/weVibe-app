import { Request, Response } from 'express';
import { UserRepository } from '../repositories/user-repository';
import { PermanentChatService } from '../services/permanent-chat-service';
import { SpeedDatingService } from '../services/speed-dating-service';
import { socketServer } from '../websocket/socket-server';
import { notificationService } from '../services/notification-service';
import { badRequest, unauthorized } from '../utils/errors';
import { prisma } from '../db/prisma-client';
import { generateReadURL } from '../services/storage.service';

export class PermanentChatController {
  constructor(
    private readonly permanentChatService: PermanentChatService,
    private readonly speedDatingService: SpeedDatingService,
    private readonly userRepository: UserRepository,
  ) {}

  listMatches = async (req: Request, res: Response): Promise<void> => {
    const userId = await this.resolveUserId(req);
    const matches = await this.permanentChatService.listMatches(userId);

    res.status(200).json({
      success: true,
      data: {
        matches,
      },
    });
  };

  getMatchDetail = async (req: Request, res: Response): Promise<void> => {
    const userId = await this.resolveUserId(req);
    const matchId = this.readMatchId(req.params.matchId);
    const match = await this.permanentChatService.getMatchDetail(userId, matchId);

    res.status(200).json({
      success: true,
      data: {
        match,
      },
    });
  };

  getMatchMessages = async (req: Request, res: Response): Promise<void> => {
    const userId = await this.resolveUserId(req);
    const matchId = this.readMatchId(req.params.matchId);

    const before = typeof req.query.before === 'string' ? req.query.before : undefined;
    const limitRaw = typeof req.query.limit === 'string' ? parseInt(req.query.limit, 10) : undefined;
    const limit = limitRaw && limitRaw > 0 && limitRaw <= 100 ? limitRaw : 30;

    const result = await this.permanentChatService.getMatchMessages(userId, matchId, { before, limit });

    res.status(200).json({
      success: true,
      data: result,
    });
  };

  markMatchMessagesRead = async (req: Request, res: Response): Promise<void> => {
    const userId = await this.resolveUserId(req);
    const matchId = this.readMatchId(req.params.matchId);
    const match = await this.permanentChatService.markMatchMessagesRead(userId, matchId);

    // Get the last read message ID for the event
    const lastReadMessage = await this.getLastReadMessageInMatch(matchId, userId);
    const lastReadMessageId = lastReadMessage?.id || '';

    // Notify counterpart about the read update
    socketServer.notifyUser(match.counterpart.userId || '', 'permanent.match.read_updated', {
      v: 1,
      data: {
        matchId,
        lastReadMessageId,
        readByUserId: userId,
      },
    });
    await this.publishBadgeUpdates([userId, match.counterpart.userId]);

    res.status(200).json({
      success: true,
      data: {
        match,
      },
    });
  };

  private async getLastReadMessageInMatch(
    matchId: string,
    userId: string,
  ): Promise<{ id: string } | null> {
    const result = await prisma.messages.findFirst({
      where: {
        match_id: matchId,
        sender_id: { not: userId },
        read_at: { not: null },
      },
      select: { id: true },
      orderBy: { read_at: 'desc' },
    });

    // Convert BigInt id to string if needed
    return result ? { id: result.id.toString() } : null;
  };

  getMatchProfile = async (req: Request, res: Response): Promise<void> => {
    const userId = await this.resolveUserId(req);
    const matchId = this.readMatchId(req.params.matchId);

    // Get match details to verify access and get counterpart
    const match = await this.permanentChatService.getMatchDetail(userId, matchId);
    if (!match || match.status !== 'active') {
      badRequest('Match not found or not active', 'MATCH_NOT_FOUND');
    }

    // Get counterpart's profile
    const counterpartId = match.counterpart.userId;
    if (!counterpartId) {
      badRequest('Match counterpart not found', 'COUNTERPART_NOT_FOUND');
    }

    const profile = await prisma.profiles.findUnique({
      where: { user_id: counterpartId }
    });
    if (!profile) {
      badRequest('Profile not found', 'PROFILE_NOT_FOUND');
    }

    // Build an array of signed photo URLs for the iOS client, which expects [String].
    // DB photos are stored as { id, storagePath, order, createdAt } objects (standard
    // upload flow). Manually created test users may only have { id, url } without
    // storagePath — in that case we return the stored URL as-is (best effort).
    const rawPhotos = Array.isArray(profile.photos) ? (profile.photos as unknown[]) : [];
    const photoEntries = await Promise.all(
      rawPhotos.map(async (item: unknown): Promise<string | null> => {
        if (!item || typeof item !== 'object') return null;
        const p = item as Record<string, unknown>;
        // Standard path: regenerate a fresh signed URL from storagePath
        if (typeof p.storagePath === 'string' && p.storagePath.trim()) {
          return generateReadURL(p.storagePath);
        }
        // Fallback for manually-created users with no storagePath
        if (typeof p.url === 'string' && p.url.trim()) {
          return p.url;
        }
        return null;
      }),
    );
    const photos = photoEntries.filter((u): u is string => u !== null);

    res.status(200).json({
      success: true,
      data: {
        profile: {
          ...profile,
          photos,
        },
      },
    });
  };

  sendMessage = async (req: Request, res: Response): Promise<void> => {
    const userId = await this.resolveUserId(req);
    const matchId = this.readMatchId(req.params.matchId);

    if (typeof req.body?.content !== 'string') {
      badRequest('Message content is required', 'MISSING_MESSAGE_CONTENT');
    }

    const result = await this.permanentChatService.sendMessage(userId, matchId, req.body.content);

    // Notify counterpart only (not the sender)
    const counterpartId = result.match.counterpart.userId;
    if (counterpartId) {
      socketServer.notifyUser(counterpartId, 'permanent.message.created', {
        v: 1,
        data: {
          matchId,
          message: {
            id: result.message.id,
            content: result.message.content,
            senderId: result.message.senderId,
            createdAt: result.message.createdAt?.toISOString() || new Date().toISOString(),
          },
        },
      });
      const senderProfile = await prisma.profiles.findUnique({
        where: { user_id: userId },
        select: { display_name: true },
      });
      const senderName = senderProfile?.display_name ?? 'Someone';
      void notificationService.sendPushToUser(
        counterpartId,
        senderName,
        result.message.content,
        { type: 'permanent_message', matchId },
        `match_${matchId}`,
      );
    }

    await this.publishBadgeUpdates([userId, counterpartId]);

    res.status(201).json({
      success: true,
      data: result,
    });
  };

  removeMatch = async (req: Request, res: Response): Promise<void> => {
    const userId = await this.resolveUserId(req);
    const matchId = this.readMatchId(req.params.matchId);
    const result = await this.permanentChatService.removeMatch(userId, matchId);

    // Notify counterpart
    socketServer.notifyUser(result.counterpartUserId || '', 'permanent.match.removed', {
      v: 1,
      data: {
        matchId,
      },
    });
    await this.publishBadgeUpdates([userId, result.counterpartUserId]);

    res.status(200).json({
      success: true,
      data: result,
    });
  };

  blockCounterpart = async (req: Request, res: Response): Promise<void> => {
    const userId = await this.resolveUserId(req);
    const matchId = this.readMatchId(req.params.matchId);
    const result = await this.permanentChatService.blockCounterpart(userId, matchId, req.body?.reason);

    // Notify counterpart
    socketServer.notifyUser(result.counterpartUserId || '', 'permanent.match.blocked', {
      v: 1,
      data: {
        matchId,
        blockedByUserId: userId,
      },
    });
    await this.publishBadgeUpdates([userId, result.counterpartUserId]);

    res.status(200).json({
      success: true,
      data: result,
    });
  };

  reportCounterpart = async (req: Request, res: Response): Promise<void> => {
    const userId = await this.resolveUserId(req);
    const matchId = this.readMatchId(req.params.matchId);
    const result = await this.permanentChatService.reportCounterpart(
      userId,
      matchId,
      req.body?.reason,
      req.body?.details,
    );

    // Notify counterpart
    socketServer.notifyUser(result.counterpartUserId || '', 'permanent.match.reported', {
      v: 1,
      data: {
        matchId,
      },
    });
    await this.publishBadgeUpdates([userId, result.counterpartUserId]);

    res.status(200).json({
      success: true,
      data: result,
    });
  };

  private async resolveUserId(req: Request): Promise<string> {
    const firebaseUid = req.auth?.uid;
    if (!firebaseUid) {
      unauthorized('User identity not found in request', 'MISSING_USER_IDENTITY');
    }

    const user = await this.userRepository.findByFirebaseUid(firebaseUid);
    if (!user) {
      unauthorized('User not found in database', 'USER_NOT_FOUND');
    }

    return user.id;
  }

  private readMatchId(value: unknown): string {
    if (typeof value !== 'string' || value.trim().length === 0) {
      badRequest('matchId is required', 'MISSING_MATCH_ID');
    }

    return value.trim();
  }

  private async publishBadgeUpdates(userIds: Array<string | null | undefined>): Promise<void> {
    const uniqueUserIds = [...new Set(userIds.filter((value): value is string => !!value))];

    await Promise.all(
      uniqueUserIds.map(async (targetUserId) => {
        const [speedDatingUnread, matchesUnread] = await Promise.all([
          this.speedDatingService.getUnreadCount(targetUserId),
          this.permanentChatService.getUnreadCount(targetUserId),
        ]);

        socketServer.notifyUser(targetUserId, 'chat.badge.updated', {
          v: 1,
          data: {
            speedDatingUnread,
            matchesUnread,
            totalUnread: speedDatingUnread + matchesUnread,
          },
        });
      }),
    );
  }
}
