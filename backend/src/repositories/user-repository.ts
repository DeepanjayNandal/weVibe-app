import { users } from '@prisma/client';
import { prisma } from '../db/prisma-client';
import { AuthIdentity } from '../services/auth/types';

export class UserRepository {
  async findById(id: string): Promise<users | null> {
    return prisma.users.findUnique({ where: { id } });
  }

  async findByEmail(email: string): Promise<users | null> {
    return prisma.users.findUnique({ where: { email } });
  }

  async findByFirebaseUid(firebaseUid: string): Promise<users | null> {
    return prisma.users.findUnique({ where: { firebase_uid: firebaseUid } });
  }

  async createFromIdentity(identity: AuthIdentity): Promise<users> {
    return prisma.users.create({
      data: {
        email: identity.email,
        firebase_uid: identity.uid,
        auth_provider: identity.provider,
      },
    });
  }

  async linkFirebaseIdentity(userId: string, identity: AuthIdentity): Promise<users> {
    return prisma.users.update({
      where: { id: userId },
      data: {
        firebase_uid: identity.uid,
        auth_provider: identity.provider,
      },
    });
  }

  async touchLastActive(userId: string): Promise<void> {
    await prisma.users.update({
      where: { id: userId },
      data: {
        last_active_at: new Date(),
      },
    });
  }

  // Marks the user as having completed onboarding.
  // Called after POST /api/v1/users/profile succeeds so iOS knows to skip onboarding on next login.
  async setOnboardingComplete(userId: string): Promise<void> {
    await prisma.users.update({
      where: { id: userId },
      data: { onboarding_complete: true },
    });
  }

  // Soft-deletes the user by setting deleted_at to now.
  // The user is blocked from logging in immediately.
  // After 30 days, purgeDeletedUsers() hard-deletes the row.
  async softDeleteUser(userId: string): Promise<void> {
    await prisma.users.update({
      where: { id: userId },
      data: { deleted_at: new Date() },
    });
  }

  // Clears deleted_at, reactivating an account within the 30-day grace period.
  async reactivateUser(userId: string): Promise<void> {
    await prisma.users.update({
      where: { id: userId },
      data: { deleted_at: null },
    });
  }

  // Hard-deletes all users whose deleted_at is older than 30 days.
  // CASCADE deletes all related rows (profiles, matches, messages, etc.).
  // Called by the purge sweep in server.ts.
  async purgeDeletedUsers(): Promise<number> {
    const cutoff = new Date(Date.now() - 30 * 24 * 60 * 60 * 1000);
    const result = await prisma.users.deleteMany({
      where: { deleted_at: { lte: cutoff } },
    });
    return result.count;
  }
}
