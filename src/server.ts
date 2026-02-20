import { createApp } from './app';
import { prisma } from './db/prisma-client';
import { env } from './config/env';

const app = createApp();

const server = app.listen(env.port, () => {
  console.log(`API server running on port ${env.port}`);
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
