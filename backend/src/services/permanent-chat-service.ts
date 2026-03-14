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

const STATUS_ACTIVE = 'active';

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

    return rows.map((row) => this.toMatchItem(row, userId));
  }

  async getMatchDetail(userId: string, matchId: string): Promise<PermanentChatMatchItem> {
    const match = await this.getAuthorizedMatch(userId, matchId);
    return this.toMatchItem(match, userId);
  }

  async getMatchMessages(userId: string, matchId: string): Promise<PermanentChatMessagesResult> {
    const match = await this.getAuthorizedMatch(userId, matchId);

    const rows = await prisma.messages.findMany({
      where: {
        match_id: matchId,
      },
      orderBy: {
        created_at: 'asc',
      },
    });

    return {
      match: this.toMatchItem(match, userId),
      messages: rows.map(messageToPayload),
    };
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

  private async getAuthorizedMatch(userId: string, matchId: string): Promise<MatchWithProfiles> {
    const match = await prisma.matches.findUnique({
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

  private toMatchItem(match: MatchWithProfiles, userId: string): PermanentChatMatchItem {
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
      counterpart: {
        userId: counterpartUser?.id ?? null,
        displayName: counterpartUser?.profiles?.display_name ?? null,
        photoUrl: extractPhotoUrl(counterpartUser?.profiles?.photos ?? null),
      },
    };
  }

}
