import { Request, Response } from 'express';
import { UserRepository } from '../repositories/user-repository';
import { MatchmakingService } from '../services/matchmaking-service';
import { socketServer } from '../websocket/socket-server';
import { unauthorized } from '../utils/errors';
import { prisma } from '../db/prisma-client';

export class MatchmakingController {
  constructor(
    private readonly matchmakingService: MatchmakingService,
    private readonly userRepository: UserRepository,
  ) {}

  joinQueue = async (req: Request, res: Response): Promise<void> => {
    const firebaseUid = req.auth?.uid;
    if (!firebaseUid) {
      unauthorized('User identity not found in request', 'MISSING_USER_IDENTITY');
    }

    const user = await this.userRepository.findByFirebaseUid(firebaseUid);
    if (!user) {
      unauthorized('User not found in database', 'USER_NOT_FOUND');
    }

    const result = await this.matchmakingService.joinQueueAndMatch(user.id);

    if (result.state === 'matched') {
      const counterpartUserId = result.selectedCandidate.userId;
      // Notify waiting user (counterpart) about the match
      socketServer.notifyUser(counterpartUserId, 'matching.queue.matched', {
        v: 1,
        data: {
          sessionId: result.sessionId,
          sessionExpiresAt: result.sessionExpiresAt,
        },
      });
    }

    res.status(200).json({
      success: true,
      data: result,
    });
  };

  leaveQueue = async (req: Request, res: Response): Promise<void> => {
    const firebaseUid = req.auth?.uid;
    if (!firebaseUid) {
      unauthorized('User identity not found in request', 'MISSING_USER_IDENTITY');
    }

    const user = await this.userRepository.findByFirebaseUid(firebaseUid);
    if (!user) {
      unauthorized('User not found in database', 'USER_NOT_FOUND');
    }

    await this.matchmakingService.leaveQueue(user.id);

    res.status(200).json({
      success: true,
      data: {
        state: 'left_queue',
      },
    });
  };

  getQueueStatus = async (req: Request, res: Response): Promise<void> => {
    const firebaseUid = req.auth?.uid;
    if (!firebaseUid) {
      unauthorized('User identity not found in request', 'MISSING_USER_IDENTITY');
    }

    const user = await this.userRepository.findByFirebaseUid(firebaseUid);
    if (!user) {
      unauthorized('User not found in database', 'USER_NOT_FOUND');
    }

    const status = await this.matchmakingService.getQueueStatus(user.id);

    res.status(200).json({
      success: true,
      data: status,
    });
  };

  listSessions = async (req: Request, res: Response): Promise<void> => {
    const firebaseUid = req.auth?.uid;
    if (!firebaseUid) {
      unauthorized('User identity not found in request', 'MISSING_USER_IDENTITY');
    }

    const user = await this.userRepository.findByFirebaseUid(firebaseUid);
    if (!user) {
      unauthorized('User not found in database', 'USER_NOT_FOUND');
    }

    const sessions = await prisma.speed_dating_sessions.findMany({
      where: {
        OR: [{ user_a_id: user.id }, { user_b_id: user.id }],
        status: 'active',
      },
      select: {
        id: true,
        expires_at: true,
        status: true,
      },
      orderBy: {
        started_at: 'desc',
      },
    });

    res.status(200).json({
      success: true,
      data: {
        sessions: sessions.map((session) => ({
          sessionId: session.id,
          sessionExpiresAt: session.expires_at,
          status: session.status,
        })),
      },
    });
  };
}
