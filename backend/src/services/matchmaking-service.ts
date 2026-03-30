import { Prisma, enum_meet_gender } from '@prisma/client';
import { prisma } from '../db/prisma-client';
import { MatchService } from './match-service';
import { MatchingQueueRepository } from '../repositories/matching-queue-repository';
import { badRequest } from '../utils/errors';

type DbClient = Prisma.TransactionClient | typeof prisma;

type UserWithProfile = Prisma.usersGetPayload<{
  include: {
    profiles: true;
  };
}>;

export type CandidateScore = {
  userId: string;
  displayName: string | null;
  scoreForward: number;
  scoreBackward: number;
  scoreCombined: number;
};

export type JoinQueueResult =
  | {
      state: 'waiting';
      queueJoinedAt: Date;
      poolSize: number;
    }
  | {
      state: 'matched';
      queueJoinedAt: Date;
      poolSize: number;
      selectedCandidate: CandidateScore;
      sessionId: string;
      sessionExpiresAt: Date | null;
    };

const DEFAULT_AGE_MIN = 18;
const DEFAULT_AGE_MAX = 35;
const DEFAULT_RADIUS_KM = 50;
const SPEED_DATING_EXPIRY_HOURS = 24;
const OPEN_SPEED_DATING_STATUSES = [
  'active',
  'active_counter_pending',
  'active_request_locked',
  'awaiting_decision',
  'awaiting_counter_decision',
  'awaiting_decision_locked',
];

function calculateAge(birthDate: Date | null): number | null {
  if (!birthDate) return null;

  const today = new Date();
  let age = today.getFullYear() - birthDate.getFullYear();
  const monthDiff = today.getMonth() - birthDate.getMonth();
  if (monthDiff < 0 || (monthDiff === 0 && today.getDate() < birthDate.getDate())) {
    age--;
  }
  return age;
}

function profileToMeetGender(profile: { sex?: string | null; gender?: string | null }): enum_meet_gender | null {
  const sex = (profile.sex || '').toLowerCase();
  if (sex === 'male') return 'men';
  if (sex === 'female') return 'women';

  const gender = (profile.gender || '').trim().toLowerCase();
  if (gender === 'female' || gender === 'woman' || gender === 'women') return 'women';
  if (gender === 'male' || gender === 'man' || gender === 'men') return 'men';

  return null;
}

function matchesGenderPreference(
  preference: enum_meet_gender | null,
  candidateProfile: { sex?: string | null; gender?: string | null } | null,
): boolean {
  if (!candidateProfile) return false;
  if (!preference || preference === 'both') return true;

  const candidateMeetGender = profileToMeetGender(candidateProfile);
  return candidateMeetGender === preference;
}

function withinRange(value: number | null, min: number | null, max: number | null): boolean {
  if (value === null) return false;
  if (min !== null && value < min) return false;
  if (max !== null && value > max) return false;
  return true;
}

function resolveAgeRange(user: { search_age_min: number | null; search_age_max: number | null }): {
  min: number;
  max: number;
} {
  const min = user.search_age_min ?? DEFAULT_AGE_MIN;
  const max = user.search_age_max ?? DEFAULT_AGE_MAX;
  return { min, max };
}

function resolveRadiusKm(user: { search_radius_km: number | null }): number {
  return user.search_radius_km ?? DEFAULT_RADIUS_KM;
}

export class MatchmakingService {
  constructor(
    private readonly queueRepository: MatchingQueueRepository,
    private readonly matchService: MatchService,
  ) {}

  async leaveQueue(userId: string): Promise<void> {
    await this.queueRepository.dequeue(userId);
  }

  async getQueueStatus(userId: string): Promise<{ inQueue: boolean }> {
    return {
      inQueue: await this.queueRepository.isInQueue(userId),
    };
  }

  async joinQueueAndMatch(userId: string): Promise<JoinQueueResult> {
    return prisma.$transaction(async (tx) => {
      await this.acquireTransactionLock(userId, tx);

      const requester = await tx.users.findUnique({
        where: { id: userId },
        include: { profiles: true },
      });

      if (!requester || !requester.profiles) {
        badRequest('A completed profile is required before joining queue', 'PROFILE_REQUIRED');
      }

      if (await this.hasOpenSpeedDatingSession(userId, tx)) {
        badRequest('Finish your current speed dating session before joining queue', 'ACTIVE_SESSION_EXISTS');
      }

      await this.queueRepository.enqueue(userId, tx);

      const queueEntry = await tx.matching_queue.findUnique({ where: { user_id: userId } });
      if (!queueEntry) {
        badRequest('Failed to create queue entry', 'QUEUE_JOIN_FAILED');
      }

      const queueCandidates = await this.queueRepository.getCandidatesFor(userId, tx);
      const scoredPool: CandidateScore[] = [];

      for (const candidateEntry of queueCandidates) {
        const candidate = candidateEntry.users;
        if (await this.hasOpenSpeedDatingSession(candidate.id, tx)) {
          continue;
        }

        const isEligible = await this.passesHardFilter(requester, candidate, tx);
        if (!isEligible || !candidate.profiles) {
          continue;
        }

        const scoreForward = this.matchService.computeCompatibility(requester.profiles, candidate.profiles);
        const scoreBackward = this.matchService.computeCompatibility(candidate.profiles, requester.profiles);
        const scoreCombined = (scoreForward + scoreBackward) / 2;

        scoredPool.push({
          userId: candidate.id,
          displayName: candidate.profiles.display_name,
          scoreForward,
          scoreBackward,
          scoreCombined,
        });
      }

      scoredPool.sort((a, b) => {
        if (b.scoreCombined !== a.scoreCombined) {
          return b.scoreCombined - a.scoreCombined;
        }
        return a.userId.localeCompare(b.userId);
      });

      if (scoredPool.length === 0) {
        return {
          state: 'waiting',
          queueJoinedAt: queueEntry.joined_at,
          poolSize: 0,
        };
      }

      for (const picked of scoredPool) {
        await this.acquireTransactionLock(this.buildPairLockKey(userId, picked.userId), tx);

        const [requesterQueueRow, candidateQueueRow] = await Promise.all([
          tx.matching_queue.findUnique({ where: { user_id: userId }, select: { user_id: true } }),
          tx.matching_queue.findUnique({ where: { user_id: picked.userId }, select: { user_id: true } }),
        ]);

        if (!requesterQueueRow || !candidateQueueRow) {
          continue;
        }

        const existingPairSession = await this.findOpenSessionBetweenUsers(userId, picked.userId, tx);
        if (existingPairSession) {
          continue;
        }

        const expiresAt = new Date(Date.now() + SPEED_DATING_EXPIRY_HOURS * 60 * 60 * 1000);
        const session = await tx.speed_dating_sessions.create({
          data: {
            user_a_id: userId,
            user_b_id: picked.userId,
            started_at: new Date(),
            expires_at: expiresAt,
            status: 'active',
          },
        });

        await this.queueRepository.dequeuePair(userId, picked.userId, tx);

        return {
          state: 'matched',
          queueJoinedAt: queueEntry.joined_at,
          poolSize: scoredPool.length,
          selectedCandidate: picked,
          sessionId: session.id,
          sessionExpiresAt: session.expires_at,
        };
      }

      return {
        state: 'waiting',
        queueJoinedAt: queueEntry.joined_at,
        poolSize: scoredPool.length,
      };
    });
  }

  private buildPairLockKey(userAId: string, userBId: string): string {
    const [first, second] = [userAId, userBId].sort();
    return `${first}:${second}`;
  }

  private async acquireTransactionLock(lockKey: string, db: DbClient): Promise<void> {
    await db.$executeRaw(
      Prisma.sql`SELECT pg_advisory_xact_lock(hashtextextended(${lockKey}, 0))`,
    );
  }

  private async findOpenSessionBetweenUsers(
    userAId: string,
    userBId: string,
    db: DbClient,
  ): Promise<{ id: string } | null> {
    return db.speed_dating_sessions.findFirst({
      where: {
        status: { in: OPEN_SPEED_DATING_STATUSES },
        expires_at: {
          gt: new Date(),
        },
        OR: [
          {
            user_a_id: userAId,
            user_b_id: userBId,
          },
          {
            user_a_id: userBId,
            user_b_id: userAId,
          },
        ],
      },
      select: { id: true },
    });
  }

  private async hasOpenSpeedDatingSession(userId: string, db: DbClient): Promise<boolean> {
    const openSessionCount = await db.speed_dating_sessions.count({
      where: {
        status: { in: OPEN_SPEED_DATING_STATUSES },
        expires_at: {
          gt: new Date(),
        },
        OR: [{ user_a_id: userId }, { user_b_id: userId }],
      },
    });

    return openSessionCount > 0;
  }

  private async passesHardFilter(
    requester: UserWithProfile,
    candidate: UserWithProfile,
    db: DbClient,
  ): Promise<boolean> {
    if (!requester.profiles || !candidate.profiles) return false;

    const blockedPair = await db.user_blocks.findFirst({
      where: {
        OR: [
          {
            blocker_user_id: requester.id,
            blocked_user_id: candidate.id,
          },
          {
            blocker_user_id: candidate.id,
            blocked_user_id: requester.id,
          },
        ],
      },
      select: { id: true },
    });

    if (blockedPair) return false;

    const requesterAge = calculateAge(requester.profiles.birth_date);
    const candidateAge = calculateAge(candidate.profiles.birth_date);

    const requesterAgeRange = resolveAgeRange(requester);
    const candidateAgeRange = resolveAgeRange(candidate);

    const requesterGenderOk = matchesGenderPreference(requester.search_gender, candidate.profiles);
    const candidateGenderOk = matchesGenderPreference(candidate.search_gender, requester.profiles);

    const requesterAgeOk = withinRange(candidateAge, requesterAgeRange.min, requesterAgeRange.max);
    const candidateAgeOk = withinRange(requesterAge, candidateAgeRange.min, candidateAgeRange.max);

    if (!requesterGenderOk || !candidateGenderOk || !requesterAgeOk || !candidateAgeOk) {
      return false;
    }

    const distanceKm = await this.getDistanceKm(requester.id, candidate.id, db);
    if (distanceKm === null) return false;

    const requesterRadius = resolveRadiusKm(requester);
    const candidateRadius = resolveRadiusKm(candidate);

    return distanceKm <= requesterRadius && distanceKm <= candidateRadius;
  }

  private async getDistanceKm(userAId: string, userBId: string, db: DbClient): Promise<number | null> {
    const rows = await db.$queryRaw<Array<{ distance_km: number | null }>>(
      Prisma.sql`
        SELECT
          CASE
            WHEN p1.location_point IS NULL OR p2.location_point IS NULL THEN NULL
            ELSE ST_DistanceSphere(p1.location_point::geometry, p2.location_point::geometry) / 1000
          END AS distance_km
        FROM profiles p1
        JOIN profiles p2 ON true
        WHERE p1.user_id = CAST(${userAId} AS uuid)
          AND p2.user_id = CAST(${userBId} AS uuid)
        LIMIT 1
      `,
    );

    if (rows.length === 0 || rows[0].distance_km === null) {
      return null;
    }

    return Number(rows[0].distance_km);
  }
}
