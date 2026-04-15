import * as admin from 'firebase-admin';
import { UserRepository } from '../repositories/user-repository';
import { badRequest, notFound } from '../utils/errors';
import { revokeAppleToken } from './apple-auth-service';

export class UserService {
  constructor(private readonly userRepository: UserRepository) {}

  async updateFcmToken(firebaseUid: string, fcmToken: string): Promise<void> {
    const user = await this.userRepository.findByFirebaseUid(firebaseUid);
    if (!user) {
      notFound('User not found', 'USER_NOT_FOUND');
    }
    await this.userRepository.updateFcmToken(user.id, fcmToken);
  }

  // Soft-deletes the authenticated user's account.
  // - Sets deleted_at to now (blocks login immediately)
  // - Revokes all Firebase refresh tokens (forces logout on all devices)
  // The row is hard-deleted after 30 days by the purge sweep in server.ts.
  async deleteAccount(firebaseUid: string): Promise<void> {
    const user = await this.userRepository.findByFirebaseUid(firebaseUid);
    if (!user) {
      notFound('User not found', 'USER_NOT_FOUND');
    }

    if (user.deleted_at) {
      badRequest('Account is already deleted', 'ACCOUNT_ALREADY_DELETED');
    }

    await this.userRepository.softDeleteUser(user.id);

    // Revoke Firebase tokens so the user is logged out on all devices immediately.
    // This is best-effort — soft delete has already been committed above.
    if (admin.apps.length > 0) {
      await admin.auth().revokeRefreshTokens(firebaseUid);
    } else {
      console.warn('[user_service] Firebase Admin not initialized — Firebase tokens were NOT revoked for uid:', firebaseUid);
    }

    // Revoke Apple refresh token if this is an Apple Sign-In account.
    // Required by App Store Review Guideline 5.1.1.
    // Best-effort: deletion is already committed, so failure here is logged but not thrown.
    if (user.auth_provider === 'apple' && user.apple_refresh_token) {
      // Use the production bundle ID — account deletion only applies to App Store builds.
      await revokeAppleToken(user.apple_refresh_token, 'com.wevibe1.app');
    }
  }
}
