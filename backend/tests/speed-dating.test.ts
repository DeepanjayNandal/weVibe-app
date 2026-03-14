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

async function createMatchedSession(tokenA: string, tokenB: string): Promise<string> {
  await request(app)
    .post('/api/v1/matching/queue/join')
    .set('Authorization', `Bearer ${tokenA}`);

  const response = await request(app)
    .post('/api/v1/matching/queue/join')
    .set('Authorization', `Bearer ${tokenB}`);

  expect(response.status).toBe(200);
  expect(response.body.data.state).toBe('matched');

  return response.body.data.sessionId as string;
}

describe('Speed Dating API', () => {
  beforeAll(async () => {
    await prisma.$connect();
  });

  beforeEach(async () => {
    await prisma.$executeRaw`DELETE FROM speed_dating_messages`;
    await prisma.$executeRaw`DELETE FROM speed_dating_sessions`;
    await prisma.$executeRaw`DELETE FROM matching_queue`;
    await prisma.$executeRaw`DELETE FROM user_blocks`;
    await prisma.$executeRaw`DELETE FROM matches`;
    await prisma.$executeRaw`DELETE FROM messages`;
    await prisma.$executeRaw`DELETE FROM profiles WHERE user_id IN (SELECT id FROM users WHERE email LIKE '%@speed-dating.test')`;
    await prisma.$executeRaw`DELETE FROM users WHERE email LIKE '%@speed-dating.test'`;
  });

  afterAll(async () => {
    await prisma.$disconnect();
  });

  test('enforces per-user 20 message limit and flips to awaiting_decision after both hit limit', async () => {
    const tokenA = 'mock:google:sd-a-001:sd-a-001@speed-dating.test';
    const tokenB = 'mock:google:sd-b-001:sd-b-001@speed-dating.test';

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

    const sessionId = await createMatchedSession(tokenA, tokenB);

    for (let i = 0; i < 20; i++) {
      const response = await request(app)
        .post(`/api/v1/matching/sessions/${sessionId}/messages`)
        .set('Authorization', `Bearer ${tokenA}`)
        .send({ content: `A-${i + 1}` });

      expect(response.status).toBe(201);
      expect(response.body.data.session.myMessageCount).toBe(i + 1);
    }

    const overLimit = await request(app)
      .post(`/api/v1/matching/sessions/${sessionId}/messages`)
      .set('Authorization', `Bearer ${tokenA}`)
      .send({ content: 'A-21' });

    expect(overLimit.status).toBe(400);
    expect(overLimit.body.error.code).toBe('MESSAGE_LIMIT_REACHED');

    for (let i = 0; i < 20; i++) {
      const response = await request(app)
        .post(`/api/v1/matching/sessions/${sessionId}/messages`)
        .set('Authorization', `Bearer ${tokenB}`)
        .send({ content: `B-${i + 1}` });

      expect(response.status).toBe(201);
    }

    const detail = await request(app)
      .get(`/api/v1/matching/sessions/${sessionId}`)
      .set('Authorization', `Bearer ${tokenA}`);

    expect(detail.status).toBe(200);
    expect(detail.body.data.session.status).toBe('awaiting_decision');
    expect(detail.body.data.session.myMessageCount).toBe(20);
    expect(detail.body.data.session.otherMessageCount).toBe(20);
    expect(detail.body.data.session.canSendMessage).toBe(false);
  });

  test('lists sessions with message progress and anonymized counterpart summary', async () => {
    const tokenA = 'mock:google:sd-a-002:sd-a-002@speed-dating.test';
    const tokenB = 'mock:google:sd-b-002:sd-b-002@speed-dating.test';

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

    const sessionId = await createMatchedSession(tokenA, tokenB);

    await request(app)
      .post(`/api/v1/matching/sessions/${sessionId}/messages`)
      .set('Authorization', `Bearer ${tokenA}`)
      .send({ content: 'hello from A' });

    const response = await request(app)
      .get('/api/v1/matching/sessions')
      .set('Authorization', `Bearer ${tokenB}`);

    expect(response.status).toBe(200);
    expect(Array.isArray(response.body.data.sessions)).toBe(true);
    expect(response.body.data.sessions.length).toBeGreaterThan(0);

    const session = response.body.data.sessions[0];
    expect(session.sessionId).toBe(sessionId);
    expect(session.status).toBe('active');
    expect(session.myMessageCount).toBe(0);
    expect(session.otherMessageCount).toBe(1);
    expect(session.messageLimit).toBe(20);
    expect(session.canOpen).toBe(true);
    expect(session.canSendMessage).toBe(true);
    expect(session.remainingSeconds).toBeGreaterThan(0);
    expect(session.counterpart.firstName).toBeTruthy();
    expect(session.counterpart.initials).toBeTruthy();
  });

  test('auto-expires old sessions and blocks messaging', async () => {
    const tokenA = 'mock:google:sd-a-003:sd-a-003@speed-dating.test';
    const tokenB = 'mock:google:sd-b-003:sd-b-003@speed-dating.test';

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

    const sessionId = await createMatchedSession(tokenA, tokenB);

    await prisma.speed_dating_sessions.update({
      where: { id: sessionId },
      data: {
        status: 'active',
        expires_at: new Date(Date.now() - 60 * 1000),
      },
    });

    const detail = await request(app)
      .get(`/api/v1/matching/sessions/${sessionId}`)
      .set('Authorization', `Bearer ${tokenA}`);

    expect(detail.status).toBe(200);
    expect(detail.body.data.session.status).toBe('expired');
    expect(detail.body.data.session.canSendMessage).toBe(false);

    const send = await request(app)
      .post(`/api/v1/matching/sessions/${sessionId}/messages`)
      .set('Authorization', `Bearer ${tokenA}`)
      .send({ content: 'should fail' });

    expect(send.status).toBe(400);
    expect(send.body.error.code).toBe('SESSION_NOT_ACTIVE');
  });
});
