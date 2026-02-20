import { users } from '@prisma/client';
import { UserRepository } from '../repositories/user-repository';
import { conflict, forbidden, unauthorized } from '../utils/errors';
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
      conflict('User already exists', 'USER_ALREADY_EXISTS');
    }

    const byEmail = await this.userRepository.findByEmail(identity.email);
    if (byEmail) {
      conflict('Email already registered', 'EMAIL_ALREADY_EXISTS');
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
      } else if (!byEmail.firebase_uid) {
        user = await this.userRepository.linkFirebaseIdentity(byEmail.id, identity);
      } else {
        user = byEmail;
      }
    }

    if (!user) {
      unauthorized('Unable to login with provided token', 'LOGIN_FAILED');
    }

    if (user.is_banned) {
      forbidden('User is banned', 'USER_BANNED');
    }

    await this.userRepository.touchLastActive(user.id);
    return user;
  }

  async me(idToken: string): Promise<users> {
    const identity = await this.authVerifier.verifyIdToken(idToken);
    const user = (await this.userRepository.findByFirebaseUid(identity.uid))
      ?? (await this.userRepository.findByEmail(identity.email));

    if (!user) {
      unauthorized('User not found', 'USER_NOT_FOUND');
    }

    if (user.is_banned) {
      forbidden('User is banned', 'USER_BANNED');
    }

    return user;
  }

  async logout(_idToken: string): Promise<void> {
    return;
  }
}
