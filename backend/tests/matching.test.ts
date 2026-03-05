import request from 'supertest';
import { PrismaClient, enum_meet_gender } from '@prisma/client';
import { createApp } from '../src/app';

const prisma = new PrismaClient();
const app = createApp();

type TestUserSetup = {
  token: string;
  birthDate: string;
  gender: string;
  searchGender: enum_meet_gender;
  ageMin?: number;
  ageMax?: number;
  radiusKm?: number;
  personality?: string;
  latitude: number;
  longitude: number;
};

async function registerUser(token: string): Promise<void> {
  await request(app)
    .post('/api/v1/auth/register')
    .send({ provider: 'google', idToken: token });
}

async function setupUser(config: TestUserSetup): Promise<void> {
  await registerUser(config.token);

  const uid = config.token.split(':')[2];
  const user = await prisma.users.findUnique({ where: { firebase_uid: uid } });
  if (!user) {
    throw new Error('User not found after registration');
  }

  await prisma.users.update({
    where: { id: user.id },
    data: {
      search_gender: config.searchGender,
      search_age_min: config.ageMin ?? 18,
      search_age_max: config.ageMax ?? 35,
      search_radius_km: config.radiusKm ?? 50,
      current_status: 'active',
    },
  });

  await prisma.profiles.upsert({
    where: { user_id: user.id },
    update: {
      display_name: uid,
      birth_date: new Date(config.birthDate),
      gender: config.gender,
      personality_primary: config.personality ?? 'A',
    },
    create: {
      user_id: user.id,
      display_name: uid,
      birth_date: new Date(config.birthDate),
      gender: config.gender,
      personality_primary: config.personality ?? 'A',
    },
  });

  await prisma.$executeRaw`
    UPDATE profiles
    SET location_point = ST_SetSRID(ST_MakePoint(${config.longitude}, ${config.latitude}), 4326)::geography
    WHERE user_id = ${user.id}::uuid
  `;
}

describe('Matching Queue API', () => {
  beforeAll(async () => {
    await prisma.$connect();
  });

  beforeEach(async () => {
    await prisma.$executeRaw`DELETE FROM user_blocks`;
    await prisma.$executeRaw`DELETE FROM matching_queue`;
    await prisma.$executeRaw`DELETE FROM speed_dating_sessions`;
    await prisma.$executeRaw`DELETE FROM matches`;
    await prisma.$executeRaw`DELETE FROM profiles WHERE user_id IN (SELECT id FROM users WHERE email LIKE '%@matching.test')`;
    await prisma.$executeRaw`DELETE FROM users WHERE email LIKE '%@matching.test'`;
  });

  afterAll(async () => {
    await prisma.$disconnect();
  });

  test('join queue returns waiting when no candidate exists', async () => {
    const tokenA = 'mock:google:mq-a-001:mq-a-001@matching.test';

    await setupUser({
      token: tokenA,
      birthDate: '1996-06-10',
      gender: 'Male',
      searchGender: 'women',
      latitude: 25.033,
      longitude: 121.5654,
    });

    const response = await request(app)
      .post('/api/v1/matching/queue/join')
      .set('Authorization', `Bearer ${tokenA}`);

    expect(response.status).toBe(200);
    expect(response.body.success).toBe(true);
    expect(response.body.data.state).toBe('waiting');
    expect(response.body.data.poolSize).toBe(0);

    const queueStatus = await request(app)
      .get('/api/v1/matching/queue/status')
      .set('Authorization', `Bearer ${tokenA}`);

    expect(queueStatus.status).toBe(200);
    expect(queueStatus.body.data.inQueue).toBe(true);
  });

  test('second user joins and creates a match, both leave queue', async () => {
    const tokenA = 'mock:google:mq-a-002:mq-a-002@matching.test';
    const tokenB = 'mock:google:mq-b-002:mq-b-002@matching.test';

    await setupUser({
      token: tokenA,
      birthDate: '1996-06-10',
      gender: 'Male',
      searchGender: 'women',
      latitude: 25.033,
      longitude: 121.5654,
    });

    await setupUser({
      token: tokenB,
      birthDate: '1997-08-14',
      gender: 'Female',
      searchGender: 'men',
      latitude: 25.034,
      longitude: 121.565,
    });

    await request(app)
      .post('/api/v1/matching/queue/join')
      .set('Authorization', `Bearer ${tokenA}`);

    const response = await request(app)
      .post('/api/v1/matching/queue/join')
      .set('Authorization', `Bearer ${tokenB}`);

    expect(response.status).toBe(200);
    expect(response.body.data.state).toBe('matched');
    expect(response.body.data.sessionId).toBeDefined();

    const remaining = await prisma.matching_queue.count();
    expect(remaining).toBe(0);

    const sessions = await prisma.speed_dating_sessions.findMany();
    expect(sessions).toHaveLength(1);
  });

  test('hard filter blocks mismatch and keeps user waiting', async () => {
    const tokenA = 'mock:google:mq-a-003:mq-a-003@matching.test';
    const tokenB = 'mock:google:mq-b-003:mq-b-003@matching.test';

    await setupUser({
      token: tokenA,
      birthDate: '1996-06-10',
      gender: 'Male',
      searchGender: 'women',
      latitude: 25.033,
      longitude: 121.5654,
    });

    await setupUser({
      token: tokenB,
      birthDate: '1997-08-14',
      gender: 'Male',
      searchGender: 'women',
      latitude: 25.0331,
      longitude: 121.5652,
    });

    await request(app)
      .post('/api/v1/matching/queue/join')
      .set('Authorization', `Bearer ${tokenA}`);

    const response = await request(app)
      .post('/api/v1/matching/queue/join')
      .set('Authorization', `Bearer ${tokenB}`);

    expect(response.status).toBe(200);
    expect(response.body.data.state).toBe('waiting');

    const queueCount = await prisma.matching_queue.count();
    expect(queueCount).toBe(2);
  });

  test('selector picks highest combined bilateral score from candidate pool', async () => {
    const tokenB = 'mock:google:mq-b-004:mq-b-004@matching.test';
    const tokenC = 'mock:google:mq-c-004:mq-c-004@matching.test';
    const tokenA = 'mock:google:mq-a-004:mq-a-004@matching.test';

    await setupUser({
      token: tokenB,
      birthDate: '1995-02-10',
      gender: 'Female',
      searchGender: 'men',
      personality: 'B',
      latitude: 25.033,
      longitude: 121.5654,
    });

    await setupUser({
      token: tokenC,
      birthDate: '1994-03-15',
      gender: 'Female',
      searchGender: 'men',
      personality: 'C',
      latitude: 25.0335,
      longitude: 121.565,
    });

    await setupUser({
      token: tokenA,
      birthDate: '1996-06-10',
      gender: 'Male',
      searchGender: 'women',
      personality: 'A',
      latitude: 25.0332,
      longitude: 121.5652,
    });

    await request(app)
      .post('/api/v1/matching/queue/join')
      .set('Authorization', `Bearer ${tokenB}`);

    await request(app)
      .post('/api/v1/matching/queue/join')
      .set('Authorization', `Bearer ${tokenC}`);

    const response = await request(app)
      .post('/api/v1/matching/queue/join')
      .set('Authorization', `Bearer ${tokenA}`);

    expect(response.status).toBe(200);
    expect(response.body.data.state).toBe('matched');
    expect(response.body.data.selectedCandidate).toBeDefined();

    // A/C personality pairing is bilateral-high and should beat A/B
    const selectedDisplayName = response.body.data.selectedCandidate.displayName as string;
    expect(selectedDisplayName).toContain('mq-c-004');
  });

  test('pair-level block prevents rematch in both directions', async () => {
    const tokenA = 'mock:google:mq-a-005:mq-a-005@matching.test';
    const tokenB = 'mock:google:mq-b-005:mq-b-005@matching.test';

    await setupUser({
      token: tokenA,
      birthDate: '1996-06-10',
      gender: 'Male',
      searchGender: 'women',
      latitude: 25.033,
      longitude: 121.5654,
    });

    await setupUser({
      token: tokenB,
      birthDate: '1997-08-14',
      gender: 'Female',
      searchGender: 'men',
      latitude: 25.034,
      longitude: 121.565,
    });

    const uidA = tokenA.split(':')[2];
    const uidB = tokenB.split(':')[2];
    const userA = await prisma.users.findUnique({ where: { firebase_uid: uidA } });
    const userB = await prisma.users.findUnique({ where: { firebase_uid: uidB } });
    if (!userA || !userB) {
      throw new Error('Missing users for block test');
    }

    await prisma.user_blocks.create({
      data: {
        blocker_user_id: userA.id,
        blocked_user_id: userB.id,
        reason: 'test block',
      },
    });

    await request(app)
      .post('/api/v1/matching/queue/join')
      .set('Authorization', `Bearer ${tokenA}`);

    const response = await request(app)
      .post('/api/v1/matching/queue/join')
      .set('Authorization', `Bearer ${tokenB}`);

    expect(response.status).toBe(200);
    expect(response.body.data.state).toBe('waiting');

    const sessions = await prisma.speed_dating_sessions.findMany();
    expect(sessions).toHaveLength(0);
  });
});
