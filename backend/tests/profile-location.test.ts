import request from 'supertest';
import { PrismaClient } from '@prisma/client';
import { createApp } from '../src/app';

const prisma = new PrismaClient();
const app = createApp();

const EMAIL_DOMAIN = '@loc.profile.test';

const VALID_PROFILE = {
  first_name: 'Alice',
  last_name: 'Smith',
  birth_date: '1998-05-20',
  gender: 'Female',
  location_city: 'San Francisco',
  location_state: 'CA',
  location_zip: '94102',
  latitude: 37.7749,
  longitude: -122.4194,
  meet_preference: 'Men',
  relationship_goals: ['Long Term'],
  min_age_preference: 22,
  max_age_preference: 35,
  distance_preference_miles: 50,
};

const VALID_LOCATION = {
  latitude: 37.7749,
  longitude: -122.4194,
  location_city: 'San Francisco',
  location_state: 'CA',
  location_zip: '94102',
};

describe('Profile API - PATCH /api/v1/users/profile/location', () => {
  beforeAll(async () => {
    await prisma.$connect();
  });

  beforeEach(async () => {
    await prisma.$executeRaw`DELETE FROM profiles WHERE user_id IN (SELECT id FROM users WHERE email LIKE ${'%' + EMAIL_DOMAIN})`;
    await prisma.$executeRaw`DELETE FROM users WHERE email LIKE ${'%' + EMAIL_DOMAIN}`;
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

  // ── Success ───────────────────────────────────────────────────────────────

  test('should return 204 and persist all location fields', async () => {
    const token = `mock:google:loc-001:alice${EMAIL_DOMAIN}`;
    await registerUser(token);
    await createProfile(token);

    const newLocation = {
      latitude: 40.7128,
      longitude: -74.006,
      location_city: 'New York',
      location_state: 'NY',
      location_zip: '10001',
    };

    const response = await request(app)
      .patch('/api/v1/users/profile/location')
      .set('Authorization', `Bearer ${token}`)
      .send(newLocation);

    expect(response.status).toBe(204);
    expect(response.body).toEqual({});

    // Verify the DB was actually updated
    const user = await prisma.users.findFirst({ where: { email: `alice${EMAIL_DOMAIN}` } });
    const profile = await prisma.profiles.findUnique({ where: { user_id: user!.id } });
    expect(Number(profile!.latitude)).toBeCloseTo(40.7128, 4);
    expect(Number(profile!.longitude)).toBeCloseTo(-74.006, 4);
    expect(profile!.location_city).toBe('New York');
    expect(profile!.state).toBe('NY');
    expect(profile!.zip_code).toBe('10001');
  });

  test('should update location_point (PostGIS) alongside profile columns', async () => {
    const token = `mock:google:loc-002:bob${EMAIL_DOMAIN}`;
    await registerUser(token);
    await createProfile(token);

    await request(app)
      .patch('/api/v1/users/profile/location')
      .set('Authorization', `Bearer ${token}`)
      .send({ latitude: 51.5074, longitude: -0.1278, location_city: 'London', location_state: 'ENG', location_zip: 'SW1A' });

    const user = await prisma.users.findFirst({ where: { email: `bob${EMAIL_DOMAIN}` } });
    const result = await prisma.$queryRaw<Array<{ has_point: boolean }>>`
      SELECT location_point IS NOT NULL AS has_point
      FROM profiles
      WHERE user_id = ${user!.id}::uuid
    `;
    expect(result[0].has_point).toBe(true);
  });

  test('should accept negative coordinates (southern/western hemisphere)', async () => {
    const token = `mock:google:loc-003:carol${EMAIL_DOMAIN}`;
    await registerUser(token);
    await createProfile(token);

    const response = await request(app)
      .patch('/api/v1/users/profile/location')
      .set('Authorization', `Bearer ${token}`)
      .send({ latitude: -33.8688, longitude: 151.2093, location_city: 'Sydney', location_state: 'NSW', location_zip: '2000' });

    expect(response.status).toBe(204);
  });

  // ── Auth ──────────────────────────────────────────────────────────────────

  test('should return 401 without bearer token', async () => {
    const response = await request(app)
      .patch('/api/v1/users/profile/location')
      .send(VALID_LOCATION);

    expect(response.status).toBe(401);
    expect(response.body.error.code).toBe('MISSING_BEARER_TOKEN');
  });

  test('should return 401 if user has no profile yet', async () => {
    const token = `mock:google:loc-004:dave${EMAIL_DOMAIN}`;
    await registerUser(token);
    // deliberately skip createProfile

    const response = await request(app)
      .patch('/api/v1/users/profile/location')
      .set('Authorization', `Bearer ${token}`)
      .send(VALID_LOCATION);

    expect(response.status).toBe(401);
    expect(response.body.error.code).toBe('PROFILE_NOT_FOUND');
  });

  // ── Validation: missing fields ────────────────────────────────────────────

  test('should return 422 when latitude is missing', async () => {
    const token = `mock:google:loc-005:eve${EMAIL_DOMAIN}`;
    await registerUser(token);
    await createProfile(token);

    const { latitude, ...body } = VALID_LOCATION;
    const response = await request(app)
      .patch('/api/v1/users/profile/location')
      .set('Authorization', `Bearer ${token}`)
      .send(body);

    expect(response.status).toBe(422);
    expect(response.body.errors.latitude).toBeDefined();
  });

  test('should return 422 when longitude is missing', async () => {
    const token = `mock:google:loc-006:frank${EMAIL_DOMAIN}`;
    await registerUser(token);
    await createProfile(token);

    const { longitude, ...body } = VALID_LOCATION;
    const response = await request(app)
      .patch('/api/v1/users/profile/location')
      .set('Authorization', `Bearer ${token}`)
      .send(body);

    expect(response.status).toBe(422);
    expect(response.body.errors.longitude).toBeDefined();
  });

  test('should return 422 when location_city is missing', async () => {
    const token = `mock:google:loc-007:grace${EMAIL_DOMAIN}`;
    await registerUser(token);
    await createProfile(token);

    const { location_city, ...body } = VALID_LOCATION;
    const response = await request(app)
      .patch('/api/v1/users/profile/location')
      .set('Authorization', `Bearer ${token}`)
      .send(body);

    expect(response.status).toBe(422);
    expect(response.body.errors.location_city).toBeDefined();
  });

  test('should return 422 when location_state is missing', async () => {
    const token = `mock:google:loc-008:henry${EMAIL_DOMAIN}`;
    await registerUser(token);
    await createProfile(token);

    const { location_state, ...body } = VALID_LOCATION;
    const response = await request(app)
      .patch('/api/v1/users/profile/location')
      .set('Authorization', `Bearer ${token}`)
      .send(body);

    expect(response.status).toBe(422);
    expect(response.body.errors.location_state).toBeDefined();
  });

  test('should return 422 when location_zip is missing', async () => {
    const token = `mock:google:loc-009:iris${EMAIL_DOMAIN}`;
    await registerUser(token);
    await createProfile(token);

    const { location_zip, ...body } = VALID_LOCATION;
    const response = await request(app)
      .patch('/api/v1/users/profile/location')
      .set('Authorization', `Bearer ${token}`)
      .send(body);

    expect(response.status).toBe(422);
    expect(response.body.errors.location_zip).toBeDefined();
  });

  // ── Validation: wrong types ───────────────────────────────────────────────

  test('should return 422 when latitude is a string', async () => {
    const token = `mock:google:loc-010:jake${EMAIL_DOMAIN}`;
    await registerUser(token);
    await createProfile(token);

    const response = await request(app)
      .patch('/api/v1/users/profile/location')
      .set('Authorization', `Bearer ${token}`)
      .send({ ...VALID_LOCATION, latitude: 'not-a-number' });

    expect(response.status).toBe(422);
    expect(response.body.errors.latitude).toBeDefined();
  });

  test('should return 422 when longitude is a string', async () => {
    const token = `mock:google:loc-011:kate${EMAIL_DOMAIN}`;
    await registerUser(token);
    await createProfile(token);

    const response = await request(app)
      .patch('/api/v1/users/profile/location')
      .set('Authorization', `Bearer ${token}`)
      .send({ ...VALID_LOCATION, longitude: 'not-a-number' });

    expect(response.status).toBe(422);
    expect(response.body.errors.longitude).toBeDefined();
  });

  test('should return 422 when all fields are missing', async () => {
    const token = `mock:google:loc-012:leo${EMAIL_DOMAIN}`;
    await registerUser(token);
    await createProfile(token);

    const response = await request(app)
      .patch('/api/v1/users/profile/location')
      .set('Authorization', `Bearer ${token}`)
      .send({});

    expect(response.status).toBe(422);
    expect(Object.keys(response.body.errors).length).toBe(5);
  });
});
