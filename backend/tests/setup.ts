process.env.AUTH_PROVIDER_MODE = 'mock';

// Disconnect the shared appPrisma singleton after each test file's worker.
// Each Jest worker has its own module instance, so this is safe with maxWorkers: 1.
import { prisma as appPrisma } from '../src/db/prisma-client';

afterAll(async () => {
  await appPrisma.$disconnect();
});