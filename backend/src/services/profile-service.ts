import { profiles } from '@prisma/client';
import { ProfileRepository, UpdateProfileData } from '../repositories/profile-repository';
import { conflict } from '../utils/errors';

// Full input for creating a profile (all required + optional onboarding fields)
export interface CreateProfileInput {
  userId: string;

  // Basic info
  firstName?: string | null;
  lastName?: string | null;
  birthDate: Date;
  gender: string;
  ethnicity?: string[] | null;

  // Career & education — collected during onboarding Step 4
  education?: string | null;
  careerField?: string | null;
  languages?: string[] | null;

  // Height (all optional — conditional on height_unit)
  heightUnit?: string | null;
  heightFt?: number | null;
  heightIn?: number | null;
  heightCm?: number | null;

  // Location
  latitude: number;
  longitude: number;
  locationCity: string;
  locationState: string;
  locationZip: string;

  // Dating preferences
  meetPreference: string;
  relationshipGoals: string[];
  minAgePreference: number;
  maxAgePreference: number;
  distancePreferenceMiles: number;

  // Lifestyle habits (optional)
  drinks?: string | null;
  smoking?: string | null;
  pets?: string | null;
  children?: string | null;
  workout?: string | null;
  sleepSchedule?: string | null;

  // Bio (optional)
  bio?: string | null;

  // Prompts (optional, max 4, shape: { question, answer })
  prompts?: Array<{ question: string; answer: string }> | null;
}

// Re-export so controllers can import from one place
export type { UpdateProfileData };

export class ProfileService {
  constructor(private readonly profileRepository: ProfileRepository) {}

  async getProfile(userId: string): Promise<profiles | null> {
    return this.profileRepository.findByUserId(userId);
  }

  async createProfile(input: CreateProfileInput): Promise<profiles> {
    // Prevent duplicate profiles for the same user
    const existing = await this.profileRepository.findByUserId(input.userId);
    if (existing) {
      conflict('Profile already exists for this user', 'PROFILE_ALREADY_EXISTS');
    }

    return this.profileRepository.create({
      userId:                  input.userId,
      firstName:               input.firstName ?? null,
      lastName:                input.lastName ?? null,
      displayName:             input.firstName && input.lastName ? `${input.firstName} ${input.lastName}`.trim() : null,
      birthDate:               input.birthDate,
      gender:                  input.gender,
      ethnicity:               input.ethnicity ?? null,
      education:               input.education ?? null,
      careerField:             input.careerField ?? null,
      languages:               input.languages ?? null,
      heightUnit:              input.heightUnit ?? null,
      heightFt:                input.heightFt,
      heightIn:                input.heightIn,
      heightCm:                input.heightCm,
      latitude:                input.latitude,
      longitude:               input.longitude,
      locationCity:            input.locationCity,
      locationState:           input.locationState,
      locationZip:             input.locationZip,
      meetPreference:          input.meetPreference,
      relationshipGoals:       input.relationshipGoals,
      minAgePreference:        input.minAgePreference,
      maxAgePreference:        input.maxAgePreference,
      distancePreferenceMiles: input.distancePreferenceMiles,
      drinks:                  input.drinks,
      smoking:                 input.smoking,
      pets:                    input.pets,
      children:                input.children,
      workout:                 input.workout,
      sleepSchedule:           input.sleepSchedule,
      bio:                     input.bio,
      prompts:                 input.prompts,
    });
  }

  async updateProfile(userId: string, data: UpdateProfileData): Promise<profiles | null> {
    // Return null if no profile exists — controller converts this to 401 PROFILE_NOT_FOUND
    const existing = await this.profileRepository.findByUserId(userId);
    if (!existing) {
      return null;
    }

    return this.profileRepository.update(userId, data);
  }
}
