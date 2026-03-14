import { Prisma, speed_dating_messages, speed_dating_sessions } from '@prisma/client';
import { prisma } from '../db/prisma-client';
import { AppError, badRequest } from '../utils/errors';
import {
  assertTwoPartyParticipant,
  getTwoPartyParticipantIds,
  isUserAInTwoParty,
} from './chat/two-party-access';

type SessionStatus = string | null;

type SessionWithProfiles = Prisma.speed_dating_sessionsGetPayload<{
  include: {
    users_speed_dating_sessions_user_a_idTousers: {
      include: {
        profiles: true;
      };
    };
    users_speed_dating_sessions_user_b_idTousers: {
      include: {
        profiles: true;
      };
    };
  };
}>;

export type SessionListItem = {
  sessionId: string;
  status: SessionStatus;
  startedAt: Date | null;
  expiresAt: Date | null;
  remainingSeconds: number;
  canOpen: boolean;
  canSendMessage: boolean;
  myMessageCount: number;
  otherMessageCount: number;
  messageLimit: number;
  counterpart: {
    userId: string | null;
    firstName: string | null;
    initials: string | null;
    blurredPhotoUrl: string | null;
  };
};

export type SessionDetail = SessionListItem;

export type MessagePayload = {
  id: string;
  sessionId: string;
  senderId: string;
  content: string;
  createdAt: Date | null;
};

export type SessionMessagesResult = {
  session: SessionDetail;
  messages: MessagePayload[];
};

export type SendMessageResult = {
  message: MessagePayload;
  session: SessionDetail;
};

const MESSAGE_LIMIT_PER_USER = 20;
const STATUS_ACTIVE = 'active';
const STATUS_AWAITING_DECISION = 'awaiting_decision';
const STATUS_EXPIRED = 'expired';

function normalizeSessionStatus(status: SessionStatus): SessionStatus {
  if (!status) return status;
  return status.trim().toLowerCase();
}

function isSessionOpenable(status: SessionStatus): boolean {
  const normalized = normalizeSessionStatus(status);
  return normalized === STATUS_ACTIVE || normalized === STATUS_AWAITING_DECISION;
}

function canSendForStatus(status: SessionStatus): boolean {
  return normalizeSessionStatus(status) === STATUS_ACTIVE;
}

function computeRemainingSeconds(expiresAt: Date | null): number {
  if (!expiresAt) return 0;
  return Math.max(0, Math.floor((expiresAt.getTime() - Date.now()) / 1000));
}

function extractFirstName(displayName: string | null | undefined): string | null {
  if (!displayName) return null;
  const first = displayName.trim().split(/\s+/)[0];
  return first || null;
}

function extractInitials(displayName: string | null | undefined): string | null {
  if (!displayName) return null;
  const words = displayName
    .trim()
    .split(/\s+/)
    .filter(Boolean);

  if (words.length === 0) return null;
  if (words.length === 1) return words[0][0]?.toUpperCase() ?? null;

  const first = words[0][0] ?? '';
  const last = words[words.length - 1][0] ?? '';
  const value = `${first}${last}`.toUpperCase();
  return value || null;
}

function extractBlurredPhotoUrl(photos: Prisma.JsonValue | null): string | null {
  if (!photos) return null;

  if (Array.isArray(photos)) {
    for (const item of photos) {
      if (typeof item === 'string' && item.trim().length > 0) {
        return item;
      }
      if (item && typeof item === 'object' && 'url' in item) {
        const maybeUrl = (item as { url?: unknown }).url;
        if (typeof maybeUrl === 'string' && maybeUrl.trim().length > 0) {
          return maybeUrl;
        }
      }
    }
  }

  return null;
}

function messageToPayload(message: speed_dating_messages): MessagePayload {
  return {
    id: String(message.id),
    sessionId: message.session_id ?? '',
    senderId: message.sender_id ?? '',
    content: message.content,
    createdAt: message.created_at,
  };
}

export class SpeedDatingService {
  async listSessions(userId: string): Promise<SessionListItem[]> {
    await this.expireUserSessions(userId);

    const sessions = await prisma.speed_dating_sessions.findMany({
      where: {
        OR: [{ user_a_id: userId }, { user_b_id: userId }],
      },
      include: {
        users_speed_dating_sessions_user_a_idTousers: {
          include: { profiles: true },
        },
        users_speed_dating_sessions_user_b_idTousers: {
          include: { profiles: true },
        },
      },
      orderBy: {
        started_at: 'desc',
      },
    });

    const ids = sessions.map((session) => session.id);
    const messageCountMap = await this.buildMessageCountMap(ids);

    return sessions.map((session) => this.toSessionListItem(session, userId, messageCountMap));
  }

  async getSessionDetail(userId: string, sessionId: string): Promise<SessionDetail> {
    const session = await this.getAuthorizedSession(userId, sessionId);

    await this.expireSessionIfNeeded(session);

    const refreshedSession = await this.getAuthorizedSession(userId, sessionId);
    const messageCountMap = await this.buildMessageCountMap([sessionId]);

    return this.toSessionListItem(refreshedSession, userId, messageCountMap);
  }

  async getSessionMessages(userId: string, sessionId: string): Promise<SessionMessagesResult> {
    const session = await this.getAuthorizedSession(userId, sessionId);

    await this.expireSessionIfNeeded(session);

    const refreshedSession = await this.getAuthorizedSession(userId, sessionId);

    const messages = await prisma.speed_dating_messages.findMany({
      where: { session_id: sessionId },
      orderBy: { created_at: 'asc' },
    });

    const messageCountMap = await this.buildMessageCountMap([sessionId]);

    return {
      session: this.toSessionListItem(refreshedSession, userId, messageCountMap),
      messages: messages.map(messageToPayload),
    };
  }

  async sendMessage(userId: string, sessionId: string, content: string): Promise<SendMessageResult> {
    const normalizedContent = content.trim();
    if (!normalizedContent) {
      badRequest('Message content is required', 'MISSING_MESSAGE_CONTENT');
    }

    return prisma.$transaction(async (tx) => {
      const session = await tx.speed_dating_sessions.findUnique({ where: { id: sessionId } });
      if (!session) {
        throw new AppError('Session not found', 404, 'SESSION_NOT_FOUND');
      }

      assertTwoPartyParticipant(session, userId);

      const expiredSession = await this.expireSessionIfNeeded(session, tx);
      const activeSession = expiredSession ?? session;
      const currentStatus = normalizeSessionStatus(activeSession.status);

      if (!canSendForStatus(currentStatus)) {
        badRequest('Session is not active for messaging', 'SESSION_NOT_ACTIVE');
      }

      const senderCount = await tx.speed_dating_messages.count({
        where: {
          session_id: sessionId,
          sender_id: userId,
        },
      });

      if (senderCount >= MESSAGE_LIMIT_PER_USER) {
        badRequest('Message limit reached for this session', 'MESSAGE_LIMIT_REACHED');
      }

      const message = await tx.speed_dating_messages.create({
        data: {
          session_id: sessionId,
          sender_id: userId,
          content: normalizedContent,
        },
      });

      const participantIds = getTwoPartyParticipantIds(activeSession);
      const [countA, countB] = await Promise.all([
        tx.speed_dating_messages.count({
          where: {
            session_id: sessionId,
            sender_id: participantIds.userAId,
          },
        }),
        tx.speed_dating_messages.count({
          where: {
            session_id: sessionId,
            sender_id: participantIds.userBId,
          },
        }),
      ]);

      if (countA >= MESSAGE_LIMIT_PER_USER && countB >= MESSAGE_LIMIT_PER_USER) {
        await tx.speed_dating_sessions.update({
          where: { id: sessionId },
          data: { status: STATUS_AWAITING_DECISION },
        });
      }

      const fullSession = await tx.speed_dating_sessions.findUnique({
        where: { id: sessionId },
        include: {
          users_speed_dating_sessions_user_a_idTousers: {
            include: { profiles: true },
          },
          users_speed_dating_sessions_user_b_idTousers: {
            include: { profiles: true },
          },
        },
      });

      if (!fullSession) {
        throw new AppError('Session not found after update', 404, 'SESSION_NOT_FOUND');
      }

      const countMap = await this.buildMessageCountMap([sessionId], tx);

      return {
        message: messageToPayload(message),
        session: this.toSessionListItem(fullSession, userId, countMap),
      };
    });
  }

  private async expireUserSessions(userId: string): Promise<void> {
    await prisma.speed_dating_sessions.updateMany({
      where: {
        OR: [{ user_a_id: userId }, { user_b_id: userId }],
        expires_at: { lte: new Date() },
        status: {
          in: [STATUS_ACTIVE, STATUS_AWAITING_DECISION],
        },
      },
      data: {
        status: STATUS_EXPIRED,
      },
    });
  }

  private async getAuthorizedSession(userId: string, sessionId: string): Promise<SessionWithProfiles> {
    const session = await prisma.speed_dating_sessions.findUnique({
      where: { id: sessionId },
      include: {
        users_speed_dating_sessions_user_a_idTousers: {
          include: { profiles: true },
        },
        users_speed_dating_sessions_user_b_idTousers: {
          include: { profiles: true },
        },
      },
    });

    if (!session) {
      throw new AppError('Session not found', 404, 'SESSION_NOT_FOUND');
    }

    assertTwoPartyParticipant(session, userId);

    return session;
  }

  private async expireSessionIfNeeded(
    session: speed_dating_sessions,
    db: Prisma.TransactionClient | typeof prisma = prisma,
  ): Promise<speed_dating_sessions | null> {
    const expiresAt = session.expires_at;
    const normalizedStatus = normalizeSessionStatus(session.status);

    if (!expiresAt || expiresAt.getTime() > Date.now()) {
      return null;
    }

    if (normalizedStatus !== STATUS_ACTIVE && normalizedStatus !== STATUS_AWAITING_DECISION) {
      return null;
    }

    return db.speed_dating_sessions.update({
      where: { id: session.id },
      data: { status: STATUS_EXPIRED },
    });
  }

  private async buildMessageCountMap(
    sessionIds: string[],
    db: Prisma.TransactionClient | typeof prisma = prisma,
  ): Promise<Map<string, Map<string, number>>> {
    const map = new Map<string, Map<string, number>>();

    if (sessionIds.length === 0) {
      return map;
    }

    const grouped = await db.speed_dating_messages.groupBy({
      by: ['session_id', 'sender_id'],
      where: {
        session_id: { in: sessionIds },
      },
      _count: {
        _all: true,
      },
    });

    for (const row of grouped) {
      const sessionId = row.session_id;
      const senderId = row.sender_id;
      if (!sessionId || !senderId) continue;

      if (!map.has(sessionId)) {
        map.set(sessionId, new Map<string, number>());
      }
      map.get(sessionId)?.set(senderId, row._count._all);
    }

    return map;
  }

  private toSessionListItem(
    session: SessionWithProfiles,
    userId: string,
    messageCountMap: Map<string, Map<string, number>>,
  ): SessionListItem {
    const participantIds = getTwoPartyParticipantIds(session);
    const isUserA = isUserAInTwoParty(session, userId);

    const myId = userId;
    const otherId = isUserA ? participantIds.userBId : participantIds.userAId;

    const counterpartUser = isUserA
      ? session.users_speed_dating_sessions_user_b_idTousers
      : session.users_speed_dating_sessions_user_a_idTousers;

    const countForSession = messageCountMap.get(session.id) ?? new Map<string, number>();
    const myMessageCount = countForSession.get(myId) ?? 0;
    const otherMessageCount = countForSession.get(otherId) ?? 0;

    const firstName = extractFirstName(counterpartUser?.profiles?.display_name);
    const initials = extractInitials(counterpartUser?.profiles?.display_name);
    const blurredPhotoUrl = extractBlurredPhotoUrl(counterpartUser?.profiles?.photos ?? null);

    const remainingSeconds = computeRemainingSeconds(session.expires_at);
    const sessionStatus = normalizeSessionStatus(session.status);

    const canSendMessage =
      canSendForStatus(sessionStatus) &&
      myMessageCount < MESSAGE_LIMIT_PER_USER &&
      remainingSeconds > 0;

    return {
      sessionId: session.id,
      status: sessionStatus,
      startedAt: session.started_at,
      expiresAt: session.expires_at,
      remainingSeconds,
      canOpen: isSessionOpenable(sessionStatus),
      canSendMessage,
      myMessageCount,
      otherMessageCount,
      messageLimit: MESSAGE_LIMIT_PER_USER,
      counterpart: {
        userId: counterpartUser?.id ?? null,
        firstName,
        initials,
        blurredPhotoUrl,
      },
    };
  }
}
