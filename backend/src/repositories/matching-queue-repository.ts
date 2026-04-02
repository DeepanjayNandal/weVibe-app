import { Prisma } from '@prisma/client';
import { prisma } from '../db/prisma-client';

type DbClient = Prisma.TransactionClient | typeof prisma;

export type QueueCandidate = Prisma.matching_queueGetPayload<{
  include: {
    users: {
      include: {
        profiles: true;
      };
    };
  };
}>;

export class MatchingQueueRepository {
  async enqueue(userId: string, db: DbClient = prisma): Promise<void> {
    await db.matching_queue.upsert({
      where: { user_id: userId },
      update: { joined_at: new Date() },
      create: { user_id: userId },
    });
  }

  async dequeue(userId: string, db: DbClient = prisma): Promise<void> {
    await db.matching_queue.deleteMany({ where: { user_id: userId } });
  }

  async dequeuePair(userAId: string, userBId: string, db: DbClient = prisma): Promise<void> {
    await db.matching_queue.deleteMany({
      where: {
        user_id: { in: [userAId, userBId] },
      },
    });
  }

  async isInQueue(userId: string, db: DbClient = prisma): Promise<boolean> {
    const entry = await db.matching_queue.findUnique({ where: { user_id: userId } });
    return Boolean(entry);
  }

  async getCandidatesFor(userId: string, db: DbClient = prisma): Promise<QueueCandidate[]> {
    return db.matching_queue.findMany({
      where: {
        user_id: { not: userId },
        users: { deleted_at: null },
      },
      orderBy: {
        joined_at: 'asc',
      },
      include: {
        users: {
          include: {
            profiles: true,
          },
        },
      },
    });
  }
}
