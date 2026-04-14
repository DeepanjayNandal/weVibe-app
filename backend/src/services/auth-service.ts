import { users } from '@prisma/client';
import { UserRepository } from '../repositories/user-repository';
import { forbidden, unauthorized } from '../utils/errors';
import { AuthVerifier } from './auth/auth-verifier';
import { LoginInput, RegisterInput } from './auth/types';

export class AuthService {
  constructor(
    private readonly userRepository: UserRepository,
    private readonly authVerifier: AuthVerifier,
  ) {}

  async register(input: RegisterInput): Promise<users> {
    const identity = await this.authVerifier.verifyIdToken(input.idToken, input.provider);

    const byUid = await this.userRepository.findByFirebaseUid(identity.uid);
    if (byUid) {
      // Already registered with this Firebase UID — idempotent retry.
      // The backend created the user but the 201 response was lost before iOS
      // received it (network failure). Return the existing record so iOS can proceed.
      return byUid;
    }

    const byEmail = await this.userRepository.findByEmail(identity.email);
    if (byEmail) {
      // Email exists with a DIFFERENT Firebase UID — this is a re-registration after
      // a rollback failure: the backend wrote the user record but iOS deleted the old
      // Firebase account during rollback and created a new one. Re-link the new UID
      // to the existing backend record so the user can continue onboarding.
      // Safe: Firebase already verified the user owns this email when it issued the token.
      return this.userRepository.linkFirebaseIdentity(byEmail.id, identity);
    }

    const created = await this.userRepository.createFromIdentity(identity);
    return created;
  }

  async login(input: LoginInput): Promise<users> {
    const identity = await this.authVerifier.verifyIdToken(input.idToken, input.provider);

    let user = await this.userRepository.findByFirebaseUid(identity.uid);
    if (!user) {
      const byEmail = await this.userRepository.findByEmail(identity.email);
      if (!byEmail) {
        user = await this.userRepository.createFromIdentity(identity);
      } else {
        // Email found but firebase_uid either missing or stale.
        // "Allow multiple accounts per email" is disabled in Firebase, so one email
        // always maps to exactly one Firebase UID. If the stored UID differs from
        // what Firebase returned, the account was re-linked (e.g. provider switch,
        // rollback re-registration). Update it so future logins resolve via byUid
        // on the first lookup without falling back to email.
        user = await this.userRepository.linkFirebaseIdentity(byEmail.id, identity);
      }
    }

    if (!user) {
      unauthorized('Unable to login with provided token', 'LOGIN_FAILED');
    }

    if (user.is_banned) {
      forbidden('User is banned', 'USER_BANNED');
    }

    // Grace period reactivation: if the user deleted their account but returns
    // within 30 days, clear deleted_at and restore their account silently.
    if (user.deleted_at) {
      const cutoff = new Date(Date.now() - 30 * 24 * 60 * 60 * 1000);
      if (user.deleted_at > cutoff) {
        await this.userRepository.reactivateUser(user.id);
        user = { ...user, deleted_at: null };
      } else {
        forbidden('Account has been deleted', 'USER_DELETED');
      }
    }

    await this.userRepository.touchLastActive(user.id);
    return user;
  }

  async me(idToken: string): Promise<users> {
    const identity = await this.authVerifier.verifyIdToken(idToken);
    let user = await this.userRepository.findByFirebaseUid(identity.uid);
    if (!user) {
      const byEmail = await this.userRepository.findByEmail(identity.email);
      if (byEmail) {
        // Stale UID — heal it so future /auth/me calls resolve on the first lookup.
        user = await this.userRepository.linkFirebaseIdentity(byEmail.id, identity);
      }
    }

    if (!user) {
      unauthorized('User not found', 'USER_NOT_FOUND');
    }

    if (user.is_banned) {
      forbidden('User is banned', 'USER_BANNED');
    }

    if (user.deleted_at) {
      forbidden('Account has been deleted', 'USER_DELETED');
    }

    return user;
  }

  async logout(_idToken: string): Promise<void> {
    return;
  }
}
