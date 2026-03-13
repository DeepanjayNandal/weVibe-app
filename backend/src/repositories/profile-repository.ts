import { profiles } from '@prisma/client';
import { prisma } from '../db/prisma-client';

// Data required to create a new profile (full onboarding payload)
export interface CreateProfileData {
  userId: string;

  // Basic info (first_name, last_name, ethnicity optional)
  firstName?: string | null;
  lastName?: string | null;
  displayName?: string | null;
  birthDate: Date;
  gender: string;
  // ethnicity is a JSON array of strings (multi-select)
  ethnicity?: string[] | null;
  education?: string | null;

  // Height (optional — only provided when height_unit is present)
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

  // Preferences
  meetPreference: string;
  relationshipGoals: string[];
  minAgePreference: number;
  maxAgePreference: number;
  distancePreferenceMiles: number;

  // Lifestyle habits (all optional)
  drinks?: string | null;
  smoking?: string | null;
  pets?: string | null;
  children?: string | null;
  workout?: string | null;
  sleepSchedule?: string | null;

  // Bio (optional)
  bio?: string | null;

  // Prompts (optional, 0-3 items)
  prompts?: Array<{ question: string; answer: string; is_custom: boolean }> | null;
}

// Data allowed for partial profile updates (all fields optional)
export interface UpdateProfileData {
  firstName?: string | null;
  lastName?: string | null;
  displayName?: string | null;
  birthDate?: Date;
  gender?: string;
  ethnicity?: string[] | null;
  education?: string | null;
  heightUnit?: string;
  heightFt?: number | null;
  heightIn?: number | null;
  heightCm?: number | null;
  latitude?: number;
  longitude?: number;
  locationCity?: string;
  locationState?: string;
  locationZip?: string;
  meetPreference?: string;
  relationshipGoals?: string[];
  minAgePreference?: number;
  maxAgePreference?: number;
  distancePreferenceMiles?: number;
  drinks?: string | null;
  smoking?: string | null;
  pets?: string | null;
  children?: string | null;
  workout?: string | null;
  sleepSchedule?: string | null;
  bio?: string | null;
  prompts?: Array<{ question: string; answer: string; is_custom: boolean }> | null;
}

export class ProfileRepository {
  async findByUserId(userId: string): Promise<profiles | null> {
    return prisma.profiles.findUnique({ where: { user_id: userId } });
  }

  async create(data: CreateProfileData): Promise<profiles> {
    return prisma.profiles.create({
      data: {
        user_id:                   data.userId,
        first_name:                data.firstName,
        last_name:                 data.lastName,
        display_name:              data.displayName ?? null,
        birth_date:                data.birthDate,
        gender:                    data.gender,
        ethnicity:                 data.ethnicity ?? null,
        education:                 data.education ?? null,

        // Height
        height_unit:               data.heightUnit,
        height_ft:                 data.heightFt ?? null,
        height_in:                 data.heightIn ?? null,
        height_cm:                 data.heightCm ?? null,

        // Location (lat/lng stored as plain floats; location_point left null here
        // — update it separately via raw SQL if PostGIS queries are needed)
        latitude:                  data.latitude,
        longitude:                 data.longitude,
        location_city:             data.locationCity,
        state:                     data.locationState,   // DB column name is state
        zip_code:                  data.locationZip,     // DB column name is zip_code

        // Preferences
        meet_preference:           data.meetPreference as any,
        relationship_goals:        data.relationshipGoals,
        min_age_preference:        data.minAgePreference,
        max_age_preference:        data.maxAgePreference,
        distance_preference_miles: data.distancePreferenceMiles,

        // Lifestyle
        lifestyle_drinks:          data.drinks as any ?? null,
        lifestyle_smoking:         data.smoking as any ?? null,
        lifestyle_pets:            data.pets as any ?? null,
        lifestyle_children:        data.children as any ?? null,
        lifestyle_workout:         data.workout as any ?? null,
        lifestyle_sleep:           data.sleepSchedule as any ?? null,

        // Bio and prompts
        bio:                       data.bio ?? null,
        prompts:                   data.prompts ?? null,
      },
    });
  }

  // Partial update — only fields present in data are updated
  async update(userId: string, data: UpdateProfileData): Promise<profiles> {
    // Build the update object dynamically — only include keys that were passed
    const updatePayload: Record<string, unknown> = {};

    if (data.firstName       !== undefined) updatePayload.first_name                = data.firstName;
    if (data.lastName        !== undefined) updatePayload.last_name                 = data.lastName;
    if (data.displayName     !== undefined) updatePayload.display_name              = data.displayName;
    if (data.birthDate       !== undefined) updatePayload.birth_date                = data.birthDate;
    if (data.gender          !== undefined) updatePayload.gender                    = data.gender;
    if (data.ethnicity       !== undefined) updatePayload.ethnicity                 = data.ethnicity;
    if (data.education       !== undefined) updatePayload.education                 = data.education;
    if (data.heightUnit      !== undefined) updatePayload.height_unit               = data.heightUnit;
    if (data.heightFt        !== undefined) updatePayload.height_ft                 = data.heightFt;
    if (data.heightIn        !== undefined) updatePayload.height_in                 = data.heightIn;
    if (data.heightCm        !== undefined) updatePayload.height_cm                 = data.heightCm;
    if (data.latitude        !== undefined) updatePayload.latitude                  = data.latitude;
    if (data.longitude       !== undefined) updatePayload.longitude                 = data.longitude;
    if (data.locationCity    !== undefined) updatePayload.location_city             = data.locationCity;
    if (data.locationState   !== undefined) updatePayload.state                     = data.locationState;
    if (data.locationZip     !== undefined) updatePayload.zip_code                  = data.locationZip;
    if (data.meetPreference  !== undefined) updatePayload.meet_preference            = data.meetPreference;
    if (data.relationshipGoals !== undefined) updatePayload.relationship_goals      = data.relationshipGoals;
    if (data.minAgePreference  !== undefined) updatePayload.min_age_preference      = data.minAgePreference;
    if (data.maxAgePreference  !== undefined) updatePayload.max_age_preference      = data.maxAgePreference;
    if (data.distancePreferenceMiles !== undefined) updatePayload.distance_preference_miles = data.distancePreferenceMiles;
    if (data.drinks          !== undefined) updatePayload.lifestyle_drinks           = data.drinks;
    if (data.smoking         !== undefined) updatePayload.lifestyle_smoking          = data.smoking;
    if (data.pets            !== undefined) updatePayload.lifestyle_pets             = data.pets;
    if (data.children        !== undefined) updatePayload.lifestyle_children         = data.children;
    if (data.workout         !== undefined) updatePayload.lifestyle_workout          = data.workout;
    if (data.sleepSchedule   !== undefined) updatePayload.lifestyle_sleep            = data.sleepSchedule;
    if (data.bio             !== undefined) updatePayload.bio                        = data.bio;
    if (data.prompts         !== undefined) updatePayload.prompts                    = data.prompts;

    return prisma.profiles.update({
      where: { user_id: userId },
      data: updatePayload as any,
    });
  }
}
