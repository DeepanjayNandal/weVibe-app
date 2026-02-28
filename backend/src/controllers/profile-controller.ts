import { Request, Response } from 'express';
import { profiles } from '@prisma/client';
import { ProfileService } from '../services/profile-service';
import { UserRepository } from '../repositories/user-repository';
import { badRequest, unauthorized } from '../utils/errors';

const VALID_GENDERS = ['Male', 'Female', 'Non-binary', 'Prefer not to say'];

function readRequiredString(value: unknown, fieldName: string, errorCode: string): string {
  if (typeof value !== 'string' || value.trim().length === 0) {
    badRequest(`${fieldName} is required`, errorCode);
  }
  return value.trim();
}

function readBirthDate(value: unknown): Date {
  if (typeof value !== 'string' || value.trim().length === 0) {
    badRequest('birth_date is required', 'MISSING_BIRTH_DATE');
  }

  const date = new Date(value.trim());
  if (isNaN(date.getTime())) {
    badRequest('birth_date must be a valid date (YYYY-MM-DD)', 'INVALID_BIRTH_DATE');
  }

  return date;
}

function readGender(value: unknown): string {
  if (typeof value !== 'string' || value.trim().length === 0) {
    badRequest('gender is required', 'MISSING_GENDER');
  }

  const gender = value.trim();
  if (!VALID_GENDERS.includes(gender)) {
    badRequest(
      `gender must be one of: ${VALID_GENDERS.join(', ')}`,
      'INVALID_GENDER',
    );
  }

  return gender;
}

function serializeProfile(profile: profiles): Record<string, unknown> {
  return {
    userId: profile.user_id,
    displayName: profile.display_name,
    birthDate: profile.birth_date,
    gender: profile.gender,
  };
}

export class ProfileController {
  constructor(
    private readonly profileService: ProfileService,
    private readonly userRepository: UserRepository,
  ) {}

  createProfile = async (req: Request, res: Response): Promise<void> => {
    // req.auth is set by authenticate middleware — contains Firebase uid
    const firebaseUid = req.auth?.uid;
    if (!firebaseUid) {
      unauthorized('User identity not found in request', 'MISSING_USER_IDENTITY');
    }

    // Resolve DB user id from firebase uid
    const user = await this.userRepository.findByFirebaseUid(firebaseUid);
    if (!user) {
      unauthorized('User not found in database', 'USER_NOT_FOUND');
    }

    const firstName = readRequiredString(req.body?.first_name, 'first_name', 'MISSING_FIRST_NAME');
    const lastName = readRequiredString(req.body?.last_name, 'last_name', 'MISSING_LAST_NAME');
    const birthDate = readBirthDate(req.body?.birth_date);
    const gender = readGender(req.body?.gender);

    const profile = await this.profileService.createProfile({
      userId: user.id,
      firstName,
      lastName,
      birthDate,
      gender,
    });

    res.status(201).json({
      success: true,
      data: {
        profile: serializeProfile(profile),
      },
    });
  };
}
