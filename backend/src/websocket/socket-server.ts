import { Server as HttpServer } from 'http';
import { Server as SocketIOServer, Socket } from 'socket.io';
import { createAdapter } from '@socket.io/redis-adapter';
import { Redis } from 'ioredis';
import { prisma } from '../db/prisma-client';
import { env } from '../config/env';
import { socketAuthMiddleware } from './socket-auth.middleware';

export interface EventPayload<T = any> {
  v: 1;
  data: T;
}

type TypingPayload = {
  chatType: 'permanent' | 'speed_dating';
  chatId: string;
  isTyping: boolean;
};

const UUID_V4_OR_V1_REGEX =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

export class SocketServer {
  private io: SocketIOServer | null = null;
  private redisPubClient: Redis | null = null;
  private redisSubClient: Redis | null = null;

  initialize(httpServer: HttpServer): SocketIOServer {
    if (this.io) {
      return this.io;
    }

    const corsConfig =
      env.wsCorsOrigins.length > 0
        ? {
            origin: env.wsCorsOrigins,
            credentials: true,
          }
        : undefined;

    this.io = new SocketIOServer(httpServer, {
      transports: ['websocket', 'polling'],
      ...(corsConfig ? { cors: corsConfig } : {}),
      // Adjust for Cloud Run environment if needed
      pingInterval: 25000,
      pingTimeout: 60000,
    });

    // Upstash Redis Adapter (Cloud Run Scaling)
    if (env.upstashRedisUrl) {
      const pubClient = new Redis(env.upstashRedisUrl);
      const subClient = pubClient.duplicate();

      pubClient.on('error', (err: Error) => console.error('[socket] Redis pub error:', err));
      subClient.on('error', (err: Error) => console.error('[socket] Redis sub error:', err));
      pubClient.on('reconnecting', () => console.error('[socket] Redis pub reconnecting'));
      subClient.on('reconnecting', () => console.error('[socket] Redis sub reconnecting'));

      this.redisPubClient = pubClient;
      this.redisSubClient = subClient;

      this.io.adapter(createAdapter(pubClient, subClient));
    }

    // Apply authentication middleware
    this.io.use(socketAuthMiddleware);

    // Connection handler
    this.io.on('connection', (socket) => {
      this.handleConnection(socket);
    });

    return this.io;
  }

  private handleConnection(socket: Socket): void {
    const dbUserId = socket.data.dbUserId;

    // Join per-user room
    socket.join(`user:${dbUserId}`);

    // Handle disconnection
    socket.on('disconnect', () => {
      this.handleDisconnect(socket, dbUserId);
    });

    // Handle incoming messages
    socket.on('ping', () => {
      socket.emit('pong');
    });

    socket.on('typing', (payload: any) => {
      void this.handleTypingMessage(socket, dbUserId, payload);
    });
  }

  private emitSystemError(socket: Socket, code: string, message: string): void {
    socket.emit('error', {
      v: 1,
      data: {
        code,
        message,
      },
    });
  }

  private async handleDisconnect(socket: Socket, dbUserId: string): Promise<void> {
    try {
      const activeSockets = await this.io?.in(`user:${dbUserId}`).fetchSockets();
      
      // if global num > 0, not remove them from queue
      if (activeSockets && activeSockets.length > 0) {
        return;
      }

      // Dequeue user from matching queue
      // deleteMany is safe no-op when user is not in queue
      await prisma.matching_queue.deleteMany({
        where: { user_id: dbUserId },
      });
    } catch (error) {
      // Log but never re-throw — disconnect handler errors must not crash the server
      console.error('[socket] dequeue on disconnect failed:', error);
    }
  }

  private async handleTypingMessage(socket: Socket, senderUserId: string, payload: any): Promise<void> {
    try {
      // Validate and parse typing payload
      if (!payload || typeof payload !== 'object') {
        return;
      }

      const { chatType, chatId, isTyping } = payload;

      if (chatType !== 'permanent' && chatType !== 'speed_dating') {
        return;
      }

      if (typeof chatId !== 'string' || chatId.trim().length === 0) {
        return;
      }

      if (!UUID_V4_OR_V1_REGEX.test(chatId.trim())) {
        // Invalid identifiers are treated as invalid payload and ignored.
        return;
      }

      if (typeof isTyping !== 'boolean') {
        return;
      }

      // Resolve counterpart user ID and validate participation
      const counterpartUserId = await this.resolveCounterpartUserId(chatType, chatId, senderUserId);

      if (!counterpartUserId) {
        // Invalid session/match or user is not a participant — silently ignore
        return;
      }

      // Relay typing event to counterpart
      const eventType = chatType === 'permanent' ? 'permanent.typing.updated' : 'speed_dating.typing.updated';
      const roomName = `user:${counterpartUserId}`;

      this.io?.to(roomName).emit(eventType, {
        v: 1,
        data: {
          [chatType === 'permanent' ? 'matchId' : 'sessionId']: chatId,
          userId: senderUserId,
          isTyping,
        },
      });
    } catch (error) {
      console.error('[socket] typing handler failed:', error);
      this.emitSystemError(socket, 'WS_TYPING_RELAY_FAILED', 'Failed to relay typing event');
    }
  }

  private async resolveCounterpartUserId(
    chatType: 'permanent' | 'speed_dating',
    chatId: string,
    senderUserId: string,
  ): Promise<string | null> {
    try {
      if (chatType === 'permanent') {
        const match = await prisma.matches.findUnique({
          where: { id: chatId },
          select: {
            user_a_id: true,
            user_b_id: true,
          },
        });

        if (!match?.user_a_id || !match?.user_b_id) {
          return null;
        }

        if (senderUserId !== match.user_a_id && senderUserId !== match.user_b_id) {
          return null;
        }

        return match.user_a_id === senderUserId ? match.user_b_id : match.user_a_id;
      } else {
        const session = await prisma.speed_dating_sessions.findUnique({
          where: { id: chatId },
          select: {
            user_a_id: true,
            user_b_id: true,
          },
        });

        if (!session?.user_a_id || !session?.user_b_id) {
          return null;
        }

        if (senderUserId !== session.user_a_id && senderUserId !== session.user_b_id) {
          return null;
        }

        return session.user_a_id === senderUserId ? session.user_b_id : session.user_a_id;
      }
    } catch (error) {
      console.error('[socket] resolveCounterpartUserId failed:', error);
      throw error;
    }
  }

  /**
   * Notify a user via socket.io
   * Broadcasts to all sockets in the user's room
   */
  notifyUser<T = any>(dbUserId: string, event: string, payload: EventPayload<T>): void {
    if (!this.io) {
      console.error('[socket] Socket.io not initialized');
      return;
    }

    const roomName = `user:${dbUserId}`;
    this.io.to(roomName).emit(event, payload);
  }

  /**
   * Get the socket.io instance for advanced usage
   */
  getIO(): SocketIOServer | null {
    return this.io;
  }

  /**
   * Gracefully shut down Socket.IO and disconnect Redis clients.
   * Call during server shutdown to avoid hanging processes.
   */
  async close(): Promise<void> {
    await new Promise<void>((resolve) => {
      if (this.io) {
        this.io.close(() => resolve());
      } else {
        resolve();
      }
    });

    await Promise.all([
      this.redisPubClient?.quit(),
      this.redisSubClient?.quit(),
    ]);

    this.redisPubClient = null;
    this.redisSubClient = null;
    this.io = null;
  }
}

export const socketServer = new SocketServer();
