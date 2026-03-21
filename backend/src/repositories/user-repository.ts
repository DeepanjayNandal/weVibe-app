import { users } from '@prisma/client';
import { prisma } from '../db/prisma-client';
import { AuthIdentity } from '../services/auth/types';

export class UserRepository {
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
}
