import { profiles } from '@prisma/client';
import { ProfileRepository } from '../repositories/profile-repository';
import { conflict } from '../utils/errors';

export interface CreateProfileInput {
  userId: string;
  firstName: string;
  lastName: string;
  birthDate: Date;
  gender: string;
}

export class ProfileService {
  constructor(private readonly profileRepository: ProfileRepository) {}

  async getProfile(userId: string): Promise<profiles | null> {
    return this.profileRepository.findByUserId(userId);
  }

  async createProfile(input: CreateProfileInput): Promise<profiles> {
    const existing = await this.profileRepository.findByUserId(input.userId);
    if (existing) {
      conflict('Profile already exists for this user', 'PROFILE_ALREADY_EXISTS');
    }

    return this.profileRepository.create({
      userId: input.userId,
      displayName: `${input.firstName} ${input.lastName}`.trim(),
      birthDate: input.birthDate,
      gender: input.gender,
    });
  }
}
