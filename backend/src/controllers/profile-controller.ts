import { Request, Response } from 'express';
import { profiles } from '@prisma/client';
import { ProfileService } from '../services/profile-service';
import { UserRepository } from '../repositories/user-repository';
import { unauthorized } from '../utils/errors';

// ─── Allowed values ────────────────────────────────────────────────────────────
// These are the string values the iOS app sends.
// The DB stores equivalent enum values — see ENUM_REFERENCE.md for the mapping.

const VALID_GENDERS = ['Male', 'Female', 'Non-binary', 'Prefer not to say'];

const VALID_ETHNICITIES = [
  'White',
  'Black or African American',
  'Hispanic or Latino',
  'Asian',
  'Native American',
  'Native Hawaiian',
  'Middle Eastern',
  'Two or more',
  'Prefer not to say',
];

const VALID_HEIGHT_UNITS = ['imperial', 'metric'];

const VALID_MEET_PREFERENCES = ['Men', 'Women', 'Open to both'];

const VALID_RELATIONSHIP_GOALS = ['Short Term', 'Long Term', 'Marriage', 'Still figuring out'];

const VALID_FREQUENCY = ['Never', 'Sometimes', 'Often'];

const VALID_PREFERENCE_LEVEL = ["Don't want", 'Unsure', 'Want', 'Have'];

const VALID_SLEEP_SCHEDULES = ['Night Owl', 'Early Bird', 'Flexible'];

// ─── Validation helpers ────────────────────────────────────────────────────────
// Each helper returns the validated value or adds an error to the errors map.
// This approach collects all field errors at once instead of throwing on the first.

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

  // Check 18+ age requirement
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

// Validates height fields based on the chosen unit
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

// Validates prompts array (0–3 items, each with question, answer, is_custom)
function validatePrompts(
  errors: ErrorMap,
  value: unknown,
): Array<{ question: string; answer: string; is_custom: boolean }> | null {
  if (value === undefined || value === null) return null;

  if (!Array.isArray(value)) {
    errors['prompts'] = 'prompts must be an array';
    return null;
  }
  if (value.length > 3) {
    errors['prompts'] = 'Maximum 3 prompts allowed';
    return null;
  }
  for (const item of value) {
    if (
      typeof item.question !== 'string' ||
      typeof item.answer !== 'string' ||
      typeof item.is_custom !== 'boolean'
    ) {
      errors['prompts'] = 'Each prompt must have question (string), answer (string), and is_custom (boolean)';
      return null;
    }
  }
  return value as Array<{ question: string; answer: string; is_custom: boolean }>;
}

// Optional string enum — returns null if value is null/undefined, validates if present
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

// ─── Serializer ────────────────────────────────────────────────────────────────
// Converts a DB profiles row to the API response shape defined in API_SPEC.md §2.1
// DB column names are mapped to API field names here (e.g. state → location_state)

function serializeProfile(profile: profiles): Record<string, unknown> {
  return {
    user_id:                   profile.user_id,
    first_name:                profile.first_name ?? null,
    last_name:                 profile.last_name ?? null,
    birth_date:                profile.birth_date ?? null,
    gender:                    profile.gender ?? null,
    ethnicity:                 profile.ethnicity ?? null,
    height_unit:               profile.height_unit ?? null,
    height_ft:                 profile.height_ft ?? null,
    height_in:                 profile.height_in ?? null,
    height_cm:                 profile.height_cm ?? null,
    latitude:                  profile.latitude ?? null,
    longitude:                 profile.longitude ?? null,
    location_city:             profile.location_city ?? null,
    location_state:            profile.state ?? null,       // DB: state → API: location_state
    location_zip:              profile.zip_code ?? null,    // DB: zip_code → API: location_zip
    meet_preference:           profile.meet_preference ?? null,
    relationship_goals:        profile.relationship_goals ?? null,
    min_age_preference:        profile.min_age_preference ?? null,
    max_age_preference:        profile.max_age_preference ?? null,
    distance_preference_miles: profile.distance_preference_miles ?? null,
    drinks:                    profile.lifestyle_drinks ?? null,
    smoking:                   profile.lifestyle_smoking ?? null,
    pets:                      profile.lifestyle_pets ?? null,
    children:                  profile.lifestyle_children ?? null,
    workout:                   profile.lifestyle_workout ?? null,
    sleep_schedule:            profile.lifestyle_sleep ?? null,
    bio:                       profile.bio ?? null,
    prompts:                   profile.prompts ?? null,
  };
}

// ─── Controller ────────────────────────────────────────────────────────────────

export class ProfileController {
  constructor(
    private readonly profileService: ProfileService,
    private readonly userRepository: UserRepository,
  ) {}

  // Helper to resolve the authenticated user's DB record from their Firebase UID
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
  // Creates the user's profile after they complete the onboarding survey.
  // All required fields must be present; optional fields default to null.
  // Returns 201 { user_id } on success, 422 with field errors on validation failure.
  createProfile = async (req: Request, res: Response): Promise<void> => {
    const user = await this.resolveUser(req);
    const body = req.body ?? {};
    const errors: ErrorMap = {};

    // ── Step 1: Basic Info ──────────────────────────────────────────────────
    const firstName  = requireString(errors, body.first_name,  'first_name',  'first_name is required');
    const lastName   = requireString(errors, body.last_name,   'last_name',   'last_name is required');
    const birthDate  = validateBirthDate(errors, body.birth_date);
    const gender     = requireEnum(errors, body.gender, 'gender', VALID_GENDERS,
                         `gender must be one of: ${VALID_GENDERS.join(', ')}`);
    const ethnicity  = requireEnum(errors, body.ethnicity, 'ethnicity', VALID_ETHNICITIES,
                         `ethnicity must be one of: ${VALID_ETHNICITIES.join(', ')}`);
    const heightUnit = requireEnum(errors, body.height_unit, 'height_unit', VALID_HEIGHT_UNITS,
                         'height_unit must be "imperial" or "metric"');
    const { heightFt, heightIn, heightCm } = validateHeight(errors, heightUnit, body);

    const locationCity  = requireString(errors, body.location_city,  'location_city',  'location_city is required');
    const locationState = requireString(errors, body.location_state, 'location_state', 'location_state is required');
    const locationZip   = requireString(errors, body.location_zip,   'location_zip',   'location_zip is required');
    const latitude      = requireFloat(errors, body.latitude,   'latitude',   'latitude is required and must be a number');
    const longitude     = requireFloat(errors, body.longitude,  'longitude',  'longitude is required and must be a number');

    // ── Step 2: Preferences ─────────────────────────────────────────────────
    const meetPreference = requireEnum(errors, body.meet_preference, 'meet_preference', VALID_MEET_PREFERENCES,
                             `meet_preference must be one of: ${VALID_MEET_PREFERENCES.join(', ')}`);
    const relationshipGoals     = validateRelationshipGoals(errors, body.relationship_goals);
    const minAgePreference      = requireInt(errors, body.min_age_preference, 'min_age_preference', 18, 80,
                                    'min_age_preference must be between 18 and 80');
    const maxAgePreference      = requireInt(errors, body.max_age_preference, 'max_age_preference', 18, 80,
                                    'max_age_preference must be between 18 and 80');
    const distancePreferenceMiles = requireInt(errors, body.distance_preference_miles, 'distance_preference_miles', 1, 100,
                                      'distance_preference_miles must be between 1 and 100');

    // max must be >= min (only check if both values parsed without error)
    if (minAgePreference !== null && maxAgePreference !== null && maxAgePreference < minAgePreference) {
      errors['max_age_preference'] = 'max_age_preference must be greater than or equal to min_age_preference';
    }

    // ── Step 3: Lifestyle Habits (all optional) ─────────────────────────────
    const drinks       = optionalEnum(errors, body.drinks,          'drinks',          VALID_FREQUENCY,         `drinks must be one of: ${VALID_FREQUENCY.join(', ')}`);
    const smoking      = optionalEnum(errors, body.smoking,         'smoking',         VALID_FREQUENCY,         `smoking must be one of: ${VALID_FREQUENCY.join(', ')}`);
    const pets         = optionalEnum(errors, body.pets,            'pets',            VALID_PREFERENCE_LEVEL,  `pets must be one of: ${VALID_PREFERENCE_LEVEL.join(', ')}`);
    const children     = optionalEnum(errors, body.children,        'children',        VALID_PREFERENCE_LEVEL,  `children must be one of: ${VALID_PREFERENCE_LEVEL.join(', ')}`);
    const workout      = optionalEnum(errors, body.workout,         'workout',         VALID_FREQUENCY,         `workout must be one of: ${VALID_FREQUENCY.join(', ')}`);
    const sleepSchedule = optionalEnum(errors, body.sleep_schedule, 'sleep_schedule',  VALID_SLEEP_SCHEDULES,   `sleep_schedule must be one of: ${VALID_SLEEP_SCHEDULES.join(', ')}`);

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

    // All validations passed — create the profile
    const profile = await this.profileService.createProfile({
      userId:                  user!.id,
      firstName:               firstName!,
      lastName:                lastName!,
      birthDate:               birthDate!,
      gender:                  gender!,
      ethnicity:               ethnicity!,
      heightUnit:              heightUnit!,
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

    // Return just the user_id as per API spec §2.2
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

    res.status(200).json(serializeProfile(profile!));
  };
}
