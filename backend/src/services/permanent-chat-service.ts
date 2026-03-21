import { Prisma, matches, messages } from '@prisma/client';
import { prisma } from '../db/prisma-client';
import { AppError, badRequest } from '../utils/errors';
import { assertTwoPartyParticipant, isUserAInTwoParty } from './chat/two-party-access';

type MatchStatus = string | null;

type MatchWithProfiles = Prisma.matchesGetPayload<{
  include: {
    users_matches_user_a_idTousers: {
      include: {
        profiles: true;
      };
    };
    users_matches_user_b_idTousers: {
      include: {
        profiles: true;
      };
    };
  };
}>;

export type PermanentChatMatchItem = {
  matchId: string;
  status: MatchStatus;
  createdAt: Date | null;
  lastMessageAt: Date | null;
  lastMessageContent: string | null;
  messageCount: number;
  canOpen: boolean;
  canSendMessage: boolean;
  unreadCount: number;
  counterpart: {
    userId: string | null;
    displayName: string | null;
    photoUrl: string | null;
  };
};

export type PermanentMessagePayload = {
  id: string;
  matchId: string;
  senderId: string;
  content: string;
  createdAt: Date | null;
  readAt: Date | null;
};

export type PermanentChatMessagesResult = {
  match: PermanentChatMatchItem;
  messages: PermanentMessagePayload[];
};

export type PermanentChatSendResult = {
  message: PermanentMessagePayload;
  match: PermanentChatMatchItem;
};

export type RemoveMatchResult = {
  match: PermanentChatMatchItem;
  counterpartUserId: string;
};

export type BlockCounterpartResult = {
  match: PermanentChatMatchItem;
  counterpartUserId: string;
  blockId: string;
};

export type ReportCounterpartResult = {
  match: PermanentChatMatchItem;
  counterpartUserId: string;
  reportId: string;
};

const STATUS_ACTIVE = 'active';
const STATUS_UNMATCHED = 'unmatched';
const STATUS_REPORTED = 'reported';
const STATUS_ENDED_EARLY = 'ended_early';
const SPEED_SESSION_INTERRUPTIBLE_STATUSES = [
  'active',
  'active_counter_pending',
  'active_request_locked',
  'awaiting_decision',
  'awaiting_counter_decision',
  'awaiting_decision_locked',
] as const;

function normalizeMatchStatus(status: MatchStatus): MatchStatus {
  if (!status) return status;
  return status.trim().toLowerCase();
}

function extractPhotoUrl(photos: Prisma.JsonValue | null): string | null {
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

function messageToPayload(message: messages): PermanentMessagePayload {
  return {
    id: String(message.id),
    matchId: message.match_id ?? '',
    senderId: message.sender_id ?? '',
    content: message.content,
    createdAt: message.created_at,
    readAt: message.read_at,
  };
}

function toNumber(value: number | null | undefined): number {
  return value ?? 0;
}

function normalizeReason(reason: unknown): string | null {
  if (typeof reason !== 'string') return null;
  const normalized = reason.trim();
  return normalized.length > 0 ? normalized : null;
}

export class PermanentChatService {
  async listMatches(userId: string): Promise<PermanentChatMatchItem[]> {
    const rows = await prisma.matches.findMany({
      where: {
        OR: [{ user_a_id: userId }, { user_b_id: userId }],
      },
      include: {
        users_matches_user_a_idTousers: {
          include: { profiles: true },
        },
        users_matches_user_b_idTousers: {
          include: { profiles: true },
        },
      },
      orderBy: [
        {
          last_message_at: 'desc',
        },
        {
          created_at: 'desc',
        },
      ],
    });

    const matchIds = rows.map((row) => row.id);
    const unreadCountMap = await this.buildUnreadCountMap(matchIds, userId);

    return rows.map((row) => this.toMatchItem(row, userId, unreadCountMap));
  }

  async getMatchDetail(userId: string, matchId: string): Promise<PermanentChatMatchItem> {
    const match = await this.getAuthorizedMatch(userId, matchId);
    const unreadCountMap = await this.buildUnreadCountMap([matchId], userId);
    return this.toMatchItem(match, userId, unreadCountMap);
  }

  async getMatchMessages(userId: string, matchId: string): Promise<PermanentChatMessagesResult> {
    return prisma.$transaction(async (tx) => {
      const match = await this.getAuthorizedMatch(userId, matchId, tx);

      const rows = await tx.messages.findMany({
        where: {
          match_id: matchId,
        },
        orderBy: {
          created_at: 'asc',
        },
      });

      const unreadCountMap = await this.buildUnreadCountMap([matchId], userId, tx);

      return {
        match: this.toMatchItem(match, userId, unreadCountMap),
        messages: rows.map(messageToPayload),
      };
    });
  }

  async markMatchMessagesRead(userId: string, matchId: string): Promise<PermanentChatMatchItem> {
    return prisma.$transaction(async (tx) => {
      const match = await this.getAuthorizedMatch(userId, matchId, tx);

      await tx.messages.updateMany({
        where: {
          match_id: matchId,
          sender_id: { not: userId },
          read_at: null,
        },
        data: {
          read_at: new Date(),
        },
      });

      const refreshedMatch = await this.getAuthorizedMatch(userId, matchId, tx);
      const unreadCountMap = await this.buildUnreadCountMap([matchId], userId, tx);

      return this.toMatchItem(refreshedMatch, userId, unreadCountMap);
    });
  }

  async getUnreadCount(userId: string): Promise<number> {
    return prisma.messages.count({
      where: {
        sender_id: { not: userId },
        read_at: null,
        matches: {
          OR: [{ user_a_id: userId }, { user_b_id: userId }],
          status: STATUS_ACTIVE,
        },
      },
    });
  }

  async sendMessage(userId: string, matchId: string, content: string): Promise<PermanentChatSendResult> {
    const normalizedContent = content.trim();
    if (!normalizedContent) {
      badRequest('Message content is required', 'MISSING_MESSAGE_CONTENT');
    }

    return prisma.$transaction(async (tx) => {
      const match = await tx.matches.findUnique({ where: { id: matchId } });
      if (!match) {
        throw new AppError('Match not found', 404, 'MATCH_NOT_FOUND');
      }

      assertTwoPartyParticipant(match, userId);

      if (normalizeMatchStatus(match.status) !== STATUS_ACTIVE) {
        badRequest('Match is not active for messaging', 'MATCH_NOT_ACTIVE');
      }

      const message = await tx.messages.create({
        data: {
          match_id: matchId,
          sender_id: userId,
          content: normalizedContent,
        },
      });

      const updatedMatch = await tx.matches.update({
        where: { id: matchId },
        data: {
          last_message_content: normalizedContent,
          last_message_at: new Date(),
          message_count: {
            increment: 1,
          },
        },
        include: {
          users_matches_user_a_idTousers: {
            include: { profiles: true },
          },
          users_matches_user_b_idTousers: {
            include: { profiles: true },
          },
        },
      });

      return {
        message: messageToPayload(message),
        match: this.toMatchItem(updatedMatch, userId),
      };
    });
  }

  async removeMatch(userId: string, matchId: string): Promise<RemoveMatchResult> {
    return prisma.$transaction(async (tx) => {
      return this.removeMatchInTransaction(tx, userId, matchId);
    });
  }

  async blockCounterpart(userId: string, matchId: string, reason?: unknown): Promise<BlockCounterpartResult> {
    return prisma.$transaction(async (tx) => {
      const removeResult = await this.removeMatchInTransaction(tx, userId, matchId);
      const normalizedReason = normalizeReason(reason);

      const block = await tx.user_blocks.upsert({
        where: {
          blocker_user_id_blocked_user_id: {
            blocker_user_id: userId,
            blocked_user_id: removeResult.counterpartUserId,
          },
        },
        update: {
          reason: normalizedReason,
        },
        create: {
          blocker_user_id: userId,
          blocked_user_id: removeResult.counterpartUserId,
          reason: normalizedReason,
        },
      });

      return {
        match: removeResult.match,
        counterpartUserId: removeResult.counterpartUserId,
        blockId: block.id,
      };
    });
  }

  async reportCounterpart(
    userId: string,
    matchId: string,
    reason: unknown,
    details: unknown,
  ): Promise<ReportCounterpartResult> {
    const normalizedReason = normalizeReason(reason);
    if (!normalizedReason) {
      badRequest('reason is required', 'MISSING_REPORT_REASON');
    }

    const normalizedDetails = normalizeReason(details);

    return prisma.$transaction(async (tx) => {
      const authorizedMatch = await this.getAuthorizedMatch(userId, matchId, tx);
      const counterpartUserId = this.getCounterpartUserId(authorizedMatch, userId);

      const reportedMatch = await tx.matches.update({
        where: { id: matchId },
        data: {
          status: STATUS_REPORTED,
        },
        include: {
          users_matches_user_a_idTousers: {
            include: { profiles: true },
          },
          users_matches_user_b_idTousers: {
            include: { profiles: true },
          },
        },
      });

      await tx.speed_dating_sessions.updateMany({
        where: {
          OR: [
            {
              user_a_id: userId,
              user_b_id: counterpartUserId,
            },
            {
              user_a_id: counterpartUserId,
              user_b_id: userId,
            },
          ],
          status: {
            in: [...SPEED_SESSION_INTERRUPTIBLE_STATUSES],
          },
        },
        data: {
          status: STATUS_ENDED_EARLY,
          user_a_decision: 'pending',
          user_b_decision: 'pending',
        },
      });

      const report = await tx.user_reports.create({
        data: {
          reporter_user_id: userId,
          reported_user_id: counterpartUserId,
          match_id: matchId,
          reason: normalizedReason,
          details: normalizedDetails,
        },
      });

      return {
        match: this.toMatchItem(reportedMatch, userId),
        counterpartUserId,
        reportId: report.id,
      };
    });
  }

  private async getAuthorizedMatch(
    userId: string,
    matchId: string,
    db: Prisma.TransactionClient | typeof prisma = prisma,
  ): Promise<MatchWithProfiles> {
    const match = await db.matches.findUnique({
      where: { id: matchId },
      include: {
        users_matches_user_a_idTousers: {
          include: { profiles: true },
        },
        users_matches_user_b_idTousers: {
          include: { profiles: true },
        },
      },
    });

    if (!match) {
      throw new AppError('Match not found', 404, 'MATCH_NOT_FOUND');
    }

    assertTwoPartyParticipant(match, userId);

    return match;
  }

  private async buildUnreadCountMap(
    matchIds: string[],
    userId: string,
    db: Prisma.TransactionClient | typeof prisma = prisma,
  ): Promise<Map<string, number>> {
    const map = new Map<string, number>();

    if (matchIds.length === 0) {
      return map;
    }

    const grouped = await db.messages.groupBy({
      by: ['match_id'],
      where: {
        match_id: { in: matchIds },
        sender_id: { not: userId },
        read_at: null,
      },
      _count: {
        _all: true,
      },
    });

    for (const row of grouped) {
      if (!row.match_id) continue;
      const unreadCount = typeof row._count === 'object' ? (row._count._all ?? 0) : 0;
      map.set(row.match_id, unreadCount);
    }

    return map;
  }

  private toMatchItem(
    match: MatchWithProfiles,
    userId: string,
    unreadCountMap: Map<string, number> = new Map<string, number>(),
  ): PermanentChatMatchItem {
    const isUserA = isUserAInTwoParty(match, userId);
    const counterpartUser = isUserA
      ? match.users_matches_user_b_idTousers
      : match.users_matches_user_a_idTousers;

    const status = normalizeMatchStatus(match.status);

    return {
      matchId: match.id,
      status,
      createdAt: match.created_at,
      lastMessageAt: match.last_message_at,
      lastMessageContent: match.last_message_content,
      messageCount: toNumber(match.message_count),
      canOpen: status === STATUS_ACTIVE,
      canSendMessage: status === STATUS_ACTIVE,
      unreadCount: unreadCountMap.get(match.id) ?? 0,
      counterpart: {
        userId: counterpartUser?.id ?? null,
        displayName: counterpartUser?.profiles?.display_name ?? null,
        photoUrl: extractPhotoUrl(counterpartUser?.profiles?.photos ?? null),
      },
    };
  }

  private async removeMatchInTransaction(
    tx: Prisma.TransactionClient,
    userId: string,
    matchId: string,
  ): Promise<RemoveMatchResult> {
    const authorizedMatch = await this.getAuthorizedMatch(userId, matchId, tx);
    const counterpartUserId = this.getCounterpartUserId(authorizedMatch, userId);

    const currentStatus = normalizeMatchStatus(authorizedMatch.status);
    const nextStatus = currentStatus === STATUS_REPORTED ? STATUS_REPORTED : STATUS_UNMATCHED;

    const updatedMatch = await tx.matches.update({
      where: { id: matchId },
      data: {
        status: nextStatus,
      },
      include: {
        users_matches_user_a_idTousers: {
          include: { profiles: true },
        },
        users_matches_user_b_idTousers: {
          include: { profiles: true },
        },
      },
    });

    await tx.speed_dating_sessions.updateMany({
      where: {
        OR: [
          {
            user_a_id: userId,
            user_b_id: counterpartUserId,
          },
          {
            user_a_id: counterpartUserId,
            user_b_id: userId,
          },
        ],
        status: {
          in: [...SPEED_SESSION_INTERRUPTIBLE_STATUSES],
        },
      },
      data: {
        status: STATUS_ENDED_EARLY,
        user_a_decision: 'pending',
        user_b_decision: 'pending',
      },
    });

    return {
      match: this.toMatchItem(updatedMatch, userId),
      counterpartUserId,
    };
  }

  private getCounterpartUserId(match: MatchWithProfiles, userId: string): string {
    const isUserA = isUserAInTwoParty(match, userId);
    const counterpartUserId = isUserA ? match.user_b_id : match.user_a_id;

    if (!counterpartUserId) {
      throw new AppError('Match participants are incomplete', 400, 'MATCH_PARTICIPANTS_INVALID');
    }

    return counterpartUserId;
  }

}
