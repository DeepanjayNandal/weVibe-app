import { Request, Response } from 'express';
import { UserRepository } from '../repositories/user-repository';
import { SpeedDatingService, SessionEndedReason } from '../services/speed-dating-service';
import { PermanentChatService } from '../services/permanent-chat-service';
import { socketServer } from '../websocket/socket-server';
import { notificationService } from '../services/notification-service';
import { badRequest, unauthorized } from '../utils/errors';
import { prisma } from '../db/prisma-client';

type SessionEndedPayload = {
  sessionId: string;
  reason: SessionEndedReason;
  matchId?: string;
  endedByUserId?: string;
};

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
        sessions: sessions.map((session) => ({
          sessionId: session.sessionId,
          sessionExpiresAt: session.expiresAt,
          status: session.status,
          lastMessageContent: session.lastMessageContent,
          lastMessageAt: session.lastMessageAt,
          isLastMessageMine: session.isLastMessageMine,
          unreadCount: session.unreadCount,
          counterpart: session.counterpart,
        })),
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

    // Get the last read message ID for the event
    const lastReadMessage = await this.getLastReadMessageInSession(sessionId, userId);
    const lastReadMessageId = lastReadMessage?.id || '';

    // Notify counterpart about the read update
    socketServer.notifyUser(session.counterpart.userId || '', 'speed_dating.session.read_updated', {
      v: 1,
      data: {
        sessionId,
        lastReadMessageId,
        readByUserId: userId,
      },
    });

    await this.publishBadgeUpdates([userId, session.counterpart.userId]);

    res.status(200).json({
      success: true,
      data: {
        session,
      },
    });
  };

  private async getLastReadMessageInSession(
    sessionId: string,
    userId: string,
  ): Promise<{ id: string } | null> {
    const result = await prisma.speed_dating_messages.findFirst({
      where: {
        session_id: sessionId,
        sender_id: { not: userId },
        read_at: { not: null },
      },
      select: { id: true },
      orderBy: { read_at: 'desc' },
    });

    // Convert BigInt id to string if needed
    return result ? { id: result.id.toString() } : null;
  };

  sendMessage = async (req: Request, res: Response): Promise<void> => {
    const userId = await this.resolveUserId(req);
    const sessionId = this.readSessionId(req.params.sessionId);

    if (typeof req.body?.content !== 'string') {
      badRequest('Message content is required', 'MISSING_MESSAGE_CONTENT');
    }

    const result = await this.speedDatingService.sendMessage(userId, sessionId, req.body.content);

    // Notify counterpart only (not the sender)
    const counterpartId = result.session.counterpart.userId;
    if (counterpartId) {
      socketServer.notifyUser(counterpartId, 'speed_dating.message.created', {
        v: 1,
        data: {
          sessionId,
          message: {
            id: result.message.id,
            content: result.message.content,
            senderId: result.message.senderId,
            createdAt: result.message.createdAt?.toISOString() || new Date().toISOString(),
          },
        },
      });
      void notificationService.sendPushToUser(
        counterpartId,
        'New message',
        result.message.content,
        { type: 'speed_dating_message', sessionId },
      );
    }

    await this.publishBadgeUpdates([userId, counterpartId]);

    res.status(201).json({
      success: true,
      data: result,
    });
  };

  requestMoveToPermanent = async (req: Request, res: Response): Promise<void> => {
    const userId = await this.resolveUserId(req);
    const sessionId = this.readSessionId(req.params.sessionId);

    const result = await this.speedDatingService.requestMoveToPermanent(userId, sessionId);

    const counterpartId = result.session.counterpart.userId;

    if (counterpartId) {
      socketServer.notifyUser(counterpartId, 'speed_dating.session.move_to_permanent_requested', {
        v: 1,
        data: {
          sessionId,
          requestedByUserId: userId,
        },
      });
    }

    await this.publishBadgeUpdates([userId, counterpartId]);

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

    const counterpartId = result.session.counterpart.userId;

    if (result.endedReason === 'graduated' && result.match?.matchId) {
      this.emitSessionEnded([userId, counterpartId], {
        sessionId,
        reason: 'graduated',
        matchId: result.match.matchId,
      });
    } else if (counterpartId) {
      socketServer.notifyUser(counterpartId, 'speed_dating.session.move_to_permanent_responded', {
        v: 1,
        data: {
          sessionId,
          respondedByUserId: userId,
          accepted: false,
        },
      });
    }

    await this.publishBadgeUpdates([userId, counterpartId]);

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

    const normalizedDecision = req.body.decision.trim().toLowerCase();
    if (normalizedDecision !== 'yes' && normalizedDecision !== 'no') {
      badRequest('decision must be yes or no', 'INVALID_FINAL_DECISION');
    }

    const result = await this.speedDatingService.submitFinalDecision(
      userId,
      sessionId,
      normalizedDecision,
    );

    const counterpartId = result.session.counterpart.userId;

    if (result.endedReason) {
      this.emitSessionEnded([userId, counterpartId], {
        sessionId,
        reason: result.endedReason,
        matchId: result.match?.matchId,
      });
    } else if (counterpartId) {
      socketServer.notifyUser(counterpartId, 'speed_dating.session.final_decision_updated', {
        v: 1,
        data: {
          sessionId,
          userId,
          decision: normalizedDecision,
        },
      });
    }

    await this.publishBadgeUpdates([userId, counterpartId]);

    res.status(200).json({
      success: true,
      data: result,
    });
  };

  endSession = async (req: Request, res: Response): Promise<void> => {
    const userId = await this.resolveUserId(req);
    const sessionId = this.readSessionId(req.params.sessionId);

    const result = await this.speedDatingService.endSession(userId, sessionId);

    const counterpartId = result.session.counterpart.userId;
    this.emitSessionEnded([userId, counterpartId], {
      sessionId,
      reason: 'ended_early',
      endedByUserId: result.endedByUserId ?? userId,
    });

    await this.publishBadgeUpdates([userId, counterpartId]);

    res.status(200).json({
      success: true,
      data: result,
    });
  };

  private emitSessionEnded(
    userIds: Array<string | null | undefined>,
    payload: SessionEndedPayload,
  ): void {
    const seen = new Set<string>();
    const data: Record<string, unknown> = {
      sessionId: payload.sessionId,
      reason: payload.reason,
    };
    if (payload.matchId) {
      data.matchId = payload.matchId;
    }
    if (payload.endedByUserId) {
      data.endedByUserId = payload.endedByUserId;
    }

    for (const id of userIds) {
      if (!id || seen.has(id)) continue;
      seen.add(id);
      socketServer.notifyUser(id, 'speed_dating.session.ended', {
        v: 1,
        data,
      });
    }
  }

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
