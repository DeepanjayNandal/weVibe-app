import { createApp } from './app';
import { prisma } from './db/prisma-client';
import { env } from './config/env';
import { startPhotoCleanupJob } from './jobs/photo-cleanup.job';

const app = createApp();

const server = app.listen(env.port, '0.0.0.0', () => {
  console.log(`API server running on port ${env.port}`);
  // Start background jobs after the server is listening and Firebase is initialised.
  startPhotoCleanupJob();
});

async function shutdown(signal: string) {
  console.log(`${signal} received. Shutting down...`);
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