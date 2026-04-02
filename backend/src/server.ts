import { createServer } from 'http';
import { createApp } from './app';
import { prisma } from './db/prisma-client';
import { env } from './config/env';
import { socketServer } from './websocket/socket-server';
import { SpeedDatingService } from './services/speed-dating-service';
import { PermanentChatService } from './services/permanent-chat-service';
import { UserRepository } from './repositories/user-repository';

const EXPIRABLE_SPEED_DATING_STATUSES = [
  'active',
  'active_counter_pending',
  'active_request_locked',
  'awaiting_decision',
  'awaiting_counter_decision',
  'awaiting_decision_locked',
] as const;

const SPEED_DATING_EXPIRY_SWEEP_INTERVAL_MS = 30_000;
// Run the deleted-user purge once per day
const DELETED_USER_PURGE_INTERVAL_MS = 24 * 60 * 60 * 1000;

const speedDatingService = new SpeedDatingService();
const permanentChatService = new PermanentChatService();
const userRepository = new UserRepository();

const app = createApp();

const httpServer = createServer(app);
socketServer.initialize(httpServer);

async function publishBadgeUpdatesForUsers(userIds: Set<string>): Promise<void> {
  await Promise.all(
    [...userIds].map(async (userId) => {
      const [speedDatingUnread, matchesUnread] = await Promise.all([
        speedDatingService.getUnreadCount(userId),
        permanentChatService.getUnreadCount(userId),
      ]);

      socketServer.notifyUser(userId, 'chat.badge.updated', {
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

const speedDatingExpirySweepHandle = setInterval(() => {
  void (async () => {
    try {
      const now = new Date();
      const expiringSessions = await prisma.speed_dating_sessions.findMany({
        where: {
          expires_at: { lte: now },
          status: { in: [...EXPIRABLE_SPEED_DATING_STATUSES] },
        },
        select: {
          id: true,
          user_a_id: true,
          user_b_id: true,
          status: true,
        },
      });

      const usersNeedingBadgeRefresh = new Set<string>();

      await Promise.all(
        expiringSessions.map(async (session) => {
          const updateResult = await prisma.speed_dating_sessions.updateMany({
            where: {
              id: session.id,
              status: { in: [...EXPIRABLE_SPEED_DATING_STATUSES] },
            },
            data: { status: 'expired' },
          });

          if (updateResult.count === 0) {
            return;
          }

          const payload = {
            v: 1 as const,
            data: {
              sessionId: session.id,
            },
          };

          if (session.user_a_id) {
            socketServer.notifyUser(session.user_a_id, 'speed_dating.session.ended', payload);
            usersNeedingBadgeRefresh.add(session.user_a_id);
          }

          if (session.user_b_id) {
            socketServer.notifyUser(session.user_b_id, 'speed_dating.session.ended', payload);
            usersNeedingBadgeRefresh.add(session.user_b_id);
          }
        }),
      );

      if (usersNeedingBadgeRefresh.size > 0) {
        await publishBadgeUpdatesForUsers(usersNeedingBadgeRefresh);
      }
    } catch (error) {
      console.error('[speed_dating] expiry sweep failed:', error);
    }
  })();
}, SPEED_DATING_EXPIRY_SWEEP_INTERVAL_MS);

(speedDatingExpirySweepHandle as any).unref();

// Purge soft-deleted users whose deleted_at is older than 30 days.
// CASCADE deletes all related rows (profiles, matches, messages, etc.).
const deletedUserPurgeHandle = setInterval(() => {
  void (async () => {
    try {
      const count = await userRepository.purgeDeletedUsers();
      if (count > 0) {
        console.log(`[user_purge] hard-deleted ${count} expired account(s)`);
      }
    } catch (error) {
      console.error('[user_purge] purge sweep failed:', error);
    }
  })();
}, DELETED_USER_PURGE_INTERVAL_MS);

(deletedUserPurgeHandle as any).unref();

const server = httpServer.listen(env.port, '0.0.0.0', () => {
  console.log(`API server running on port ${env.port}`);
});

async function shutdown(signal: string) {
  console.log(`${signal} received. Shutting down...`);
  clearInterval(speedDatingExpirySweepHandle);
  clearInterval(deletedUserPurgeHandle);
  server.close(async () => {
    await prisma.$disconnect();
    process.exit(0);
  });
}

process.on('SIGINT', () => {
  void shutdown('SIGINT');
});

process.on('SIGTERM', () => {
  void shutdown('SIGTERM');
});
export { app };