import { Request, Response } from 'express';
import { UserRepository } from '../repositories/user-repository';
import { SpeedDatingService } from '../services/speed-dating-service';
import { PermanentChatService } from '../services/permanent-chat-service';
import { chatWebSocketBroker } from '../realtime/chat-websocket';
import { badRequest, unauthorized } from '../utils/errors';

export class SpeedDatingController {
  constructor(
    private readonly speedDatingService: SpeedDatingService,
    private readonly permanentChatService: PermanentChatService,
    private readonly userRepository: UserRepository,
  ) {}

  listSessions = async (req: Request, res: Response): Promise<void> => {
    const userId = await this.resolveUserId(req);
    const sessions = await this.speedDatingService.listSessions(userId);

    res.status(200).json({
      success: true,
      data: {
        sessions,
      },
    });
  };

  getSessionDetail = async (req: Request, res: Response): Promise<void> => {
    const userId = await this.resolveUserId(req);
    const sessionId = this.readSessionId(req.params.sessionId);

    const session = await this.speedDatingService.getSessionDetail(userId, sessionId);

    res.status(200).json({
      success: true,
      data: {
        session,
      },
    });
  };

  getSessionMessages = async (req: Request, res: Response): Promise<void> => {
    const userId = await this.resolveUserId(req);
    const sessionId = this.readSessionId(req.params.sessionId);

    const result = await this.speedDatingService.getSessionMessages(userId, sessionId);

    res.status(200).json({
      success: true,
      data: result,
    });
  };

  markSessionMessagesRead = async (req: Request, res: Response): Promise<void> => {
    const userId = await this.resolveUserId(req);
    const sessionId = this.readSessionId(req.params.sessionId);

    const session = await this.speedDatingService.markSessionMessagesRead(userId, sessionId);

    chatWebSocketBroker.publishSpeedDatingReadUpdated({
      recipientUserIds: [userId, session.counterpart.userId],
      payload: { session },
    });
    await this.publishBadgeUpdates([userId, session.counterpart.userId]);

    res.status(200).json({
      success: true,
      data: {
        session,
      },
    });
  };

  sendMessage = async (req: Request, res: Response): Promise<void> => {
    const userId = await this.resolveUserId(req);
    const sessionId = this.readSessionId(req.params.sessionId);

    if (typeof req.body?.content !== 'string') {
      badRequest('Message content is required', 'MISSING_MESSAGE_CONTENT');
    }

    const result = await this.speedDatingService.sendMessage(userId, sessionId, req.body.content);

    chatWebSocketBroker.publishSpeedDatingMessage({
      recipientUserIds: [userId, result.session.counterpart.userId],
      payload: result,
    });
    await this.publishBadgeUpdates([userId, result.session.counterpart.userId]);

    res.status(201).json({
      success: true,
      data: result,
    });
  };

  requestMoveToPermanent = async (req: Request, res: Response): Promise<void> => {
    const userId = await this.resolveUserId(req);
    const sessionId = this.readSessionId(req.params.sessionId);

    const result = await this.speedDatingService.requestMoveToPermanent(userId, sessionId);

    chatWebSocketBroker.publishSpeedDatingMoveToPermanentUpdated({
      recipientUserIds: [userId, result.session.counterpart.userId],
      payload: result,
    });
    await this.publishBadgeUpdates([userId, result.session.counterpart.userId]);

    res.status(200).json({
      success: true,
      data: result,
    });
  };

  respondToMoveToPermanent = async (req: Request, res: Response): Promise<void> => {
    const userId = await this.resolveUserId(req);
    const sessionId = this.readSessionId(req.params.sessionId);

    if (typeof req.body?.accept !== 'boolean') {
      badRequest('accept must be a boolean', 'INVALID_MOVE_TO_PERMANENT_RESPONSE');
    }

    const result = await this.speedDatingService.respondToMoveToPermanent(
      userId,
      sessionId,
      req.body.accept,
    );

    chatWebSocketBroker.publishSpeedDatingMoveToPermanentUpdated({
      recipientUserIds: [userId, result.session.counterpart.userId],
      payload: result,
    });
    await this.publishBadgeUpdates([userId, result.session.counterpart.userId]);

    res.status(200).json({
      success: true,
      data: result,
    });
  };

  submitFinalDecision = async (req: Request, res: Response): Promise<void> => {
    const userId = await this.resolveUserId(req);
    const sessionId = this.readSessionId(req.params.sessionId);

    if (typeof req.body?.decision !== 'string') {
      badRequest('decision must be yes or no', 'INVALID_FINAL_DECISION');
    }

    const result = await this.speedDatingService.submitFinalDecision(
      userId,
      sessionId,
      req.body.decision,
    );

    chatWebSocketBroker.publishSpeedDatingFinalDecisionUpdated({
      recipientUserIds: [userId, result.session.counterpart.userId],
      payload: result,
    });
    await this.publishBadgeUpdates([userId, result.session.counterpart.userId]);

    res.status(200).json({
      success: true,
      data: result,
    });
  };

  endSession = async (req: Request, res: Response): Promise<void> => {
    const userId = await this.resolveUserId(req);
    const sessionId = this.readSessionId(req.params.sessionId);

    const result = await this.speedDatingService.endSession(userId, sessionId);

    chatWebSocketBroker.publishSpeedDatingEnded({
      recipientUserIds: [userId, result.session.counterpart.userId],
      payload: result,
    });
    await this.publishBadgeUpdates([userId, result.session.counterpart.userId]);

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

  private readSessionId(value: unknown): string {
    if (typeof value !== 'string' || value.trim().length === 0) {
      badRequest('sessionId is required', 'MISSING_SESSION_ID');
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

        chatWebSocketBroker.publishChatBadgeUpdated({
          recipientUserIds: [targetUserId],
          payload: {
            speedDatingUnread,
            matchesUnread,
            totalUnread: speedDatingUnread + matchesUnread,
          },
        });
      }),
    );
  }
}
