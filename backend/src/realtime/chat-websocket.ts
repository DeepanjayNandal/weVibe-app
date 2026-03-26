import { IncomingMessage, Server as HttpServer } from 'http';
import { URL } from 'url';
import { WebSocket, WebSocketServer } from 'ws';
import { prisma } from '../db/prisma-client';
import { UserRepository } from '../repositories/user-repository';
import { createAuthVerifier } from '../services/auth/auth-verifier';

type PermanentMessageEvent = {
  recipientUserIds: Array<string | null | undefined>;
  payload: unknown;
};

type SpeedDatingMessageEvent = {
  recipientUserIds: Array<string | null | undefined>;
  payload: unknown;
};

type PermanentMatchStatusEvent = {
  recipientUserIds: Array<string | null | undefined>;
  payload: unknown;
};

type SpeedDatingSessionStatusEvent = {
  recipientUserIds: Array<string | null | undefined>;
  payload: unknown;
};

type MatchmakingQueueEvent = {
  recipientUserIds: Array<string | null | undefined>;
  payload: unknown;
};

type ChatBadgeEvent = {
  recipientUserIds: Array<string | null | undefined>;
  payload: unknown;
};

type TypingChatType = 'permanent' | 'speed_dating';

type TypingEventPayload = {
  chatType: TypingChatType;
  chatId: string;
  isTyping: boolean;
};

type WebSocketClientMessage = {
  type?: unknown;
  data?: unknown;
};

const WS_PATH = '/ws/chat';

function uniqueNonEmpty(values: Array<string | null | undefined>): string[] {
  const normalized = values
    .filter((value): value is string => typeof value === 'string')
    .map((value) => value.trim())
    .filter((value) => value.length > 0);

  return [...new Set(normalized)];
}

export class ChatWebSocketBroker {
  private readonly authVerifier = createAuthVerifier();

  private readonly userRepository = new UserRepository();

  private readonly userSockets = new Map<string, Set<WebSocket>>();

  private readonly socketToUser = new Map<WebSocket, string>();

  private wss: WebSocketServer | null = null;

  initialize(server: HttpServer): void {
    if (this.wss) {
      return;
    }

    const wss = new WebSocketServer({ noServer: true });

    wss.on('connection', (socket, req) => {
      void this.handleConnection(socket, req);
    });

    server.on('upgrade', (req, socket, head) => {
      const pathname = this.getPathname(req);
      if (pathname !== WS_PATH) {
        socket.destroy();
        return;
      }

      wss.handleUpgrade(req, socket, head, (ws) => {
        wss.emit('connection', ws, req);
      });
    });

    this.wss = wss;
  }

  publishPermanentMessage(event: PermanentMessageEvent): void {
    this.broadcastToUsers(uniqueNonEmpty(event.recipientUserIds), {
      type: 'permanent.message.created',
      data: event.payload,
    });
  }

  publishSpeedDatingMessage(event: SpeedDatingMessageEvent): void {
    this.broadcastToUsers(uniqueNonEmpty(event.recipientUserIds), {
      type: 'speed_dating.message.created',
      data: event.payload,
    });
  }

  publishPermanentReadUpdated(event: PermanentMatchStatusEvent): void {
    this.broadcastToUsers(uniqueNonEmpty(event.recipientUserIds), {
      type: 'permanent.match.read_updated',
      data: event.payload,
    });
  }

  publishPermanentMatchRemoved(event: PermanentMatchStatusEvent): void {
    this.broadcastToUsers(uniqueNonEmpty(event.recipientUserIds), {
      type: 'permanent.match.removed',
      data: event.payload,
    });
  }

  publishPermanentCounterpartBlocked(event: PermanentMatchStatusEvent): void {
    this.broadcastToUsers(uniqueNonEmpty(event.recipientUserIds), {
      type: 'permanent.match.blocked',
      data: event.payload,
    });
  }

  publishPermanentCounterpartReported(event: PermanentMatchStatusEvent): void {
    this.broadcastToUsers(uniqueNonEmpty(event.recipientUserIds), {
      type: 'permanent.match.reported',
      data: event.payload,
    });
  }

  publishSpeedDatingReadUpdated(event: SpeedDatingSessionStatusEvent): void {
    this.broadcastToUsers(uniqueNonEmpty(event.recipientUserIds), {
      type: 'speed_dating.session.read_updated',
      data: event.payload,
    });
  }

  publishSpeedDatingMoveToPermanentUpdated(event: SpeedDatingSessionStatusEvent): void {
    this.broadcastToUsers(uniqueNonEmpty(event.recipientUserIds), {
      type: 'speed_dating.session.move_to_permanent_updated',
      data: event.payload,
    });
  }

  publishSpeedDatingFinalDecisionUpdated(event: SpeedDatingSessionStatusEvent): void {
    this.broadcastToUsers(uniqueNonEmpty(event.recipientUserIds), {
      type: 'speed_dating.session.final_decision_updated',
      data: event.payload,
    });
  }

  publishSpeedDatingEnded(event: SpeedDatingSessionStatusEvent): void {
    this.broadcastToUsers(uniqueNonEmpty(event.recipientUserIds), {
      type: 'speed_dating.session.ended',
      data: event.payload,
    });
  }

  publishMatchingQueueMatched(event: MatchmakingQueueEvent): void {
    this.broadcastToUsers(uniqueNonEmpty(event.recipientUserIds), {
      type: 'matching.queue.matched',
      data: event.payload,
    });
  }

  publishChatBadgeUpdated(event: ChatBadgeEvent): void {
    this.broadcastToUsers(uniqueNonEmpty(event.recipientUserIds), {
      type: 'chat.badge.updated',
      data: event.payload,
    });
  }

  private getPathname(req: IncomingMessage): string {
    const parsed = new URL(req.url ?? '/', 'http://localhost');
    return parsed.pathname;
  }

  private async handleConnection(socket: WebSocket, req: IncomingMessage): Promise<void> {
    const userId = await this.resolveUserId(req);
    if (!userId) {
      this.safeSend(socket, {
        type: 'error',
        data: {
          code: 'WS_UNAUTHORIZED',
          message: 'Unauthorized websocket connection',
        },
      });
      socket.close(1008, 'Unauthorized');
      return;
    }

    this.attachSocket(userId, socket);

    this.safeSend(socket, {
      type: 'connected',
      data: {
        userId,
      },
    });

    socket.on('message', (raw) => {
      void this.handleClientMessage(socket, raw.toString());
    });

    socket.on('close', () => {
      this.detachSocket(socket);
    });
  }

  private async handleClientMessage(socket: WebSocket, raw: string): Promise<void> {
    let message: WebSocketClientMessage;

    try {
      message = JSON.parse(raw) as WebSocketClientMessage;
    } catch {
      this.safeSend(socket, {
        type: 'error',
        data: {
          code: 'WS_BAD_PAYLOAD',
          message: 'Invalid JSON payload',
        },
      });
      return;
    }

    if (message.type === 'ping') {
      this.safeSend(socket, { type: 'pong' });
      return;
    }

    if (message.type === 'typing') {
      await this.handleTypingMessage(socket, message.data);
    }
  }

  private async handleTypingMessage(socket: WebSocket, data: unknown): Promise<void> {
    const senderUserId = this.socketToUser.get(socket);
    if (!senderUserId) {
      return;
    }

    const payload = this.parseTypingPayload(data);
    if (!payload) {
      return;
    }

    const counterpartUserId = await this.resolveCounterpartUserId(
      payload.chatType,
      payload.chatId,
      senderUserId,
    );

    if (!counterpartUserId) {
      return;
    }

    const eventType =
      payload.chatType === 'permanent' ? 'permanent.typing.updated' : 'speed_dating.typing.updated';

    this.broadcastToUsers([counterpartUserId], {
      type: eventType,
      data: {
        chatType: payload.chatType,
        chatId: payload.chatId,
        senderUserId,
        isTyping: payload.isTyping,
        sentAt: new Date().toISOString(),
      },
    });
  }

  private parseTypingPayload(data: unknown): TypingEventPayload | null {
    if (!data || typeof data !== 'object') {
      return null;
    }

    const candidate = data as {
      chatType?: unknown;
      chatId?: unknown;
      isTyping?: unknown;
    };

    const chatType = candidate.chatType;
    const chatId = candidate.chatId;
    const isTyping = candidate.isTyping;

    if (chatType !== 'permanent' && chatType !== 'speed_dating') {
      return null;
    }

    if (typeof chatId !== 'string' || chatId.trim().length === 0) {
      return null;
    }

    if (typeof isTyping !== 'boolean') {
      return null;
    }

    return {
      chatType,
      chatId: chatId.trim(),
      isTyping,
    };
  }

  private async resolveCounterpartUserId(
    chatType: TypingChatType,
    chatId: string,
    senderUserId: string,
  ): Promise<string | null> {
    if (chatType === 'permanent') {
      const match = await prisma.matches.findUnique({
        where: { id: chatId },
        select: {
          user_a_id: true,
          user_b_id: true,
        },
      });

      return this.pickCounterpartUserId(match, senderUserId);
    }

    const session = await prisma.speed_dating_sessions.findUnique({
      where: { id: chatId },
      select: {
        user_a_id: true,
        user_b_id: true,
      },
    });

    return this.pickCounterpartUserId(session, senderUserId);
  }

  private pickCounterpartUserId(
    record: { user_a_id: string | null; user_b_id: string | null } | null,
    senderUserId: string,
  ): string | null {
    if (!record?.user_a_id || !record.user_b_id) {
      return null;
    }

    if (record.user_a_id === senderUserId) {
      return record.user_b_id;
    }

    if (record.user_b_id === senderUserId) {
      return record.user_a_id;
    }

    return null;
  }

  private async resolveUserId(req: IncomingMessage): Promise<string | null> {
    const token = this.extractIdToken(req);
    if (!token) {
      return null;
    }

    try {
      const identity = await this.authVerifier.verifyIdToken(token);
      const user = await this.userRepository.findByFirebaseUid(identity.uid);
      return user?.id ?? null;
    } catch {
      return null;
    }
  }

  private extractIdToken(req: IncomingMessage): string | null {
    const authorizationHeader = req.headers.authorization;
    if (typeof authorizationHeader === 'string') {
      const [scheme, token] = authorizationHeader.split(' ');
      if (scheme?.toLowerCase() === 'bearer' && token?.trim()) {
        return token.trim();
      }
    }

    const parsed = new URL(req.url ?? '/', 'http://localhost');
    const queryToken = parsed.searchParams.get('token');
    if (queryToken && queryToken.trim().length > 0) {
      return queryToken.trim();
    }

    return null;
  }

  private attachSocket(userId: string, socket: WebSocket): void {
    if (!this.userSockets.has(userId)) {
      this.userSockets.set(userId, new Set<WebSocket>());
    }

    this.userSockets.get(userId)?.add(socket);
    this.socketToUser.set(socket, userId);
  }

  private detachSocket(socket: WebSocket): void {
    const userId = this.socketToUser.get(socket);
    if (!userId) {
      return;
    }

    const sockets = this.userSockets.get(userId);
    if (sockets) {
      sockets.delete(socket);
      if (sockets.size === 0) {
        this.userSockets.delete(userId);
      }
    }

    this.socketToUser.delete(socket);
  }

  private broadcastToUsers(userIds: string[], payload: unknown): void {
    for (const userId of userIds) {
      const sockets = this.userSockets.get(userId);
      if (!sockets || sockets.size === 0) {
        continue;
      }

      for (const socket of sockets) {
        this.safeSend(socket, payload);
      }
    }
  }

  private safeSend(socket: WebSocket, payload: unknown): void {
    if (socket.readyState !== WebSocket.OPEN) {
      return;
    }

    socket.send(JSON.stringify(payload));
  }
}

export const chatWebSocketBroker = new ChatWebSocketBroker();
