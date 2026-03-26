import { Request, Response } from 'express';
import { UserRepository } from '../repositories/user-repository';
import { MatchmakingService } from '../services/matchmaking-service';
import { chatWebSocketBroker } from '../realtime/chat-websocket';
import { unauthorized } from '../utils/errors';

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
      chatWebSocketBroker.publishMatchingQueueMatched({
        recipientUserIds: [user.id, counterpartUserId],
        payload: {
          state: 'matched',
          sessionId: result.sessionId,
          sessionExpiresAt: result.sessionExpiresAt,
          participantUserIds: [user.id, counterpartUserId],
          queueJoinedAt: result.queueJoinedAt,
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
}
