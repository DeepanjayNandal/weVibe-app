import { createServer } from 'http';
import { createApp } from './app';
import { prisma } from './db/prisma-client';
import { env } from './config/env';
import { socketServer } from './websocket/socket-server';
import { SpeedDatingService } from './services/speed-dating-service';
import { PermanentChatService } from './services/permanent-chat-service';
import { UserRepository } from './repositories/user-repository';

const SPEED_DATING_EXPIRY_SWEEP_INTERVAL_MS = 30_000;
// Run the deleted-user purge once per day
const DELETED_USER_PURGE_INTERVAL_MS = 24 * 60 * 60 * 1000;

const speedDatingService = new SpeedDatingService();
const permanentChatService = new PermanentChatService();
const userRepository = new UserRepository();
import { startPhotoCleanupJob } from './jobs/photo-cleanup.job';

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
      const results = await speedDatingService.expireDueSessions();

      const usersNeedingBadgeRefresh = new Set<string>();

      for (const result of results) {
        const data: Record<string, unknown> = {
          sessionId: result.sessionId,
          reason: result.endedReason,
        };
        if (result.matchId) {
          data.matchId = result.matchId;
        }

        const payload = { v: 1 as const, data };

        if (result.userAId) {
          socketServer.notifyUser(result.userAId, 'speed_dating.session.ended', payload);
          usersNeedingBadgeRefresh.add(result.userAId);
        }

        if (result.userBId) {
          socketServer.notifyUser(result.userBId, 'speed_dating.session.ended', payload);
          usersNeedingBadgeRefresh.add(result.userBId);
        }
      }

      if (usersNeedingBadgeRefresh.size > 0) {
        await publishBadgeUpdatesForUsers(usersNeedingBadgeRefresh);
      }
    } catch (error) {
      console.error('[speed_dating] expiry sweep failed:', error);
    }
  })();
}, SPEED_DATING_EXPIRY_SWEEP_INTERVAL_MS);

speedDatingExpirySweepHandle.unref();

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

deletedUserPurgeHandle.unref();

const server = httpServer.listen(env.port, '0.0.0.0', () => {
  console.log(`API server running on port ${env.port}`);
  // Start background jobs after the server is listening and Firebase is initialised.
  startPhotoCleanupJob();
});

async function shutdown(signal: string) {
  console.log(`${signal} received. Shutting down...`);
  clearInterval(speedDatingExpirySweepHandle);
  
  // turn off Socket.io and Redis Adapter at the same time
  socketServer.getIO()?.close();
  
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