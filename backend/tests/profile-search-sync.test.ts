import request from 'supertest';
import { PrismaClient } from '@prisma/client';
import { createApp } from '../src/app';

const prisma = new PrismaClient();
const app = createApp();

describe('Profile preference and location sync', () => {
  beforeAll(async () => {
    await prisma.$connect();
  });

  beforeEach(async () => {
    await prisma.$executeRaw`DELETE FROM profiles WHERE user_id IN (SELECT id FROM users WHERE email LIKE '%@profile-sync.test')`;
    await prisma.$executeRaw`DELETE FROM users WHERE email LIKE '%@profile-sync.test'`;
  });

  afterAll(async () => {
    await prisma.$disconnect();
  });

  async function registerUser(token: string): Promise<void> {
    await request(app)
      .post('/api/v1/auth/register')
      .send({ provider: 'google', idToken: token });
  }

  test('create profile syncs users.search_* and location_point', async () => {
    const token = 'mock:google:ps-001:ps-001@profile-sync.test';
    await registerUser(token);

    const createResponse = await request(app)
      .post('/api/v1/users/profile')
      .set('Authorization', `Bearer ${token}`)
      .send({
        first_name: 'Josh',
        last_name: 'Wang',
        birth_date: '1997-06-15',
        gender: 'Male',
        location_city: 'Mesa',
        location_state: 'AZ',
        location_zip: '85212',
        latitude: 33.3071663,
        longitude: -111.6784706,
        meet_preference: 'Women',
        relationship_goals: ['Long Term'],
        min_age_preference: 24,
        max_age_preference: 32,
        distance_preference_miles: 18,
      });

    expect(createResponse.status).toBe(201);

    const user = await prisma.users.findUnique({
      where: { firebase_uid: 'ps-001' },
      select: {
        id: true,
        search_gender: true,
        search_age_min: true,
        search_age_max: true,
        search_radius_km: true,
      },
    });

    expect(user).not.toBeNull();
    expect(user?.search_gender).toBe('women');
    expect(user?.search_age_min).toBe(24);
    expect(user?.search_age_max).toBe(32);
    expect(user?.search_radius_km).toBe(29);

    const pointRows = await prisma.$queryRaw<Array<{ has_point: boolean; lng: number; lat: number }>>`
      SELECT
        location_point IS NOT NULL AS has_point,
        ST_X(location_point::geometry) AS lng,
        ST_Y(location_point::geometry) AS lat
      FROM profiles
      WHERE user_id = ${user?.id}::uuid
      LIMIT 1
    `;

    expect(pointRows).toHaveLength(1);
    expect(pointRows[0].has_point).toBe(true);
    expect(pointRows[0].lng).toBeCloseTo(-111.6784706, 5);
    expect(pointRows[0].lat).toBeCloseTo(33.3071663, 5);
  });

  test('patch profile syncs updated preferences and partial coordinate changes', async () => {
    const token = 'mock:google:ps-002:ps-002@profile-sync.test';
    await registerUser(token);

    await request(app)
      .post('/api/v1/users/profile')
      .set('Authorization', `Bearer ${token}`)
      .send({
        first_name: 'Amie',
        last_name: 'Nguyen',
        birth_date: '2000-10-29',
        gender: 'Female',
        location_city: 'Mesa',
        location_state: 'AZ',
        location_zip: '85212',
        latitude: 33.3071663,
        longitude: -111.6784706,
        meet_preference: 'Men',
        relationship_goals: ['Long Term'],
        min_age_preference: 24,
        max_age_preference: 39,
        distance_preference_miles: 18,
      });

    const patchResponse = await request(app)
      .patch('/api/v1/users/profile')
      .set('Authorization', `Bearer ${token}`)
      .send({
        meet_preference: 'Open to both',
        min_age_preference: 21,
        max_age_preference: 45,
        distance_preference_miles: 10,
        longitude: -111.6700000,
      });

    expect(patchResponse.status).toBe(200);

    const user = await prisma.users.findUnique({
      where: { firebase_uid: 'ps-002' },
      select: {
        id: true,
        search_gender: true,
        search_age_min: true,
        search_age_max: true,
        search_radius_km: true,
      },
    });

    expect(user).not.toBeNull();
    expect(user?.search_gender).toBe('both');
    expect(user?.search_age_min).toBe(21);
    expect(user?.search_age_max).toBe(45);
    expect(user?.search_radius_km).toBe(16);

    const pointRows = await prisma.$queryRaw<Array<{ lng: number; lat: number }>>`
      SELECT
        ST_X(location_point::geometry) AS lng,
        ST_Y(location_point::geometry) AS lat
      FROM profiles
      WHERE user_id = ${user?.id}::uuid
      LIMIT 1
    `;

    expect(pointRows).toHaveLength(1);
    expect(pointRows[0].lng).toBeCloseTo(-111.6700000, 5);
    expect(pointRows[0].lat).toBeCloseTo(33.3071663, 5);
  });
});
