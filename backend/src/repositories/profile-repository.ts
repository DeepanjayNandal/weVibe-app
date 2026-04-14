import { Prisma, enum_meet_gender, profiles } from '@prisma/client';
import { prisma } from '../db/prisma-client';

type DbClient = Prisma.TransactionClient | typeof prisma;

function mapMeetPreferenceToSearchGender(value: string | null | undefined): enum_meet_gender | null | undefined {
  if (value === undefined) return undefined;
  if (value === null) return null;

  if (value === 'Men') return 'men';
  if (value === 'Women') return 'women';
  if (value === 'Open to both') return 'both';

  return undefined;
}

function milesToKilometers(miles: number | null): number | null {
  if (miles === null) return null;
  return Math.max(1, Math.round(miles * 1.60934));
}

function buildUserSearchUpdate(data: {
  meetPreference?: string | null;
  minAgePreference?: number | null;
  maxAgePreference?: number | null;
  distancePreferenceMiles?: number | null;
}): Prisma.usersUncheckedUpdateInput {
  const userUpdate: Prisma.usersUncheckedUpdateInput = {};

  const mappedGender = mapMeetPreferenceToSearchGender(data.meetPreference);
  if (mappedGender !== undefined) {
    userUpdate.search_gender = mappedGender;
  }

  if (data.minAgePreference !== undefined) {
    userUpdate.search_age_min = data.minAgePreference;
  }

  if (data.maxAgePreference !== undefined) {
    userUpdate.search_age_max = data.maxAgePreference;
  }

  if (data.distancePreferenceMiles !== undefined) {
    userUpdate.search_radius_km = milesToKilometers(data.distancePreferenceMiles);
  }

  return userUpdate;
}

async function updateLocationPoint(
  db: DbClient,
  userId: string,
  latitude: number | null,
  longitude: number | null,
): Promise<void> {
  if (latitude === null || longitude === null) {
    await db.$executeRaw(
      Prisma.sql`
        UPDATE profiles
        SET location_point = NULL
        WHERE user_id = CAST(${userId} AS uuid)
      `,
    );
    return;
  }

  await db.$executeRaw(
    Prisma.sql`
      UPDATE profiles
      SET location_point = ST_SetSRID(ST_MakePoint(${longitude}, ${latitude}), 4326)::geography
      WHERE user_id = CAST(${userId} AS uuid)
    `,
  );
}

// Data required to create a new profile (full onboarding payload)
export interface CreateProfileData {
  userId: string;

  // Basic info
  firstName?: string | null;
  lastName?: string | null;
  nickname?: string | null;
  displayName?: string | null;
  birthDate: Date;
  gender: string;
  // ethnicity is a JSON array of strings (multi-select)
  ethnicity?: string[] | null;

  // Career & education — collected during onboarding
  education?: string | null;
  careerField?: string | null;
  languages?: string[] | null;

  // Height (optional — conditional on height_unit)
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

  // Lifestyle habits (all optional)
  drinks?: string | null;
  smoking?: string | null;
  pets?: string | null;
  children?: string | null;
  workout?: string | null;
  sleepSchedule?: string | null;

  // Bio (optional)
  bio?: string | null;

  // Prompts (optional, 0–4 items, shape: { question, answer })
  prompts?: Array<{ question: string; answer: string }> | null;
}

// Data allowed for partial profile updates — all fields optional
export interface UpdateProfileData {
  // Identity
  firstName?: string | null;
  lastName?: string | null;
  nickname?: string | null;
  displayName?: string | null;
  birthDate?: Date;
  gender?: string;
  pronouns?: string | null;
  orientation?: string | null;
  genderIdentity?: string | null;
  showSex?: boolean;
  showOrientation?: boolean;
  showIdentity?: boolean;
  showPersonalityTrait?: boolean;

  // Background
  ethnicity?: string[] | null;
  birthCountry?: string | null;
  languages?: string[] | null;

  // Career & education
  education?: string | null;
  careerField?: string | null;
  jobTitle?: string | null;
  school?: string | null;

  // Height
  heightUnit?: string | null;
  heightFt?: number | null;
  heightIn?: number | null;
  heightCm?: number | null;

  // Location
  latitude?: number;
  longitude?: number;
  locationCity?: string;
  locationState?: string;
  locationZip?: string;

  // Bio & social
  bio?: string | null;
  instagramHandle?: string | null;
  tiktokHandle?: string | null;
  spotifyPlaylistUrl?: string | null;

  // Lifestyle habits
  drinks?: string | null;
  smoking?: string | null;
  workout?: string | null;
  sleepSchedule?: string | null;
  pets?: string | null;
  cannabis?: string | null;
  petTypes?: string | null;
  petsName?: string | null;
  children?: string | null;

  // Flexibility flags
  isDrinksFlexible?: boolean;
  isSmokingFlexible?: boolean;
  isWorkoutFlexible?: boolean;
  isSleepFlexible?: boolean;
  isCannabisFlexible?: boolean;
  isKidsFlexible?: boolean;

  // Personality
  loveLanguage?: string | null;
  zodiacSign?: string | null;
  communicationStyle?: string | null;
  conflictStyle?: string | null;

  // Interests & date activities
  interests?: string[] | null;
  preferredDateActivities?: string[] | null;
  wouldNotDoActivities?: string[] | null;

  // Dating preferences
  meetPreference?: string | null;
  relationshipGoals?: string[];
  minAgePreference?: number | null;
  maxAgePreference?: number | null;
  distancePreferenceMiles?: number | null;

  // Prompts (0–4 items)
  prompts?: Array<{ question: string; answer: string }> | null;
}

export class ProfileRepository {
  async findByUserId(userId: string): Promise<profiles | null> {
    return prisma.profiles.findUnique({ where: { user_id: userId } });
  }

  async create(data: CreateProfileData): Promise<profiles> {
    return prisma.$transaction(async (tx) => {
      const profile = await tx.profiles.create({
        data: {
          user_id:                   data.userId,
          first_name:                data.firstName,
          last_name:                 data.lastName,
          nickname:                  data.nickname ?? null,
          display_name:              data.displayName ?? null,
          birth_date:                data.birthDate,
          gender:                    data.gender,
          ethnicity:                 data.ethnicity ?? Prisma.JsonNull,

          // Career & education — saved at onboarding if iOS sends them
          education:                 data.education ?? null,
          career_field:              data.careerField ?? null,
          languages:                 data.languages ?? Prisma.JsonNull,

          // Height
          height_unit:               data.heightUnit,
          height_ft:                 data.heightFt ?? null,
          height_in:                 data.heightIn ?? null,
          height_cm:                 data.heightCm ?? null,

          // Location
          latitude:                  data.latitude,
          longitude:                 data.longitude,
          location_city:             data.locationCity,
          state:                     data.locationState,   // DB column name is state
          zip_code:                  data.locationZip,     // DB column name is zip_code

          // Dating preferences
          meet_preference:           data.meetPreference,
          relationship_goals:        data.relationshipGoals,
          min_age_preference:        data.minAgePreference,
          max_age_preference:        data.maxAgePreference,
          distance_preference_miles: data.distancePreferenceMiles,

          // Lifestyle habits — stored as plain strings matching iOS values
          lifestyle_drinks:          data.drinks ?? null,
          lifestyle_smoking:         data.smoking ?? null,
          lifestyle_pets:            data.pets ?? null,
          lifestyle_children:        data.children ?? null,
          lifestyle_workout:         data.workout ?? null,
          lifestyle_sleep:           data.sleepSchedule ?? null,

          // Bio and prompts
          bio:                       data.bio ?? null,
          prompts:                   data.prompts ?? Prisma.JsonNull,
        },
      });

      await tx.users.update({
        where: { id: data.userId },
        data: buildUserSearchUpdate({
          meetPreference: data.meetPreference,
          minAgePreference: data.minAgePreference,
          maxAgePreference: data.maxAgePreference,
          distancePreferenceMiles: data.distancePreferenceMiles,
        }),
      });

      await updateLocationPoint(tx, data.userId, data.latitude, data.longitude);

      return profile;
    });
  }

  async updateLocation(
    userId: string,
    data: {
      latitude: number;
      longitude: number;
      locationCity: string;
      locationState: string;
      locationZip: string;
    },
  ): Promise<void> {
    await prisma.$transaction(async (tx) => {
      await tx.profiles.update({
        where: { user_id: userId },
        data: {
          latitude:      data.latitude,
          longitude:     data.longitude,
          location_city: data.locationCity,
          state:         data.locationState,
          zip_code:      data.locationZip,
        },
      });

      await updateLocationPoint(tx, userId, data.latitude, data.longitude);
    });
  }

  // Partial update — only fields present in data are updated
  async update(userId: string, data: UpdateProfileData): Promise<profiles> {
    // Build the update payload dynamically — only include keys that were passed
    const p: Record<string, unknown> = {};

    // Identity
    if (data.firstName        !== undefined) p.first_name          = data.firstName;
    if (data.lastName         !== undefined) p.last_name           = data.lastName;
    if (data.nickname         !== undefined) p.nickname            = data.nickname;
    if (data.displayName      !== undefined) p.display_name        = data.displayName;
    if (data.birthDate        !== undefined) p.birth_date          = data.birthDate;
    if (data.gender           !== undefined) p.gender              = data.gender;
    if (data.pronouns         !== undefined) p.pronouns            = data.pronouns;
    if (data.orientation      !== undefined) p.orientation         = data.orientation;
    if (data.genderIdentity   !== undefined) p.gender_identity     = data.genderIdentity;
    if (data.showSex          !== undefined) p.show_sex            = data.showSex;
    if (data.showOrientation  !== undefined) p.show_orientation    = data.showOrientation;
    if (data.showIdentity     !== undefined) p.show_identity       = data.showIdentity;
    if (data.showPersonalityTrait !== undefined) p.show_personality_trait = data.showPersonalityTrait;

    // Background
    if (data.ethnicity        !== undefined) p.ethnicity           = data.ethnicity;
    if (data.birthCountry     !== undefined) p.birth_country       = data.birthCountry;
    if (data.languages        !== undefined) p.languages           = data.languages;

    // Career & education
    if (data.education        !== undefined) p.education           = data.education;
    if (data.careerField      !== undefined) p.career_field        = data.careerField;
    if (data.jobTitle         !== undefined) p.job_title           = data.jobTitle;
    if (data.school           !== undefined) p.school              = data.school;

    // Height
    if (data.heightUnit       !== undefined) p.height_unit         = data.heightUnit;
    if (data.heightFt         !== undefined) p.height_ft           = data.heightFt;
    if (data.heightIn         !== undefined) p.height_in           = data.heightIn;
    if (data.heightCm         !== undefined) p.height_cm           = data.heightCm;

    // Location
    if (data.latitude         !== undefined) p.latitude            = data.latitude;
    if (data.longitude        !== undefined) p.longitude           = data.longitude;
    if (data.locationCity     !== undefined) p.location_city       = data.locationCity;
    if (data.locationState    !== undefined) p.state               = data.locationState;   // DB: state
    if (data.locationZip      !== undefined) p.zip_code            = data.locationZip;     // DB: zip_code

    // Bio & social
    if (data.bio                  !== undefined) p.bio                  = data.bio;
    if (data.instagramHandle      !== undefined) p.instagram_handle     = data.instagramHandle;
    if (data.tiktokHandle         !== undefined) p.tiktok_handle        = data.tiktokHandle;
    if (data.spotifyPlaylistUrl   !== undefined) p.spotify_playlist_url = data.spotifyPlaylistUrl;

    // Lifestyle habits
    if (data.drinks           !== undefined) p.lifestyle_drinks     = data.drinks;
    if (data.smoking          !== undefined) p.lifestyle_smoking    = data.smoking;
    if (data.workout          !== undefined) p.lifestyle_workout    = data.workout;
    if (data.sleepSchedule    !== undefined) p.lifestyle_sleep      = data.sleepSchedule;
    if (data.pets             !== undefined) p.lifestyle_pets       = data.pets;
    if (data.cannabis         !== undefined) p.lifestyle_cannabis   = data.cannabis;
    if (data.petTypes         !== undefined) p.pet_types            = data.petTypes;
    if (data.petsName         !== undefined) p.pets_name            = data.petsName;
    if (data.children         !== undefined) p.lifestyle_children   = data.children;

    // Flexibility flags
    if (data.isDrinksFlexible   !== undefined) p.is_drinks_flexible   = data.isDrinksFlexible;
    if (data.isSmokingFlexible  !== undefined) p.is_smoking_flexible  = data.isSmokingFlexible;
    if (data.isWorkoutFlexible  !== undefined) p.is_workout_flexible  = data.isWorkoutFlexible;
    if (data.isSleepFlexible    !== undefined) p.is_sleep_flexible    = data.isSleepFlexible;
    if (data.isCannabisFlexible !== undefined) p.is_cannabis_flexible = data.isCannabisFlexible;
    if (data.isKidsFlexible     !== undefined) p.is_kids_flexible     = data.isKidsFlexible;

    // Personality
    if (data.loveLanguage        !== undefined) p.love_language        = data.loveLanguage;
    if (data.zodiacSign          !== undefined) p.zodiac_sign          = data.zodiacSign;
    if (data.communicationStyle  !== undefined) p.communication_style  = data.communicationStyle;
    if (data.conflictStyle       !== undefined) p.conflict_style       = data.conflictStyle;

    // Interests & date activities
    if (data.interests               !== undefined) p.interests                 = data.interests;
    if (data.preferredDateActivities !== undefined) p.preferred_date_activities = data.preferredDateActivities;
    if (data.wouldNotDoActivities    !== undefined) p.would_not_do_activities   = data.wouldNotDoActivities;

    // Dating preferences
    if (data.meetPreference          !== undefined) p.meet_preference            = data.meetPreference;
    if (data.relationshipGoals       !== undefined) p.relationship_goals         = data.relationshipGoals;
    if (data.minAgePreference        !== undefined) p.min_age_preference         = data.minAgePreference;
    if (data.maxAgePreference        !== undefined) p.max_age_preference         = data.maxAgePreference;
    if (data.distancePreferenceMiles !== undefined) p.distance_preference_miles  = data.distancePreferenceMiles;

    // Prompts
    if (data.prompts !== undefined) p.prompts = data.prompts;

    return prisma.$transaction(async (tx) => {
      const existingProfile = await tx.profiles.findUnique({
        where: { user_id: userId },
        select: {
          latitude: true,
          longitude: true,
        },
      });

      const updatedProfile = await tx.profiles.update({
        where: { user_id: userId },
        data: p as any,
      });

      const userSearchUpdate = buildUserSearchUpdate({
        meetPreference: data.meetPreference,
        minAgePreference: data.minAgePreference,
        maxAgePreference: data.maxAgePreference,
        distancePreferenceMiles: data.distancePreferenceMiles,
      });

      if (Object.keys(userSearchUpdate).length > 0) {
        await tx.users.update({
          where: { id: userId },
          data: userSearchUpdate,
        });
      }

      if (data.latitude !== undefined || data.longitude !== undefined) {
        const latitude = data.latitude ?? existingProfile?.latitude ?? null;
        const longitude = data.longitude ?? existingProfile?.longitude ?? null;
        await updateLocationPoint(tx, userId, latitude, longitude);
      }

      return updatedProfile;
    });
  }
}
