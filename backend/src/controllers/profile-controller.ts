import { Request, Response } from 'express';
import { profiles } from '@prisma/client';
import { ProfileService } from '../services/profile-service';
import { UserRepository } from '../repositories/user-repository';
import { unauthorized } from '../utils/errors';
import { generateReadURL } from '../services/storage.service';

// ─── Allowed values ────────────────────────────────────────────────────────────
// All values match the exact rawValue strings iOS sends — do not change casing.

// gender: biological sex collected during onboarding
const VALID_GENDERS = ['Male', 'Female', 'Non-binary', 'Prefer not to say'];

// orientation: sexual orientation — PATCH only
const VALID_ORIENTATIONS = [
  'Straight', 'Gay', 'Lesbian', 'Bisexual', 'Demisexual',
  'Pansexual', 'Queer', 'Questioning', 'Prefer not to say',
];

// gender_identity: separate from biological sex — PATCH only
const VALID_GENDER_IDENTITIES = [
  'Man', 'Woman', 'Non-binary', 'Gender fluid', 'Gender queer',
  'Agender', 'Bigender', 'Two-spirit', 'Transgender', 'Prefer not to say',
];

// Ethnicity values accepted from iOS (sent as JSON array, multiple allowed)
const VALID_ETHNICITIES = [
  'White', 'Asian', 'Other+', 'Hispanic/Latino',
  'Black/African American', 'Native Hawaiian', 'Pacific Islander',
];

const VALID_HEIGHT_UNITS = ['imperial', 'metric'];

// meet_preference — exact iOS values (capitalized, "Open to both" not "both")
const VALID_MEET_PREFERENCES = ['Men', 'Women', 'Open to both'];

// relationship_goals — exact iOS values (title case, "Still figuring out")
const VALID_RELATIONSHIP_GOALS = ['Short Term', 'Long Term', 'Marriage', 'Still figuring out'];

// drinks / smoking / workout / cannabis — exact iOS values (capitalized)
const VALID_FREQUENCY = ['Never', 'Sometimes', 'Often'];

// pets / children — exact iOS values (capitalized, "Don't want" with apostrophe)
const VALID_PREFERENCE_LEVEL = ["Don't want", 'Unsure', 'Want', 'Have'];

// sleep_schedule — exact iOS values (title case, spaced)
const VALID_SLEEP_SCHEDULES = ['Night Owl', 'Early Bird', 'Flexible'];

// education — snake_case rawValues from iOS EducationLevel enum
const VALID_EDUCATION = ['high_school', 'in_college', 'bachelors', 'masters', 'phd', 'other'];

// career_field — exact iOS values
const VALID_CAREER_FIELDS = ['Technology', 'Healthcare', 'Education', 'Finance', 'Arts', 'Other'];

// love_language — PATCH only
const VALID_LOVE_LANGUAGES = [
  'Words of Affirmation', 'Acts of Service', 'Receiving Gifts', 'Quality Time', 'Physical Touch',
];

// zodiac_sign — PATCH only
const VALID_ZODIAC_SIGNS = [
  'Aries', 'Taurus', 'Gemini', 'Cancer', 'Leo', 'Virgo',
  'Libra', 'Scorpio', 'Sagittarius', 'Capricorn', 'Aquarius', 'Pisces',
];

// communication_style / conflict_style — "" (empty string) is valid (means neutral/no preference)
const VALID_COMMUNICATION_STYLES = ['Big Texter', 'Phone Person', ''];
const VALID_CONFLICT_STYLES      = ['Quiet & Reserved', 'Confrontational', ''];

// birth_country — single-select list from iOS
const VALID_BIRTH_COUNTRIES = [
  'United States', 'Canada', 'United Kingdom', 'Australia', 'India', 'Mexico', 'Brazil',
  'Germany', 'France', 'Japan', 'South Korea', 'China', 'Nigeria', 'Philippines', 'Vietnam',
  'Spain', 'Italy', 'Pakistan', 'Bangladesh', 'Ethiopia', 'Egypt', 'Other',
];

// interests — valid values from iOS picker (max 7)
const VALID_INTERESTS = [
  'Travel', 'Photography', 'Music', 'Reading', 'Fitness', 'Dance', 'Cooking', 'Gaming',
  'Art', 'Sports', 'Movies', 'Yoga', 'Hiking', 'Fashion', 'Technology', 'Foodie', 'Outdoors',
  'KPop', 'Shopping', 'Concerts', 'Skiing', 'Running', 'Tattoos', 'Climbing', 'Swimming',
  'Festivals', 'Startups', 'Collecting', 'Road Trips', 'Boba Tea', 'Coffee', 'Dogs', 'Cats',
  'Activism', 'Football', 'Basketball', 'Soccer', 'Crossfit', 'Aquarium', 'Nature', 'Cars',
  'Sneakers', '90s Kid', 'Country Music', 'LGBTQ+ Rights', 'Climate Change',
];

// date activity values — shared by preferred_date_activities and would_not_do_activities (max 3 each)
const VALID_DATE_ACTIVITIES = [
  'Dinner & a movie', 'Coffee at a local cafe', 'Exploring the city', 'Night out at the club',
  'Live music at a bar', 'Lunch & a museum', 'Something active & adventurous', 'Concert',
  'Hiking', 'Cooking together', 'Picnic', 'Art gallery', 'Sports game', 'Comedy show', 'Rooftop bar',
];

// ─── Validation helpers ────────────────────────────────────────────────────────
// Collect all field errors at once instead of throwing on first failure.

type ErrorMap = Record<string, string>;

function requireString(
  errors: ErrorMap,
  value: unknown,
  field: string,
  message: string,
): string | null {
  if (typeof value !== 'string' || value.trim().length === 0) {
    errors[field] = message;
    return null;
  }
  return value.trim();
}

function requireEnum(
  errors: ErrorMap,
  value: unknown,
  field: string,
  allowed: string[],
  message: string,
): string | null {
  const str = requireString(errors, value, field, message);
  if (str && !allowed.includes(str)) {
    errors[field] = message;
    return null;
  }
  return str;
}

function requireInt(
  errors: ErrorMap,
  value: unknown,
  field: string,
  min: number,
  max: number,
  message: string,
): number | null {
  if (typeof value !== 'number' || !Number.isInteger(value) || value < min || value > max) {
    errors[field] = message;
    return null;
  }
  return value;
}

function requireFloat(
  errors: ErrorMap,
  value: unknown,
  field: string,
  message: string,
): number | null {
  if (typeof value !== 'number' || isNaN(value)) {
    errors[field] = message;
    return null;
  }
  return value;
}

// Optional string — skip if null/undefined, validate if present
function optionalString(
  errors: ErrorMap,
  value: unknown,
  field: string,
  message: string,
): string | null {
  if (value === undefined || value === null) return null;
  return requireString(errors, value, field, message);
}

// Optional enum — skip if null/undefined, validate if present
function optionalEnum(
  errors: ErrorMap,
  value: unknown,
  field: string,
  allowed: string[],
  message: string,
): string | null {
  if (value === undefined || value === null) return null;
  return requireEnum(errors, value, field, allowed, message);
}

// Optional int — skip if null/undefined, validate range if present
function optionalInt(
  errors: ErrorMap,
  value: unknown,
  field: string,
  min: number,
  max: number,
  message: string,
): number | null {
  if (value === undefined || value === null) return null;
  return requireInt(errors, value, field, min, max, message);
}

// Validates birth_date string and enforces 18+ age rule
function validateBirthDate(errors: ErrorMap, value: unknown): Date | null {
  if (typeof value !== 'string' || value.trim().length === 0) {
    errors['birth_date'] = 'birth_date is required';
    return null;
  }

  const date = new Date(value.trim());
  if (isNaN(date.getTime())) {
    errors['birth_date'] = 'birth_date must be a valid date (YYYY-MM-DD)';
    return null;
  }

  const today = new Date();
  let age = today.getFullYear() - date.getFullYear();
  const monthDiff = today.getMonth() - date.getMonth();
  if (monthDiff < 0 || (monthDiff === 0 && today.getDate() < date.getDate())) {
    age--;
  }
  if (age < 18) {
    errors['birth_date'] = 'User must be at least 18 years old';
    return null;
  }

  return date;
}

// Validates height fields — only required when height_unit is provided
function validateHeight(
  errors: ErrorMap,
  heightUnit: string | null,
  body: Record<string, unknown>,
): { heightFt: number | null; heightIn: number | null; heightCm: number | null } {
  let heightFt: number | null = null;
  let heightIn: number | null = null;
  let heightCm: number | null = null;

  if (heightUnit === 'imperial') {
    heightFt = requireInt(errors, body.height_ft, 'height_ft', 3, 8, 'height_ft must be between 3 and 8');
    heightIn = requireInt(errors, body.height_in, 'height_in', 0, 11, 'height_in must be between 0 and 11');
  } else if (heightUnit === 'metric') {
    heightCm = requireInt(errors, body.height_cm, 'height_cm', 91, 272, 'height_cm must be between 91 and 272');
  }

  return { heightFt, heightIn, heightCm };
}

// Validates ethnicity as a JSON array of allowed values (optional, multi-select)
function validateEthnicity(errors: ErrorMap, value: unknown): string[] | null {
  if (value === undefined || value === null) return null;

  if (!Array.isArray(value) || value.length === 0) {
    errors['ethnicity'] = 'ethnicity must be a non-empty array';
    return null;
  }
  for (const item of value) {
    if (!VALID_ETHNICITIES.includes(item)) {
      errors['ethnicity'] = `Each ethnicity must be one of: ${VALID_ETHNICITIES.join(', ')}`;
      return null;
    }
  }
  return value as string[];
}

// Validates relationship_goals array (1–2 items, each from allowed list)
function validateRelationshipGoals(errors: ErrorMap, value: unknown): string[] | null {
  if (!Array.isArray(value) || value.length === 0) {
    errors['relationship_goals'] = 'relationship_goals must have at least 1 item';
    return null;
  }
  if (value.length > 2) {
    errors['relationship_goals'] = 'Maximum 2 goals allowed';
    return null;
  }
  for (const item of value) {
    if (!VALID_RELATIONSHIP_GOALS.includes(item)) {
      errors['relationship_goals'] = `Each goal must be one of: ${VALID_RELATIONSHIP_GOALS.join(', ')}`;
      return null;
    }
  }
  return value as string[];
}

// Validates prompts array (0–4 items, shape: { question, answer })
// is_custom field removed — iOS no longer sends it
function validatePrompts(
  errors: ErrorMap,
  value: unknown,
): Array<{ question: string; answer: string }> | null {
  if (value === undefined || value === null) return null;

  if (!Array.isArray(value)) {
    errors['prompts'] = 'prompts must be an array';
    return null;
  }
  if (value.length > 4) {
    errors['prompts'] = 'Maximum 4 prompts allowed';
    return null;
  }
  for (const item of value) {
    if (typeof item.question !== 'string' || typeof item.answer !== 'string') {
      errors['prompts'] = 'Each prompt must have question (string) and answer (string)';
      return null;
    }
  }
  return value as Array<{ question: string; answer: string }>;
}

// Validates a string array against an allowed list, with an optional max length cap
function validateStringArray(
  errors: ErrorMap,
  value: unknown,
  field: string,
  allowed: string[],
  max: number,
): string[] | null {
  if (value === undefined || value === null) return null;

  if (!Array.isArray(value)) {
    errors[field] = `${field} must be an array`;
    return null;
  }
  if (value.length > max) {
    errors[field] = `Maximum ${max} items allowed for ${field}`;
    return null;
  }
  for (const item of value) {
    if (!allowed.includes(item)) {
      errors[field] = `Invalid value "${item}" for ${field}`;
      return null;
    }
  }
  return value as string[];
}

// Validates a languages array — values must be from the allowed list
function validateLanguages(errors: ErrorMap, value: unknown): string[] | null {
  const VALID_LANGUAGES = [
    'English', 'Spanish', 'Mandarin/Chinese', 'Hindi', 'Arabic', 'French', 'Portuguese',
    'Russian', 'Japanese', 'Korean', 'German', 'Vietnamese', 'Italian', 'Other+',
  ];
  if (value === undefined || value === null) return null;
  if (!Array.isArray(value) || value.length === 0) {
    errors['languages'] = 'languages must be a non-empty array';
    return null;
  }
  for (const item of value) {
    if (!VALID_LANGUAGES.includes(item)) {
      errors['languages'] = `Invalid language value "${item}"`;
      return null;
    }
  }
  return value as string[];
}

// ─── Serializer ────────────────────────────────────────────────────────────────
// Converts a DB profiles row to the API response shape.
// DB column names mapped to API field names where they differ (state → location_state etc.)

function serializeProfile(profile: profiles): Record<string, unknown> {
  return {
    // ── Identity ──────────────────────────────────────────────────────────────
    user_id:                      profile.user_id,
    first_name:                   profile.first_name ?? null,
    last_name:                    profile.last_name ?? null,
    birth_date:                   profile.birth_date ?? null,
    gender:                       profile.gender ?? null,
    pronouns:                     profile.pronouns ?? null,
    orientation:                  profile.orientation ?? null,
    gender_identity:              profile.gender_identity ?? null,
    show_sex:                     profile.show_sex ?? true,
    show_orientation:             profile.show_orientation ?? true,
    show_identity:                profile.show_identity ?? true,

    // ── Background ────────────────────────────────────────────────────────────
    ethnicity:                    profile.ethnicity ?? null,
    birth_country:                profile.birth_country ?? null,
    languages:                    profile.languages ?? null,

    // ── Career & Education ────────────────────────────────────────────────────
    education:                    profile.education ?? null,
    career_field:                 profile.career_field ?? null,
    job_title:                    profile.job_title ?? null,
    school:                       profile.school ?? null,

    // ── Height ────────────────────────────────────────────────────────────────
    height_unit:                  profile.height_unit ?? null,
    height_ft:                    profile.height_ft ?? null,
    height_in:                    profile.height_in ?? null,
    height_cm:                    profile.height_cm ?? null,

    // ── Location ──────────────────────────────────────────────────────────────
    latitude:                     profile.latitude ?? null,
    longitude:                    profile.longitude ?? null,
    location_city:                profile.location_city ?? null,
    location_state:               profile.state ?? null,       // DB: state → API: location_state
    location_zip:                 profile.zip_code ?? null,    // DB: zip_code → API: location_zip

    // ── Bio & Social ──────────────────────────────────────────────────────────
    bio:                          profile.bio ?? null,
    instagram_handle:             profile.instagram_handle ?? null,
    tiktok_handle:                profile.tiktok_handle ?? null,
    spotify_playlist_url:         profile.spotify_playlist_url ?? null,

    // ── Lifestyle Habits ──────────────────────────────────────────────────────
    drinks:                       profile.lifestyle_drinks ?? null,
    smoking:                      profile.lifestyle_smoking ?? null,
    workout:                      profile.lifestyle_workout ?? null,
    sleep_schedule:               profile.lifestyle_sleep ?? null,
    pets:                         profile.lifestyle_pets ?? null,
    cannabis:                     profile.lifestyle_cannabis ?? null,
    pet_types:                    profile.pet_types ?? null,
    pets_name:                    profile.pets_name ?? null,
    children:                     profile.lifestyle_children ?? null,

    // ── Lifestyle Flexibility Flags ───────────────────────────────────────────
    is_drinks_flexible:           profile.is_drinks_flexible ?? false,
    is_smoking_flexible:          profile.is_smoking_flexible ?? false,
    is_workout_flexible:          profile.is_workout_flexible ?? false,
    is_sleep_flexible:            profile.is_sleep_flexible ?? false,
    is_cannabis_flexible:         profile.is_cannabis_flexible ?? false,
    is_kids_flexible:             profile.is_kids_flexible ?? false,

    // ── Personality ───────────────────────────────────────────────────────────
    love_language:                profile.love_language ?? null,
    zodiac_sign:                  profile.zodiac_sign ?? null,
    communication_style:          profile.communication_style ?? null,
    conflict_style:               profile.conflict_style ?? null,
    // personality_type is set by the Personality Test flow — returned here but not writable via PATCH
    personality_type:             profile.personality_type ?? null,

    // ── Interests & Date Activities ───────────────────────────────────────────
    interests:                    profile.interests ?? null,
    preferred_date_activities:    profile.preferred_date_activities ?? null,
    would_not_do_activities:      profile.would_not_do_activities ?? null,

    // ── Dating Preferences ────────────────────────────────────────────────────
    meet_preference:              profile.meet_preference ?? null,
    relationship_goals:           profile.relationship_goals ?? null,
    min_age_preference:           profile.min_age_preference ?? null,
    max_age_preference:           profile.max_age_preference ?? null,
    distance_preference_miles:    profile.distance_preference_miles ?? null,

    // ── Prompts ───────────────────────────────────────────────────────────────
    prompts:                      profile.prompts ?? null,

  };
}

// ─── Controller ────────────────────────────────────────────────────────────────

export class ProfileController {
  constructor(
    private readonly profileService: ProfileService,
    private readonly userRepository: UserRepository,
  ) {}

  // Resolves the authenticated user's DB record from their Firebase UID
  private async resolveUser(req: Request) {
    const firebaseUid = req.auth?.uid;
    if (!firebaseUid) {
      unauthorized('User identity not found in request', 'MISSING_USER_IDENTITY');
    }
    const user = await this.userRepository.findByFirebaseUid(firebaseUid);
    if (!user) {
      unauthorized('User not found in database', 'USER_NOT_FOUND');
    }
    return user;
  }

  // POST /api/v1/users/profile
  // Creates the user's profile after completing the onboarding survey.
  // Required: birth_date, gender, meet_preference, relationship_goals, age range, distance, location, lat/lng
  // Optional: first_name, last_name, ethnicity, height, education, habits, bio, prompts
  // Returns 201 { user_id } on success, 422 with field errors on validation failure.
  createProfile = async (req: Request, res: Response): Promise<void> => {
    const user = await this.resolveUser(req);
    const body = req.body ?? {};
    const errors: ErrorMap = {};

    // ── Step 1: Basic Info ──────────────────────────────────────────────────
    const firstName  = optionalString(errors, body.first_name,  'first_name',  'first_name must be a non-empty string');
    const lastName   = optionalString(errors, body.last_name,   'last_name',   'last_name must be a non-empty string');
    const birthDate  = validateBirthDate(errors, body.birth_date);
    const gender     = requireEnum(errors, body.gender, 'gender', VALID_GENDERS,
                         `gender must be one of: ${VALID_GENDERS.join(', ')}`);
    const ethnicity  = validateEthnicity(errors, body.ethnicity);

    // height_unit is optional — if provided, conditional fields are required
    const heightUnit = optionalEnum(errors, body.height_unit, 'height_unit', VALID_HEIGHT_UNITS,
                         'height_unit must be "imperial" or "metric"');
    const { heightFt, heightIn, heightCm } = validateHeight(errors, heightUnit, body);

    const locationCity  = requireString(errors, body.location_city,  'location_city',  'location_city is required');
    const locationState = requireString(errors, body.location_state, 'location_state', 'location_state is required');
    const locationZip   = requireString(errors, body.location_zip,   'location_zip',   'location_zip is required');
    const latitude      = requireFloat(errors, body.latitude,   'latitude',   'latitude is required and must be a number');
    const longitude     = requireFloat(errors, body.longitude,  'longitude',  'longitude is required and must be a number');

    // education — optional snake_case value matching iOS EducationLevel rawValue
    const education = optionalEnum(errors, body.education, 'education', VALID_EDUCATION,
                        `education must be one of: ${VALID_EDUCATION.join(', ')}`);

    // career_field — optional, collected in onboarding Step 4 alongside education
    const careerField = optionalEnum(errors, body.career_field, 'career_field', VALID_CAREER_FIELDS,
                          `career_field must be one of: ${VALID_CAREER_FIELDS.join(', ')}`);

    // languages — optional JSON array, collected in onboarding Step 4
    const languages = validateLanguages(errors, body.languages);

    // ── Step 2: Preferences ─────────────────────────────────────────────────
    const meetPreference        = requireEnum(errors, body.meet_preference, 'meet_preference', VALID_MEET_PREFERENCES,
                                    `meet_preference must be one of: ${VALID_MEET_PREFERENCES.join(', ')}`);
    const relationshipGoals     = validateRelationshipGoals(errors, body.relationship_goals);
    const minAgePreference      = requireInt(errors, body.min_age_preference, 'min_age_preference', 18, 80,
                                    'min_age_preference must be between 18 and 80');
    const maxAgePreference      = requireInt(errors, body.max_age_preference, 'max_age_preference', 18, 80,
                                    'max_age_preference must be between 18 and 80');
    const distancePreferenceMiles = requireInt(errors, body.distance_preference_miles, 'distance_preference_miles', 1, 100,
                                      'distance_preference_miles must be between 1 and 100');

    // max must be >= min
    if (minAgePreference !== null && maxAgePreference !== null && maxAgePreference < minAgePreference) {
      errors['max_age_preference'] = 'max_age_preference must be greater than or equal to min_age_preference';
    }

    // ── Step 3: Lifestyle Habits (all optional) ─────────────────────────────
    const drinks        = optionalEnum(errors, body.drinks,         'drinks',         VALID_FREQUENCY,        `drinks must be one of: ${VALID_FREQUENCY.join(', ')}`);
    const smoking       = optionalEnum(errors, body.smoking,        'smoking',        VALID_FREQUENCY,        `smoking must be one of: ${VALID_FREQUENCY.join(', ')}`);
    const pets          = optionalEnum(errors, body.pets,           'pets',           VALID_PREFERENCE_LEVEL, `pets must be one of: ${VALID_PREFERENCE_LEVEL.join(', ')}`);
    const children      = optionalEnum(errors, body.children,       'children',       VALID_PREFERENCE_LEVEL, `children must be one of: ${VALID_PREFERENCE_LEVEL.join(', ')}`);
    const workout       = optionalEnum(errors, body.workout,        'workout',        VALID_FREQUENCY,        `workout must be one of: ${VALID_FREQUENCY.join(', ')}`);
    const sleepSchedule = optionalEnum(errors, body.sleep_schedule, 'sleep_schedule', VALID_SLEEP_SCHEDULES,  `sleep_schedule must be one of: ${VALID_SLEEP_SCHEDULES.join(', ')}`);

    // ── Step 4: Bio (optional) ──────────────────────────────────────────────
    let bio: string | null = null;
    if (body.bio !== undefined && body.bio !== null) {
      if (typeof body.bio !== 'string') {
        errors['bio'] = 'bio must be a string';
      } else if (body.bio.length > 500) {
        errors['bio'] = 'bio must be 500 characters or fewer';
      } else {
        bio = body.bio;
      }
    }

    // ── Step 5: Prompts (optional) ──────────────────────────────────────────
    const prompts = validatePrompts(errors, body.prompts);

    // Return all field errors at once (422 Unprocessable Entity)
    if (Object.keys(errors).length > 0) {
      res.status(422).json({ errors });
      return;
    }

    const profile = await this.profileService.createProfile({
      userId:                  user!.id,
      firstName,
      lastName,
      birthDate:               birthDate!,
      gender:                  gender!,
      ethnicity,
      education,
      careerField,
      languages,
      heightUnit,
      heightFt,
      heightIn,
      heightCm,
      latitude:                latitude!,
      longitude:               longitude!,
      locationCity:            locationCity!,
      locationState:           locationState!,
      locationZip:             locationZip!,
      meetPreference:          meetPreference!,
      relationshipGoals:       relationshipGoals!,
      minAgePreference:        minAgePreference!,
      maxAgePreference:        maxAgePreference!,
      distancePreferenceMiles: distancePreferenceMiles!,
      drinks,
      smoking,
      pets,
      children,
      workout,
      sleepSchedule,
      bio,
      prompts,
    });

    // Mark onboarding as complete so iOS knows to skip onboarding on next login
    await this.userRepository.setOnboardingComplete(user!.id);

    res.status(201).json({ user_id: profile.user_id });
  };

  // GET /api/v1/users/profile
  // Returns the authenticated user's full profile.
  // 401 PROFILE_NOT_FOUND if the user hasn't completed onboarding yet.
  getProfile = async (req: Request, res: Response): Promise<void> => {
    const user = await this.resolveUser(req);

    const profile = await this.profileService.getProfile(user!.id);
    if (!profile) {
      unauthorized('Profile not found', 'PROFILE_NOT_FOUND');
    }

    const serialized = serializeProfile(profile!);

    const rawPhotos = Array.isArray(profile!.photos) ? (profile!.photos as any[]) : [];
    const sortedPhotos = [...rawPhotos].sort((a, b) => (a.order ?? 0) - (b.order ?? 0));
    const photos = await Promise.all(
      sortedPhotos.map(async (p: any) => ({
        id: p.id,
        url: await generateReadURL(p.storagePath),
      }))
    );

    res.status(200).json({
      ...serialized,
      photos,
      personality_type:              profile!.personality_type ?? null,
      personality_primary:           profile!.personality_primary ?? null,
      personality_secondary:         profile!.personality_secondary ?? null,
      is_personality_test_complete:  user!.is_personality_test_complete ?? false,
    });
  };

  // PATCH /api/v1/users/profile
  // Partial profile update — only fields that are sent get updated.
  // All fields are optional. Same validation rules as POST apply to any field that is present.
  // Returns 200 with the full updated profile on success.
  // Returns 401 PROFILE_NOT_FOUND if the user hasn't completed onboarding yet.
  // Returns 422 with field errors if any provided value fails validation.
  updateProfile = async (req: Request, res: Response): Promise<void> => {
    const user = await this.resolveUser(req);
    const existingProfile = await this.profileService.getProfile(user!.id);
    if (!existingProfile) {
      unauthorized('Profile not found', 'PROFILE_NOT_FOUND');
    }

    const body = req.body ?? {};
    const errors: ErrorMap = {};

    // Build update data — only validate and include fields that are actually present in the request
    const updateData: Record<string, unknown> = {};

    // ── Identity ────────────────────────────────────────────────────────────
    if (body.first_name !== undefined) {
      updateData.firstName = optionalString(errors, body.first_name, 'first_name', 'first_name must be a non-empty string');
    }
    if (body.last_name !== undefined) {
      updateData.lastName = optionalString(errors, body.last_name, 'last_name', 'last_name must be a non-empty string');
    }
    if (body.birth_date !== undefined) {
      updateData.birthDate = validateBirthDate(errors, body.birth_date);
    }
    if (body.gender !== undefined) {
      updateData.gender = requireEnum(errors, body.gender, 'gender', VALID_GENDERS,
        `gender must be one of: ${VALID_GENDERS.join(', ')}`);
    }
    if (body.pronouns !== undefined) {
      updateData.pronouns = optionalString(errors, body.pronouns, 'pronouns', 'pronouns must be a non-empty string');
    }
    if (body.orientation !== undefined) {
      updateData.orientation = optionalEnum(errors, body.orientation, 'orientation', VALID_ORIENTATIONS,
        `orientation must be one of: ${VALID_ORIENTATIONS.join(', ')}`);
    }
    if (body.gender_identity !== undefined) {
      updateData.genderIdentity = optionalEnum(errors, body.gender_identity, 'gender_identity', VALID_GENDER_IDENTITIES,
        `gender_identity must be one of: ${VALID_GENDER_IDENTITIES.join(', ')}`);
    }
    // Visibility toggle flags — booleans, default true
    if (body.show_sex         !== undefined) updateData.showSex         = typeof body.show_sex         === 'boolean' ? body.show_sex         : (errors['show_sex']         = 'show_sex must be a boolean', undefined);
    if (body.show_orientation !== undefined) updateData.showOrientation = typeof body.show_orientation === 'boolean' ? body.show_orientation : (errors['show_orientation'] = 'show_orientation must be a boolean', undefined);
    if (body.show_identity    !== undefined) updateData.showIdentity    = typeof body.show_identity    === 'boolean' ? body.show_identity    : (errors['show_identity']    = 'show_identity must be a boolean', undefined);

    // ── Background ──────────────────────────────────────────────────────────
    if (body.ethnicity !== undefined) {
      updateData.ethnicity = validateEthnicity(errors, body.ethnicity);
    }
    if (body.birth_country !== undefined) {
      updateData.birthCountry = optionalEnum(errors, body.birth_country, 'birth_country', VALID_BIRTH_COUNTRIES,
        `birth_country must be one of the supported countries`);
    }
    if (body.languages !== undefined) {
      updateData.languages = validateLanguages(errors, body.languages);
    }

    // ── Career & Education ──────────────────────────────────────────────────
    if (body.education !== undefined) {
      updateData.education = optionalEnum(errors, body.education, 'education', VALID_EDUCATION,
        `education must be one of: ${VALID_EDUCATION.join(', ')}`);
    }
    if (body.career_field !== undefined) {
      updateData.careerField = optionalEnum(errors, body.career_field, 'career_field', VALID_CAREER_FIELDS,
        `career_field must be one of: ${VALID_CAREER_FIELDS.join(', ')}`);
    }
    if (body.job_title !== undefined) {
      updateData.jobTitle = optionalString(errors, body.job_title, 'job_title', 'job_title must be a non-empty string');
    }
    if (body.school !== undefined) {
      updateData.school = optionalString(errors, body.school, 'school', 'school must be a non-empty string');
    }

    // ── Height ──────────────────────────────────────────────────────────────
    if (body.height_unit !== undefined) {
      const val = optionalEnum(errors, body.height_unit, 'height_unit', VALID_HEIGHT_UNITS,
        'height_unit must be "imperial" or "metric"');
      updateData.heightUnit = val;
      // Re-validate conditional height fields when height_unit is being updated
      const { heightFt, heightIn, heightCm } = validateHeight(errors, val, body);
      updateData.heightFt = heightFt;
      updateData.heightIn = heightIn;
      updateData.heightCm = heightCm;
    }

    // ── Location ────────────────────────────────────────────────────────────
    if (body.location_city  !== undefined) updateData.locationCity  = optionalString(errors, body.location_city,  'location_city',  'location_city must be a non-empty string');
    if (body.location_state !== undefined) updateData.locationState = optionalString(errors, body.location_state, 'location_state', 'location_state must be a non-empty string');
    if (body.location_zip   !== undefined) updateData.locationZip   = optionalString(errors, body.location_zip,   'location_zip',   'location_zip must be a non-empty string');
    if (body.latitude       !== undefined) updateData.latitude      = requireFloat(errors, body.latitude,  'latitude',  'latitude must be a number');
    if (body.longitude      !== undefined) updateData.longitude     = requireFloat(errors, body.longitude, 'longitude', 'longitude must be a number');

    // ── Bio & Social ────────────────────────────────────────────────────────
    if (body.bio !== undefined) {
      if (body.bio === null) {
        updateData.bio = null;
      } else if (typeof body.bio !== 'string') {
        errors['bio'] = 'bio must be a string';
      } else if (body.bio.length > 500) {
        errors['bio'] = 'bio must be 500 characters or fewer';
      } else {
        updateData.bio = body.bio;
      }
    }
    if (body.instagram_handle     !== undefined) updateData.instagramHandle    = optionalString(errors, body.instagram_handle,     'instagram_handle',     'instagram_handle must be a string');
    if (body.tiktok_handle        !== undefined) updateData.tiktokHandle       = optionalString(errors, body.tiktok_handle,        'tiktok_handle',        'tiktok_handle must be a string');
    if (body.spotify_playlist_url !== undefined) updateData.spotifyPlaylistUrl = optionalString(errors, body.spotify_playlist_url, 'spotify_playlist_url', 'spotify_playlist_url must be a string');

    // ── Lifestyle Habits ────────────────────────────────────────────────────
    if (body.drinks         !== undefined) updateData.drinks        = optionalEnum(errors, body.drinks,         'drinks',         VALID_FREQUENCY,        `drinks must be one of: ${VALID_FREQUENCY.join(', ')}`);
    if (body.smoking        !== undefined) updateData.smoking       = optionalEnum(errors, body.smoking,        'smoking',        VALID_FREQUENCY,        `smoking must be one of: ${VALID_FREQUENCY.join(', ')}`);
    if (body.workout        !== undefined) updateData.workout       = optionalEnum(errors, body.workout,        'workout',        VALID_FREQUENCY,        `workout must be one of: ${VALID_FREQUENCY.join(', ')}`);
    if (body.sleep_schedule !== undefined) updateData.sleepSchedule = optionalEnum(errors, body.sleep_schedule, 'sleep_schedule', VALID_SLEEP_SCHEDULES,  `sleep_schedule must be one of: ${VALID_SLEEP_SCHEDULES.join(', ')}`);
    if (body.pets           !== undefined) updateData.pets          = optionalEnum(errors, body.pets,           'pets',           VALID_PREFERENCE_LEVEL, `pets must be one of: ${VALID_PREFERENCE_LEVEL.join(', ')}`);
    if (body.cannabis       !== undefined) updateData.cannabis      = optionalEnum(errors, body.cannabis,       'cannabis',       VALID_FREQUENCY,        `cannabis must be one of: ${VALID_FREQUENCY.join(', ')}`);
    if (body.pet_types      !== undefined) updateData.petTypes      = optionalString(errors, body.pet_types,  'pet_types',  'pet_types must be a string');
    if (body.pets_name      !== undefined) updateData.petsName      = optionalString(errors, body.pets_name,  'pets_name',  'pets_name must be a string');
    if (body.children       !== undefined) updateData.children      = optionalEnum(errors, body.children,       'children',       VALID_PREFERENCE_LEVEL, `children must be one of: ${VALID_PREFERENCE_LEVEL.join(', ')}`);

    // ── Lifestyle Flexibility Flags ──────────────────────────────────────────
    const boolFields: Array<[string, string]> = [
      ['is_drinks_flexible',   'isDrinksFlexible'],
      ['is_smoking_flexible',  'isSmokingFlexible'],
      ['is_workout_flexible',  'isWorkoutFlexible'],
      ['is_sleep_flexible',    'isSleepFlexible'],
      ['is_cannabis_flexible', 'isCannabisFlexible'],
      ['is_kids_flexible',     'isKidsFlexible'],
    ];
    for (const [bodyKey, dataKey] of boolFields) {
      if (body[bodyKey] !== undefined) {
        if (typeof body[bodyKey] !== 'boolean') {
          errors[bodyKey] = `${bodyKey} must be a boolean`;
        } else {
          updateData[dataKey] = body[bodyKey];
        }
      }
    }

    // ── Personality ─────────────────────────────────────────────────────────
    if (body.love_language !== undefined) {
      updateData.loveLanguage = optionalEnum(errors, body.love_language, 'love_language', VALID_LOVE_LANGUAGES,
        `love_language must be one of: ${VALID_LOVE_LANGUAGES.join(', ')}`);
    }
    if (body.zodiac_sign !== undefined) {
      updateData.zodiacSign = optionalEnum(errors, body.zodiac_sign, 'zodiac_sign', VALID_ZODIAC_SIGNS,
        `zodiac_sign must be one of: ${VALID_ZODIAC_SIGNS.join(', ')}`);
    }
    // communication_style and conflict_style accept "" (empty = neutral/no preference)
    if (body.communication_style !== undefined) {
      if (typeof body.communication_style !== 'string' || !VALID_COMMUNICATION_STYLES.includes(body.communication_style)) {
        errors['communication_style'] = `communication_style must be one of: ${VALID_COMMUNICATION_STYLES.filter(Boolean).join(', ')}, or empty string`;
      } else {
        updateData.communicationStyle = body.communication_style;
      }
    }
    if (body.conflict_style !== undefined) {
      if (typeof body.conflict_style !== 'string' || !VALID_CONFLICT_STYLES.includes(body.conflict_style)) {
        errors['conflict_style'] = `conflict_style must be one of: ${VALID_CONFLICT_STYLES.filter(Boolean).join(', ')}, or empty string`;
      } else {
        updateData.conflictStyle = body.conflict_style;
      }
    }

    // ── Interests & Date Activities ──────────────────────────────────────────
    if (body.interests !== undefined) {
      updateData.interests = validateStringArray(errors, body.interests, 'interests', VALID_INTERESTS, 7);
    }
    if (body.preferred_date_activities !== undefined) {
      updateData.preferredDateActivities = validateStringArray(errors, body.preferred_date_activities, 'preferred_date_activities', VALID_DATE_ACTIVITIES, 3);
    }
    if (body.would_not_do_activities !== undefined) {
      updateData.wouldNotDoActivities = validateStringArray(errors, body.would_not_do_activities, 'would_not_do_activities', VALID_DATE_ACTIVITIES, 3);
    }

    // ── Dating Preferences ───────────────────────────────────────────────────
    if (body.meet_preference !== undefined) {
      updateData.meetPreference = requireEnum(errors, body.meet_preference, 'meet_preference', VALID_MEET_PREFERENCES,
        `meet_preference must be one of: ${VALID_MEET_PREFERENCES.join(', ')}`);
    }
    if (body.relationship_goals !== undefined) {
      updateData.relationshipGoals = validateRelationshipGoals(errors, body.relationship_goals);
    }
    if (body.min_age_preference !== undefined) {
      updateData.minAgePreference = optionalInt(errors, body.min_age_preference, 'min_age_preference', 18, 80,
        'min_age_preference must be between 18 and 80');
    }
    if (body.max_age_preference !== undefined) {
      updateData.maxAgePreference = optionalInt(errors, body.max_age_preference, 'max_age_preference', 18, 80,
        'max_age_preference must be between 18 and 80');
    }
    // For single-field age updates, compare against the persisted counterpart to prevent invalid ranges.
    if (body.min_age_preference !== undefined || body.max_age_preference !== undefined) {
      const effectiveMinAge =
        updateData.minAgePreference !== undefined
          ? (updateData.minAgePreference as number | null)
          : existingProfile!.min_age_preference;
      const effectiveMaxAge =
        updateData.maxAgePreference !== undefined
          ? (updateData.maxAgePreference as number | null)
          : existingProfile!.max_age_preference;

      if (
        effectiveMinAge !== null &&
        effectiveMaxAge !== null &&
        effectiveMaxAge < effectiveMinAge
      ) {
        errors['max_age_preference'] = 'max_age_preference must be greater than or equal to min_age_preference';
      }
    }
    if (body.distance_preference_miles !== undefined) {
      updateData.distancePreferenceMiles = optionalInt(errors, body.distance_preference_miles, 'distance_preference_miles', 1, 100,
        'distance_preference_miles must be between 1 and 100');
    }

    // ── Prompts ─────────────────────────────────────────────────────────────
    if (body.prompts !== undefined) {
      updateData.prompts = validatePrompts(errors, body.prompts);
    }

    // Return all field errors at once (422 Unprocessable Entity)
    if (Object.keys(errors).length > 0) {
      res.status(422).json({ errors });
      return;
    }

    const updated = await this.profileService.updateProfile(user!.id, updateData as any);
    if (!updated) {
      unauthorized('Profile not found', 'PROFILE_NOT_FOUND');
    }

    // iOS only checks the status code — { success: true } is sufficient
    res.status(200).json({ success: true });
  };
}
