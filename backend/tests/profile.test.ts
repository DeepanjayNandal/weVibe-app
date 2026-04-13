import request from 'supertest';
import { PrismaClient } from '@prisma/client';
import { createApp } from '../src/app';

const prisma = new PrismaClient();
const app = createApp();

const VALID_PROFILE = {
  first_name: 'Alice',
  last_name: 'Smith',
  birth_date: '1998-05-20',
  gender: 'Female',
  location_city: 'Taipei',
  location_state: 'Taiwan',
  location_zip: '100',
  latitude: 25.033,
  longitude: 121.565,
  meet_preference: 'Men',
  relationship_goals: ['Long Term'],
  min_age_preference: 22,
  max_age_preference: 30,
  distance_preference_miles: 50,
};

describe('Profile API - POST /api/v1/users/profile', () => {
  beforeAll(async () => {
    await prisma.$connect();
  });

  beforeEach(async () => {
    await prisma.$executeRaw`DELETE FROM profiles WHERE user_id IN (SELECT id FROM users WHERE email LIKE '%@profile.test')`;
    await prisma.$executeRaw`DELETE FROM users WHERE email LIKE '%@profile.test'`;
  });

  afterAll(async () => {
    await prisma.$disconnect();
  });

  async function registerUser(token: string): Promise<void> {
    await request(app)
      .post('/api/v1/auth/register')
      .send({ provider: 'google', idToken: token });
  }

  test('should create a profile for a registered user', async () => {
    const token = 'mock:google:p-001:alice@profile.test';
    await registerUser(token);

    const response = await request(app)
      .post('/api/v1/users/profile')
      .set('Authorization', `Bearer ${token}`)
      .send(VALID_PROFILE);

    expect(response.status).toBe(201);
    expect(response.body.user_id).toBeDefined();
  });

  test('should return 201 idempotently if profile already exists (iOS retry safety)', async () => {
    const token = 'mock:google:p-002:bob@profile.test';
    await registerUser(token);

    await request(app)
      .post('/api/v1/users/profile')
      .set('Authorization', `Bearer ${token}`)
      .send({ ...VALID_PROFILE, gender: 'Male', meet_preference: 'Women' });

    // Simulates iOS retrying after a lost network response — must be idempotent
    const response = await request(app)
      .post('/api/v1/users/profile')
      .set('Authorization', `Bearer ${token}`)
      .send({ ...VALID_PROFILE, gender: 'Male', meet_preference: 'Women' });

    expect(response.status).toBe(201);
    expect(response.body.user_id).toBeDefined();
  });

  test('should return 401 without bearer token', async () => {
    const response = await request(app)
      .post('/api/v1/users/profile')
      .send(VALID_PROFILE);

    expect(response.status).toBe(401);
    expect(response.body.error.code).toBe('MISSING_BEARER_TOKEN');
  });

  test('should return 422 for missing birth_date', async () => {
    const token = 'mock:google:p-003:charlie@profile.test';
    await registerUser(token);

    const { birth_date, ...withoutBirthDate } = VALID_PROFILE;
    const response = await request(app)
      .post('/api/v1/users/profile')
      .set('Authorization', `Bearer ${token}`)
      .send(withoutBirthDate);

    expect(response.status).toBe(422);
    expect(response.body.errors.birth_date).toBeDefined();
  });

  test('should return 422 for invalid birth_date format', async () => {
    const token = 'mock:google:p-004:diana@profile.test';
    await registerUser(token);

    const response = await request(app)
      .post('/api/v1/users/profile')
      .set('Authorization', `Bearer ${token}`)
      .send({ ...VALID_PROFILE, birth_date: 'not-a-date' });

    expect(response.status).toBe(422);
    expect(response.body.errors.birth_date).toBeDefined();
  });

  test('should return 422 for missing gender', async () => {
    const token = 'mock:google:p-005:evan@profile.test';
    await registerUser(token);

    const { gender, ...withoutGender } = VALID_PROFILE;
    const response = await request(app)
      .post('/api/v1/users/profile')
      .set('Authorization', `Bearer ${token}`)
      .send(withoutGender);

    expect(response.status).toBe(422);
    expect(response.body.errors.gender).toBeDefined();
  });

  test('should return 422 for invalid gender value', async () => {
    const token = 'mock:google:p-006:fiona@profile.test';
    await registerUser(token);

    const response = await request(app)
      .post('/api/v1/users/profile')
      .set('Authorization', `Bearer ${token}`)
      .send({ ...VALID_PROFILE, gender: 'attack_helicopter' });

    expect(response.status).toBe(422);
    expect(response.body.errors.gender).toBeDefined();
  });

  test('should return 422 for missing location fields', async () => {
    const token = 'mock:google:p-007:george@profile.test';
    await registerUser(token);

    const { location_city, location_state, location_zip, latitude, longitude, ...withoutLocation } = VALID_PROFILE;
    const response = await request(app)
      .post('/api/v1/users/profile')
      .set('Authorization', `Bearer ${token}`)
      .send(withoutLocation);

    expect(response.status).toBe(422);
    expect(response.body.errors.location_city).toBeDefined();
  });

  test('should return 422 for missing meet_preference', async () => {
    const token = 'mock:google:p-008:hannah@profile.test';
    await registerUser(token);

    const { meet_preference, ...withoutMeetPref } = VALID_PROFILE;
    const response = await request(app)
      .post('/api/v1/users/profile')
      .set('Authorization', `Bearer ${token}`)
      .send(withoutMeetPref);

    expect(response.status).toBe(422);
    expect(response.body.errors.meet_preference).toBeDefined();
  });

  test('should accept all valid gender values', async () => {
    const genders = ['Male', 'Female', 'Non-binary', 'Prefer not to say'];
    const meetPrefs = ['Women', 'Men', 'Open to both', 'Open to both'];

    for (let i = 0; i < genders.length; i++) {
      const token = `mock:google:p-gender-${i}:gendertest${i}@profile.test`;
      await registerUser(token);

      const response = await request(app)
        .post('/api/v1/users/profile')
        .set('Authorization', `Bearer ${token}`)
        .send({ ...VALID_PROFILE, gender: genders[i], meet_preference: meetPrefs[i] });

      expect(response.status).toBe(201);
      expect(response.body.user_id).toBeDefined();
    }
  });
});

describe('Profile API - GET /api/v1/users/profile', () => {
  beforeAll(async () => {
    await prisma.$connect();
  });

  beforeEach(async () => {
    await prisma.$executeRaw`DELETE FROM profiles WHERE user_id IN (SELECT id FROM users WHERE email LIKE '%@get.profile.test')`;
    await prisma.$executeRaw`DELETE FROM users WHERE email LIKE '%@get.profile.test'`;
  });

  afterAll(async () => {
    await prisma.$disconnect();
  });

  async function registerUser(token: string): Promise<void> {
    await request(app)
      .post('/api/v1/auth/register')
      .send({ provider: 'google', idToken: token });
  }

  async function createProfile(token: string): Promise<void> {
    await request(app)
      .post('/api/v1/users/profile')
      .set('Authorization', `Bearer ${token}`)
      .send(VALID_PROFILE);
  }

  test('should return profile for authenticated user', async () => {
    const token = 'mock:google:g-001:alice@get.profile.test';
    await registerUser(token);
    await createProfile(token);

    const response = await request(app)
      .get('/api/v1/users/profile')
      .set('Authorization', `Bearer ${token}`);

    expect(response.status).toBe(200);
    expect(response.body.first_name).toBe('Alice');
    expect(response.body.last_name).toBe('Smith');
    expect(response.body.gender).toBe('Female');
    expect(response.body.birth_date).toBeDefined();
  });

  test('should return 401 without bearer token', async () => {
    const response = await request(app).get('/api/v1/users/profile');

    expect(response.status).toBe(401);
    expect(response.body.error.code).toBe('MISSING_BEARER_TOKEN');
  });

  test('should return 401 if profile does not exist', async () => {
    const token = 'mock:google:g-002:bob@get.profile.test';
    await registerUser(token);

    const response = await request(app)
      .get('/api/v1/users/profile')
      .set('Authorization', `Bearer ${token}`);

    expect(response.status).toBe(401);
    expect(response.body.error.code).toBe('PROFILE_NOT_FOUND');
  });
});
