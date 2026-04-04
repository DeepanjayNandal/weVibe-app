import { Prisma, enum_decision, matches, speed_dating_messages, speed_dating_sessions } from '@prisma/client';
import { prisma } from '../db/prisma-client';
import { AppError, badRequest } from '../utils/errors';
import {
  assertTwoPartyParticipant,
  getTwoPartyParticipantIds,
  isUserAInTwoParty,
} from './chat/two-party-access';
import { socketServer } from '../websocket/socket-server';

type SessionStatus = string | null;
type DecisionValue = enum_decision | null;
type MoveRequestStatus = 'none' | 'sent' | 'received' | 'counter_available' | 'locked';

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
  unreadCount: number;
  myMessageCount: number;
  otherMessageCount: number;
  messageLimit: number;
  counterpart: {
    userId: string | null;
    firstName: string | null;
    initials: string | null;
    blurredPhotoUrl: string | null;
  };
  moveToPermanent: {
    myDecision: DecisionValue;
    otherDecision: DecisionValue;
    requestStatus: MoveRequestStatus;
    canRequest: boolean;
    canRespond: boolean;
    canSubmitFinalDecision: boolean;
  };
};

export type SessionDetail = SessionListItem;

export type MessagePayload = {
  id: string;
  sessionId: string;
  senderId: string;
  content: string;
  createdAt: Date | null;
  readAt: Date | null;
};

export type SessionMessagesResult = {
  session: SessionDetail;
  messages: MessagePayload[];
};

export type SendMessageResult = {
  message: MessagePayload;
  session: SessionDetail;
};

export type SpeedDatingActionResult = {
  session: SessionDetail;
  match: {
    matchId: string;
    status: string | null;
    messageCount: number;
  } | null;
};

const MESSAGE_LIMIT_PER_USER = 20;
const EXPIRED_SOFT_DELETE_GRACE_HOURS = 24;
const STATUS_ACTIVE = 'active';
const STATUS_ACTIVE_COUNTER_PENDING = 'active_counter_pending';
const STATUS_ACTIVE_REQUEST_LOCKED = 'active_request_locked';
const STATUS_AWAITING_DECISION = 'awaiting_decision';
const STATUS_AWAITING_COUNTER_DECISION = 'awaiting_counter_decision';
const STATUS_AWAITING_DECISION_LOCKED = 'awaiting_decision_locked';
const STATUS_GRADUATED = 'graduated';
const STATUS_EXPIRED = 'expired';
const STATUS_ARCHIVED = 'archived';
const STATUS_ENDED_EARLY = 'ended_early';

const DECISION_PENDING: enum_decision = 'pending';
const DECISION_YES: enum_decision = 'yes';
const DECISION_NO: enum_decision = 'no';

const ACTIVE_FLOW_STATUSES = [
  STATUS_ACTIVE,
  STATUS_ACTIVE_COUNTER_PENDING,
  STATUS_ACTIVE_REQUEST_LOCKED,
];

const AWAITING_FLOW_STATUSES = [
  STATUS_AWAITING_DECISION,
  STATUS_AWAITING_COUNTER_DECISION,
  STATUS_AWAITING_DECISION_LOCKED,
];

const OPENABLE_STATUSES = [...ACTIVE_FLOW_STATUSES, ...AWAITING_FLOW_STATUSES];
const EXPIRABLE_STATUSES = [...OPENABLE_STATUSES];

function isWithinExpiredGraceWindow(expiresAt: Date | null): boolean {
  if (!expiresAt) return false;
  const cutoff = Date.now() - EXPIRED_SOFT_DELETE_GRACE_HOURS * 60 * 60 * 1000;
  return expiresAt.getTime() >= cutoff;
}

function isVisibleInSpeedTab(status: SessionStatus, expiresAt: Date | null): boolean {
  const normalized = normalizeSessionStatus(status);
  if (!normalized) return false;

  if (ACTIVE_FLOW_STATUSES.includes(normalized)) {
    return true;
  }

  if (normalized === STATUS_EXPIRED) {
    return isWithinExpiredGraceWindow(expiresAt);
  }

  return false;
}

function normalizeSessionStatus(status: SessionStatus): SessionStatus {
  if (!status) return status;
  return status.trim().toLowerCase();
}

function normalizeDecision(decision: DecisionValue): DecisionValue {
  if (!decision) return decision;
  return decision.trim().toLowerCase() as enum_decision;
}

function parseDecisionInput(decision: string): DecisionValue {
  return decision.trim().toLowerCase() as enum_decision;
}

function toPublicSessionStatus(status: SessionStatus): SessionStatus {
  const normalized = normalizeSessionStatus(status);

  if (normalized && ACTIVE_FLOW_STATUSES.includes(normalized)) {
    return STATUS_ACTIVE;
  }

  if (normalized && AWAITING_FLOW_STATUSES.includes(normalized)) {
    return STATUS_AWAITING_DECISION;
  }

  return normalized;
}

function isSessionOpenable(status: SessionStatus): boolean {
  const normalized = normalizeSessionStatus(status);
  return normalized ? OPENABLE_STATUSES.includes(normalized) : false;
}

function canSendForStatus(status: SessionStatus): boolean {
  const normalized = normalizeSessionStatus(status);
  return normalized ? ACTIVE_FLOW_STATUSES.includes(normalized) : false;
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
    readAt: message.read_at,
  };
}

function toNumber(value: number | null | undefined): number {
  return value ?? 0;
}

function isAwaitingFlowStatus(status: SessionStatus): boolean {
  const normalized = normalizeSessionStatus(status);
  return normalized ? AWAITING_FLOW_STATUSES.includes(normalized) : false;
}

function buildMatchSummary(match: matches): SpeedDatingActionResult['match'] {
  return {
    matchId: match.id,
    status: match.status ?? null,
    messageCount: toNumber(match.message_count),
  };
}

export class SpeedDatingService {
  async listSessions(userId: string): Promise<SessionListItem[]> {
    await this.expireUserSessions(userId);

    const allSessions = await prisma.speed_dating_sessions.findMany({
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

    const sessions = allSessions.filter((session) =>
      isVisibleInSpeedTab(session.status, session.expires_at),
    );

    const ids = sessions.map((session) => session.id);
    const messageCountMap = await this.buildMessageCountMap(ids);
    const unreadCountMap = await this.buildUnreadCountMap(ids, userId);

    return sessions.map((session) =>
      this.toSessionListItem(session, userId, messageCountMap, unreadCountMap),
    );
  }

  async getSessionDetail(userId: string, sessionId: string): Promise<SessionDetail> {
    const session = await this.getAuthorizedSession(userId, sessionId);

    await this.expireSessionIfNeeded(session);

    const refreshedSession = await this.getAuthorizedSession(userId, sessionId);
    const messageCountMap = await this.buildMessageCountMap([sessionId]);
    const unreadCountMap = await this.buildUnreadCountMap([sessionId], userId);

    return this.toSessionListItem(refreshedSession, userId, messageCountMap, unreadCountMap);
  }

  async getSessionMessages(userId: string, sessionId: string): Promise<SessionMessagesResult> {
    return prisma.$transaction(async (tx) => {
      const session = await this.getAuthorizedSession(userId, sessionId, tx);

      await this.expireSessionIfNeeded(session, tx);

      const refreshedSession = await this.getAuthorizedSession(userId, sessionId, tx);

      const messages = await tx.speed_dating_messages.findMany({
        where: { session_id: sessionId },
        orderBy: { created_at: 'asc' },
      });

      const messageCountMap = await this.buildMessageCountMap([sessionId], tx);
      const unreadCountMap = await this.buildUnreadCountMap([sessionId], userId, tx);

      return {
        session: this.toSessionListItem(refreshedSession, userId, messageCountMap, unreadCountMap),
        messages: messages.map(messageToPayload),
      };
    });
  }

  async markSessionMessagesRead(userId: string, sessionId: string): Promise<SessionDetail> {
    return prisma.$transaction(async (tx) => {
      const session = await this.getAuthorizedSession(userId, sessionId, tx);
      await this.expireSessionIfNeeded(session, tx);

      await tx.speed_dating_messages.updateMany({
        where: {
          session_id: sessionId,
          sender_id: { not: userId },
          read_at: null,
        },
        data: {
          read_at: new Date(),
        },
      });

      const refreshedSession = await this.getAuthorizedSession(userId, sessionId, tx);
      const messageCountMap = await this.buildMessageCountMap([sessionId], tx);
      const unreadCountMap = await this.buildUnreadCountMap([sessionId], userId, tx);

      return this.toSessionListItem(refreshedSession, userId, messageCountMap, unreadCountMap);
    });
  }

  async getUnreadCount(userId: string): Promise<number> {
    await this.expireUserSessions(userId);

    const sessions = await prisma.speed_dating_sessions.findMany({
      where: {
        OR: [{ user_a_id: userId }, { user_b_id: userId }],
      },
      select: {
        id: true,
        status: true,
        expires_at: true,
      },
    });

    const visibleSessionIds = sessions
      .filter((session) => isVisibleInSpeedTab(session.status, session.expires_at))
      .map((session) => session.id);

    if (visibleSessionIds.length === 0) {
      return 0;
    }

    return prisma.speed_dating_messages.count({
      where: {
        session_id: { in: visibleSessionIds },
        sender_id: { not: userId },
        read_at: null,
      },
    });
  }

  async sendMessage(userId: string, sessionId: string, content: string): Promise<SendMessageResult> {
    const normalizedContent = content.trim();
    if (!normalizedContent) {
      badRequest('Message content is required', 'MISSING_MESSAGE_CONTENT');
    }

    let counterpartUserId = '';

    const result = await prisma.$transaction(async (tx) => {
      const session = await tx.speed_dating_sessions.findUnique({ where: { id: sessionId } });
      if (!session) {
        throw new AppError('Session not found', 404, 'SESSION_NOT_FOUND');
      }

      assertTwoPartyParticipant(session, userId);
      const participantIds = getTwoPartyParticipantIds(session);
      counterpartUserId = participantIds.userAId === userId ? participantIds.userBId : participantIds.userAId;

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
          data: {
            status: STATUS_AWAITING_DECISION,
            user_a_decision: DECISION_PENDING,
            user_b_decision: DECISION_PENDING,
          },
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

    // Immediately send real-time push notification via Socket.IO to counterpart after successful DB transaction
    if (counterpartUserId) {
      socketServer.notifyUser(counterpartUserId, 'speed_dating.message.created', {
        v: 1,
        data: {
          sessionId,
          message: result.message,
        },
      });
    }

    return result;
  }

  async requestMoveToPermanent(userId: string, sessionId: string): Promise<SpeedDatingActionResult> {
    return prisma.$transaction(async (tx) => {
      const session = await this.getAuthorizedSessionRecord(tx, userId, sessionId);
      const expiredSession = await this.expireSessionIfNeeded(session, tx);
      const activeSession = expiredSession ?? session;
      const internalStatus = normalizeSessionStatus(activeSession.status);

      const perspective = this.getDecisionPerspective(activeSession, userId);
      const moveState = this.toMoveToPermanentState(activeSession, userId);

      if (!moveState.canRequest) {
        badRequest('Move-to-permanent request is not allowed in the current session state', 'MOVE_TO_PERMANENT_NOT_ALLOWED');
      }

      let nextStatus = internalStatus;
      let nextMyDecision = DECISION_YES;
      let nextOtherDecision = DECISION_PENDING;

      if (
        (internalStatus === STATUS_ACTIVE || internalStatus === STATUS_AWAITING_DECISION) &&
        perspective.myDecision === DECISION_PENDING &&
        perspective.otherDecision === DECISION_PENDING
      ) {
        nextStatus = internalStatus;
      } else if (
        (internalStatus === STATUS_ACTIVE || internalStatus === STATUS_AWAITING_DECISION) &&
        perspective.myDecision === DECISION_NO &&
        perspective.otherDecision === DECISION_YES
      ) {
        nextStatus = internalStatus === STATUS_ACTIVE ? STATUS_ACTIVE_COUNTER_PENDING : STATUS_AWAITING_COUNTER_DECISION;
      } else {
        badRequest('Move-to-permanent request is not allowed in the current session state', 'MOVE_TO_PERMANENT_NOT_ALLOWED');
      }

      await tx.speed_dating_sessions.update({
        where: { id: sessionId },
        data: this.buildDecisionUpdateData(perspective.isUserA, nextMyDecision, nextOtherDecision, {
          status: nextStatus,
        }),
      });

      return this.buildActionResult(tx, userId, sessionId, null);
    });
  }

  async respondToMoveToPermanent(
    userId: string,
    sessionId: string,
    accept: boolean,
  ): Promise<SpeedDatingActionResult> {
    return prisma.$transaction(async (tx) => {
      const session = await this.getAuthorizedSessionRecord(tx, userId, sessionId);
      const expiredSession = await this.expireSessionIfNeeded(session, tx);
      const activeSession = expiredSession ?? session;
      const internalStatus = normalizeSessionStatus(activeSession.status);
      const perspective = this.getDecisionPerspective(activeSession, userId);
      const moveState = this.toMoveToPermanentState(activeSession, userId);

      if (!moveState.canRespond) {
        badRequest('There is no pending move-to-permanent request to respond to', 'MOVE_TO_PERMANENT_RESPONSE_NOT_ALLOWED');
      }

      if (accept) {
        const match = await this.graduateSession(tx, activeSession);
        return this.buildActionResult(tx, userId, sessionId, match);
      }

      if (internalStatus === STATUS_ACTIVE_COUNTER_PENDING) {
        await tx.speed_dating_sessions.update({
          where: { id: sessionId },
          data: this.buildDecisionUpdateData(perspective.isUserA, DECISION_NO, DECISION_NO, {
            status: STATUS_ACTIVE_REQUEST_LOCKED,
          }),
        });
      } else if (internalStatus === STATUS_AWAITING_COUNTER_DECISION) {
        await tx.speed_dating_sessions.update({
          where: { id: sessionId },
          data: this.buildDecisionUpdateData(perspective.isUserA, DECISION_NO, DECISION_NO, {
            status: STATUS_AWAITING_DECISION_LOCKED,
          }),
        });
      } else {
        await tx.speed_dating_sessions.update({
          where: { id: sessionId },
          data: this.buildDecisionUpdateData(perspective.isUserA, DECISION_NO, DECISION_YES, {
            status: isAwaitingFlowStatus(internalStatus) ? STATUS_AWAITING_DECISION : STATUS_ACTIVE,
          }),
        });
      }

      return this.buildActionResult(tx, userId, sessionId, null);
    });
  }

  async submitFinalDecision(
    userId: string,
    sessionId: string,
    decision: string,
  ): Promise<SpeedDatingActionResult> {
    const normalizedDecision = parseDecisionInput(decision);
    if (normalizedDecision !== DECISION_YES && normalizedDecision !== DECISION_NO) {
      badRequest('Decision must be yes or no', 'INVALID_FINAL_DECISION');
    }

    return prisma.$transaction(async (tx) => {
      const session = await this.getAuthorizedSessionRecord(tx, userId, sessionId);
      const expiredSession = await this.expireSessionIfNeeded(session, tx);
      const activeSession = expiredSession ?? session;
      const internalStatus = normalizeSessionStatus(activeSession.status);

      if (internalStatus !== STATUS_AWAITING_DECISION && internalStatus !== STATUS_AWAITING_DECISION_LOCKED) {
        badRequest('Final decision is only available after the session reaches its decision phase', 'FINAL_DECISION_NOT_ALLOWED');
      }

      const perspective = this.getDecisionPerspective(activeSession, userId);
      const moveState = this.toMoveToPermanentState(activeSession, userId);

      if (!moveState.canSubmitFinalDecision) {
        badRequest('Final decision cannot be changed while a move-to-permanent request is pending', 'FINAL_DECISION_NOT_ALLOWED');
      }

      const nextMyDecision = normalizedDecision;
      const nextOtherDecision = perspective.otherDecision;

      if (nextMyDecision === DECISION_YES && nextOtherDecision === DECISION_YES) {
        await tx.speed_dating_sessions.update({
          where: { id: sessionId },
          data: this.buildDecisionUpdateData(perspective.isUserA, DECISION_YES, DECISION_YES),
        });
        const refreshed = await tx.speed_dating_sessions.findUnique({ where: { id: sessionId } });
        if (!refreshed) {
          throw new AppError('Session not found after decision update', 404, 'SESSION_NOT_FOUND');
        }
        const match = await this.graduateSession(tx, refreshed);
        return this.buildActionResult(tx, userId, sessionId, match);
      }

      let nextStatus = internalStatus;
      if (nextMyDecision === DECISION_NO && nextOtherDecision === DECISION_NO) {
        nextStatus = STATUS_ARCHIVED;
      }

      await tx.speed_dating_sessions.update({
        where: { id: sessionId },
        data: this.buildDecisionUpdateData(perspective.isUserA, nextMyDecision, nextOtherDecision, {
          status: nextStatus,
        }),
      });

      return this.buildActionResult(tx, userId, sessionId, null);
    });
  }

  async endSession(userId: string, sessionId: string): Promise<SpeedDatingActionResult> {
    return prisma.$transaction(async (tx) => {
      const session = await this.getAuthorizedSessionRecord(tx, userId, sessionId);
      const expiredSession = await this.expireSessionIfNeeded(session, tx);
      const activeSession = expiredSession ?? session;
      const internalStatus = normalizeSessionStatus(activeSession.status);

      if (!internalStatus || !OPENABLE_STATUSES.includes(internalStatus)) {
        badRequest('Session cannot be ended in the current state', 'SESSION_END_NOT_ALLOWED');
      }

      await tx.speed_dating_sessions.update({
        where: { id: sessionId },
        data: {
          status: STATUS_ENDED_EARLY,
          user_a_decision: DECISION_PENDING,
          user_b_decision: DECISION_PENDING,
        },
      });

      return this.buildActionResult(tx, userId, sessionId, null);
    });
  }

  private async expireUserSessions(userId: string): Promise<void> {
    await prisma.speed_dating_sessions.updateMany({
      where: {
        OR: [{ user_a_id: userId }, { user_b_id: userId }],
        expires_at: { lte: new Date() },
        status: {
          in: EXPIRABLE_STATUSES,
        },
      },
      data: {
        status: STATUS_EXPIRED,
      },
    });
  }

  private async getAuthorizedSession(
    userId: string,
    sessionId: string,
    db: Prisma.TransactionClient | typeof prisma = prisma,
  ): Promise<SessionWithProfiles> {
    const session = await db.speed_dating_sessions.findUnique({
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

  private async getAuthorizedSessionRecord(
    db: Prisma.TransactionClient | typeof prisma,
    userId: string,
    sessionId: string,
  ): Promise<speed_dating_sessions> {
    const session = await db.speed_dating_sessions.findUnique({
      where: { id: sessionId },
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

    if (!normalizedStatus || !EXPIRABLE_STATUSES.includes(normalizedStatus)) {
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

  private async buildUnreadCountMap(
    sessionIds: string[],
    userId: string,
    db: Prisma.TransactionClient | typeof prisma = prisma,
  ): Promise<Map<string, number>> {
    const map = new Map<string, number>();

    if (sessionIds.length === 0) {
      return map;
    }

    const grouped = await db.speed_dating_messages.groupBy({
      by: ['session_id'],
      where: {
        session_id: { in: sessionIds },
        sender_id: { not: userId },
        read_at: null,
      },
      _count: {
        _all: true,
      },
    });

    for (const row of grouped) {
      if (!row.session_id) continue;
      const unreadCount = typeof row._count === 'object' ? (row._count._all ?? 0) : 0;
      map.set(row.session_id, unreadCount);
    }

    return map;
  }

  private getDecisionPerspective(
    session: Pick<speed_dating_sessions, 'user_a_decision' | 'user_b_decision' | 'user_a_id' | 'user_b_id'>,
    userId: string,
  ): { isUserA: boolean; myDecision: DecisionValue; otherDecision: DecisionValue } {
    const isUserA = isUserAInTwoParty(session, userId);

    return {
      isUserA,
      myDecision: normalizeDecision(isUserA ? session.user_a_decision : session.user_b_decision),
      otherDecision: normalizeDecision(isUserA ? session.user_b_decision : session.user_a_decision),
    };
  }

  private buildDecisionUpdateData(
    isUserA: boolean,
    myDecision: DecisionValue,
    otherDecision: DecisionValue,
    extra: Prisma.speed_dating_sessionsUpdateInput = {},
  ): Prisma.speed_dating_sessionsUpdateInput {
    return isUserA
      ? {
          ...extra,
          user_a_decision: myDecision,
          user_b_decision: otherDecision,
        }
      : {
          ...extra,
          user_a_decision: otherDecision,
          user_b_decision: myDecision,
        };
  }

  private toMoveToPermanentState(
    session: Pick<speed_dating_sessions, 'status' | 'user_a_decision' | 'user_b_decision' | 'user_a_id' | 'user_b_id'>,
    userId: string,
  ): SessionListItem['moveToPermanent'] {
    const internalStatus = normalizeSessionStatus(session.status);
    const { myDecision, otherDecision } = this.getDecisionPerspective(session, userId);

    const hasRequestWorkflow =
      internalStatus === STATUS_ACTIVE ||
      internalStatus === STATUS_ACTIVE_COUNTER_PENDING ||
      internalStatus === STATUS_AWAITING_DECISION ||
      internalStatus === STATUS_AWAITING_COUNTER_DECISION;

    const outgoingPending =
      hasRequestWorkflow && myDecision === DECISION_YES && otherDecision === DECISION_PENDING;
    const incomingPending =
      hasRequestWorkflow && myDecision === DECISION_PENDING && otherDecision === DECISION_YES;
    const counterAvailable = myDecision === DECISION_NO && otherDecision === DECISION_YES;
    const locked =
      internalStatus === STATUS_ACTIVE_REQUEST_LOCKED ||
      internalStatus === STATUS_AWAITING_DECISION_LOCKED;

    const canRequest =
      ((internalStatus === STATUS_ACTIVE || internalStatus === STATUS_AWAITING_DECISION) &&
        myDecision === DECISION_PENDING &&
        otherDecision === DECISION_PENDING) ||
      ((internalStatus === STATUS_ACTIVE || internalStatus === STATUS_AWAITING_DECISION) && counterAvailable);

    const canRespond =
      incomingPending &&
      (internalStatus === STATUS_ACTIVE ||
        internalStatus === STATUS_ACTIVE_COUNTER_PENDING ||
        internalStatus === STATUS_AWAITING_DECISION ||
        internalStatus === STATUS_AWAITING_COUNTER_DECISION);

    const canSubmitFinalDecision =
      (internalStatus === STATUS_AWAITING_DECISION || internalStatus === STATUS_AWAITING_DECISION_LOCKED) &&
      true;

    let requestStatus: MoveRequestStatus = 'none';
    if (incomingPending) {
      requestStatus = 'received';
    } else if (outgoingPending) {
      requestStatus = 'sent';
    } else if (locked) {
      requestStatus = 'locked';
    } else if (counterAvailable) {
      requestStatus = 'counter_available';
    }

    return {
      myDecision,
      otherDecision,
      requestStatus,
      canRequest,
      canRespond,
      canSubmitFinalDecision,
    };
  }

  private async graduateSession(
    db: Prisma.TransactionClient,
    session: speed_dating_sessions,
  ): Promise<matches> {
    const participantIds = getTwoPartyParticipantIds(session);
    const speedMessages = await db.speed_dating_messages.findMany({
      where: { session_id: session.id },
      orderBy: { created_at: 'asc' },
    });

    const lastMessage = speedMessages[speedMessages.length - 1];
    const match = await db.matches.create({
      data: {
        user_a_id: participantIds.userAId,
        user_b_id: participantIds.userBId,
        status: 'active',
        created_at: new Date(),
        last_message_content: lastMessage?.content ?? null,
        last_message_at: lastMessage?.created_at ?? null,
        message_count: speedMessages.length,
        user_a_decision: DECISION_PENDING,
        user_b_decision: DECISION_PENDING,
      },
    });

    if (speedMessages.length > 0) {
      await db.messages.createMany({
        data: speedMessages.map((message) => ({
          match_id: match.id,
          sender_id: message.sender_id,
          content: message.content,
          type: message.type,
          created_at: message.created_at,
          read_at: null,
        })),
      });
    }

    await db.speed_dating_sessions.update({
      where: { id: session.id },
      data: {
        status: STATUS_GRADUATED,
        user_a_decision: DECISION_YES,
        user_b_decision: DECISION_YES,
      },
    });

    return match;
  }

  private async buildActionResult(
    db: Prisma.TransactionClient,
    userId: string,
    sessionId: string,
    match: matches | null,
  ): Promise<SpeedDatingActionResult> {
    const fullSession = await db.speed_dating_sessions.findUnique({
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

    const countMap = await this.buildMessageCountMap([sessionId], db);

    return {
      session: this.toSessionListItem(fullSession, userId, countMap),
      match: match ? buildMatchSummary(match) : null,
    };
  }

  private toSessionListItem(
    session: SessionWithProfiles,
    userId: string,
    messageCountMap: Map<string, Map<string, number>>,
    unreadCountMap: Map<string, number> = new Map<string, number>(),
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
    const publicStatus = toPublicSessionStatus(sessionStatus);

    const canSendMessage =
      canSendForStatus(sessionStatus) &&
      myMessageCount < MESSAGE_LIMIT_PER_USER &&
      remainingSeconds > 0;

    const unreadCount = unreadCountMap.get(session.id) ?? 0;

    return {
      sessionId: session.id,
      status: publicStatus,
      startedAt: session.started_at,
      expiresAt: session.expires_at,
      remainingSeconds,
      canOpen: isSessionOpenable(sessionStatus),
      canSendMessage,
      unreadCount,
      myMessageCount,
      otherMessageCount,
      messageLimit: MESSAGE_LIMIT_PER_USER,
      counterpart: {
        userId: counterpartUser?.id ?? null,
        firstName,
        initials,
        blurredPhotoUrl,
      },
      moveToPermanent: this.toMoveToPermanentState(session, userId),
    };
  }
}
