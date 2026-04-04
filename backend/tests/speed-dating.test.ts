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

async function forceAwaitingDecision(sessionId: string): Promise<void> {
  await prisma.speed_dating_sessions.update({
    where: { id: sessionId },
    data: {
      status: 'awaiting_decision',
      user_a_decision: 'pending',
      user_b_decision: 'pending',
    },
  });
}

async function getUserIdFromToken(token: string): Promise<string> {
  const uid = token.split(':')[2];
  const user = await prisma.users.findUnique({ where: { firebase_uid: uid } });
  if (!user) {
    throw new Error('User not found');
  }
  return user.id;
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

  test('lists active sessions with minimal reconnect payload', async () => {
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
    expect(session.sessionExpiresAt).toBeTruthy();
    expect(Object.keys(session).sort()).toEqual(
      ['sessionExpiresAt', 'sessionId', 'status'].sort(),
    );
  });

  test('supports early move-to-permanent acceptance and copies speed dating history into permanent chat', async () => {
    const tokenA = 'mock:google:sd-a-early-001:sd-a-early-001@speed-dating.test';
    const tokenB = 'mock:google:sd-b-early-001:sd-b-early-001@speed-dating.test';

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

    await request(app)
      .post(`/api/v1/matching/sessions/${sessionId}/messages`)
      .set('Authorization', `Bearer ${tokenB}`)
      .send({ content: 'hello from B' });

    const requestResponse = await request(app)
      .post(`/api/v1/matching/sessions/${sessionId}/move-to-permanent/request`)
      .set('Authorization', `Bearer ${tokenA}`);

    expect(requestResponse.status).toBe(200);
    expect(requestResponse.body.data.session.moveToPermanent.requestStatus).toBe('sent');

    const acceptResponse = await request(app)
      .post(`/api/v1/matching/sessions/${sessionId}/move-to-permanent/respond`)
      .set('Authorization', `Bearer ${tokenB}`)
      .send({ accept: true });

    expect(acceptResponse.status).toBe(200);
    expect(acceptResponse.body.data.session.status).toBe('graduated');
    expect(acceptResponse.body.data.match).not.toBeNull();

    const matchId = acceptResponse.body.data.match.matchId as string;
    const permanentMessages = await request(app)
      .get(`/api/v1/matching/matches/${matchId}/messages`)
      .set('Authorization', `Bearer ${tokenA}`);

    expect(permanentMessages.status).toBe(200);
    expect(permanentMessages.body.data.messages).toHaveLength(2);
    expect(permanentMessages.body.data.messages[0].content).toBe('hello from A');
    expect(permanentMessages.body.data.messages[1].content).toBe('hello from B');
  });

  test('flips move-to-permanent request rights after decline and locks further re-requests after a second decline', async () => {
    const tokenA = 'mock:google:sd-a-early-002:sd-a-early-002@speed-dating.test';
    const tokenB = 'mock:google:sd-b-early-002:sd-b-early-002@speed-dating.test';

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
      .post(`/api/v1/matching/sessions/${sessionId}/move-to-permanent/request`)
      .set('Authorization', `Bearer ${tokenA}`);

    const declineResponse = await request(app)
      .post(`/api/v1/matching/sessions/${sessionId}/move-to-permanent/respond`)
      .set('Authorization', `Bearer ${tokenB}`)
      .send({ accept: false });

    expect(declineResponse.status).toBe(200);
    expect(declineResponse.body.data.session.moveToPermanent.canRequest).toBe(true);
    expect(declineResponse.body.data.session.moveToPermanent.requestStatus).toBe('counter_available');

    const blockedRetry = await request(app)
      .post(`/api/v1/matching/sessions/${sessionId}/move-to-permanent/request`)
      .set('Authorization', `Bearer ${tokenA}`);

    expect(blockedRetry.status).toBe(400);
    expect(blockedRetry.body.error.code).toBe('MOVE_TO_PERMANENT_NOT_ALLOWED');

    const counterRequest = await request(app)
      .post(`/api/v1/matching/sessions/${sessionId}/move-to-permanent/request`)
      .set('Authorization', `Bearer ${tokenB}`);

    expect(counterRequest.status).toBe(200);
    expect(counterRequest.body.data.session.moveToPermanent.requestStatus).toBe('sent');

    const secondDecline = await request(app)
      .post(`/api/v1/matching/sessions/${sessionId}/move-to-permanent/respond`)
      .set('Authorization', `Bearer ${tokenA}`)
      .send({ accept: false });

    expect(secondDecline.status).toBe(200);
    expect(secondDecline.body.data.session.moveToPermanent.requestStatus).toBe('locked');
    expect(secondDecline.body.data.session.canSendMessage).toBe(true);

    const lockedRetry = await request(app)
      .post(`/api/v1/matching/sessions/${sessionId}/move-to-permanent/request`)
      .set('Authorization', `Bearer ${tokenB}`);

    expect(lockedRetry.status).toBe(400);
    expect(lockedRetry.body.error.code).toBe('MOVE_TO_PERMANENT_NOT_ALLOWED');

    const sendMessage = await request(app)
      .post(`/api/v1/matching/sessions/${sessionId}/messages`)
      .set('Authorization', `Bearer ${tokenA}`)
      .send({ content: 'still chatting' });

    expect(sendMessage.status).toBe(201);
  });

  test('supports final decision graduation after the session reaches awaiting_decision', async () => {
    const tokenA = 'mock:google:sd-a-final-001:sd-a-final-001@speed-dating.test';
    const tokenB = 'mock:google:sd-b-final-001:sd-b-final-001@speed-dating.test';

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
    await forceAwaitingDecision(sessionId);

    const firstDecision = await request(app)
      .post(`/api/v1/matching/sessions/${sessionId}/final-decision`)
      .set('Authorization', `Bearer ${tokenA}`)
      .send({ decision: 'yes' });

    expect(firstDecision.status).toBe(200);
    expect(firstDecision.body.data.session.status).toBe('awaiting_decision');
    expect(firstDecision.body.data.match).toBeNull();

    const secondDecision = await request(app)
      .post(`/api/v1/matching/sessions/${sessionId}/final-decision`)
      .set('Authorization', `Bearer ${tokenB}`)
      .send({ decision: 'yes' });

    expect(secondDecision.status).toBe(200);
    expect(secondDecision.body.data.session.status).toBe('graduated');
    expect(secondDecision.body.data.match).not.toBeNull();
  });

  test('allows initial move-to-permanent request in awaiting_decision state', async () => {
    const tokenA = 'mock:google:sd-a-awaiting-001:sd-a-awaiting-001@speed-dating.test';
    const tokenB = 'mock:google:sd-b-awaiting-001:sd-b-awaiting-001@speed-dating.test';

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
    await forceAwaitingDecision(sessionId);

    const requestResponse = await request(app)
      .post(`/api/v1/matching/sessions/${sessionId}/move-to-permanent/request`)
      .set('Authorization', `Bearer ${tokenA}`);

    expect(requestResponse.status).toBe(200);
    expect(requestResponse.body.data.session.status).toBe('awaiting_decision');
    expect(requestResponse.body.data.session.moveToPermanent.requestStatus).toBe('sent');

    const detailForB = await request(app)
      .get(`/api/v1/matching/sessions/${sessionId}`)
      .set('Authorization', `Bearer ${tokenB}`);

    expect(detailForB.status).toBe(200);
    expect(detailForB.body.data.session.moveToPermanent.requestStatus).toBe('received');
    expect(detailForB.body.data.session.moveToPermanent.canRespond).toBe(true);
  });

  test('lists only active sessions', async () => {
    const tokenA = 'mock:google:sd-a-grace-001:sd-a-grace-001@speed-dating.test';
    const tokenB = 'mock:google:sd-b-grace-001:sd-b-grace-001@speed-dating.test';

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

    const userAId = await getUserIdFromToken(tokenA);
    const userBId = await getUserIdFromToken(tokenB);

    await prisma.speed_dating_sessions.create({
      data: {
        user_a_id: userAId,
        user_b_id: userBId,
        started_at: new Date(),
        expires_at: new Date(Date.now() + 60 * 60 * 1000),
        status: 'active',
      },
    });

    await prisma.speed_dating_sessions.create({
      data: {
        user_a_id: userAId,
        user_b_id: userBId,
        started_at: new Date(Date.now() - 2 * 60 * 60 * 1000),
        expires_at: new Date(Date.now() - 60 * 60 * 1000),
        status: 'expired',
      },
    });

    await prisma.speed_dating_sessions.create({
      data: {
        user_a_id: userAId,
        user_b_id: userBId,
        started_at: new Date(Date.now() - 60 * 60 * 1000),
        expires_at: new Date(Date.now() - 49 * 60 * 60 * 1000),
        status: 'expired',
      },
    });

    await prisma.speed_dating_sessions.create({
      data: {
        user_a_id: userAId,
        user_b_id: userBId,
        started_at: new Date(),
        expires_at: new Date(Date.now() + 60 * 60 * 1000),
        status: 'archived',
      },
    });

    const response = await request(app)
      .get('/api/v1/matching/sessions')
      .set('Authorization', `Bearer ${tokenA}`);

    expect(response.status).toBe(200);
    expect(response.body.data.sessions).toHaveLength(1);

    const statuses = response.body.data.sessions.map((item: { status: string }) => item.status).sort();
    expect(statuses).toEqual(['active']);
  });

  test('updates speed dating unread state and returns aggregated badge counts', async () => {
    const tokenA = 'mock:google:sd-a-unread-001:sd-a-unread-001@speed-dating.test';
    const tokenB = 'mock:google:sd-b-unread-001:sd-b-unread-001@speed-dating.test';

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
      .send({ content: 'unread message' });

    const listBeforeRead = await request(app)
      .get('/api/v1/matching/sessions')
      .set('Authorization', `Bearer ${tokenB}`);

    expect(listBeforeRead.status).toBe(200);
    expect(listBeforeRead.body.data.sessions[0].status).toBe('active');

    const badgesBeforeRead = await request(app)
      .get('/api/v1/matching/chats/badges')
      .set('Authorization', `Bearer ${tokenB}`);

    expect(badgesBeforeRead.status).toBe(200);
    expect(badgesBeforeRead.body.data.speedDatingUnread).toBe(1);
    expect(badgesBeforeRead.body.data.totalUnread).toBeGreaterThanOrEqual(1);

    const detailBeforeRead = await request(app)
      .get(`/api/v1/matching/sessions/${sessionId}`)
      .set('Authorization', `Bearer ${tokenB}`);

    expect(detailBeforeRead.status).toBe(200);
    expect(detailBeforeRead.body.data.session.unreadCount).toBe(1);

    const messagesResponse = await request(app)
      .get(`/api/v1/matching/sessions/${sessionId}/messages`)
      .set('Authorization', `Bearer ${tokenB}`);

    expect(messagesResponse.status).toBe(200);
    expect(messagesResponse.body.data.messages[0].readAt).toBeNull();

    const markReadResponse = await request(app)
      .patch(`/api/v1/matching/sessions/${sessionId}/read`)
      .set('Authorization', `Bearer ${tokenB}`);

    expect(markReadResponse.status).toBe(200);
    expect(markReadResponse.body.data.session.unreadCount).toBe(0);

    const messagesAfterRead = await request(app)
      .get(`/api/v1/matching/sessions/${sessionId}/messages`)
      .set('Authorization', `Bearer ${tokenB}`);

    expect(messagesAfterRead.status).toBe(200);
    expect(messagesAfterRead.body.data.messages[0].readAt).toBeTruthy();

    const badgesAfterRead = await request(app)
      .get('/api/v1/matching/chats/badges')
      .set('Authorization', `Bearer ${tokenB}`);

    expect(badgesAfterRead.status).toBe(200);
    expect(badgesAfterRead.body.data.speedDatingUnread).toBe(0);

    const detailAfterRead = await request(app)
      .get(`/api/v1/matching/sessions/${sessionId}`)
      .set('Authorization', `Bearer ${tokenB}`);

    expect(detailAfterRead.status).toBe(200);
    expect(detailAfterRead.body.data.session.unreadCount).toBe(0);
  });

  test('archives the session when both final decisions are no', async () => {
    const tokenA = 'mock:google:sd-a-final-002:sd-a-final-002@speed-dating.test';
    const tokenB = 'mock:google:sd-b-final-002:sd-b-final-002@speed-dating.test';

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
    await forceAwaitingDecision(sessionId);

    await request(app)
      .post(`/api/v1/matching/sessions/${sessionId}/final-decision`)
      .set('Authorization', `Bearer ${tokenA}`)
      .send({ decision: 'no' });

    const secondDecision = await request(app)
      .post(`/api/v1/matching/sessions/${sessionId}/final-decision`)
      .set('Authorization', `Bearer ${tokenB}`)
      .send({ decision: 'no' });

    expect(secondDecision.status).toBe(200);
    expect(secondDecision.body.data.session.status).toBe('archived');
    expect(secondDecision.body.data.match).toBeNull();
  });

  test('ends a session early and blocks further messaging', async () => {
    const tokenA = 'mock:google:sd-a-end-001:sd-a-end-001@speed-dating.test';
    const tokenB = 'mock:google:sd-b-end-001:sd-b-end-001@speed-dating.test';

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

    const endResponse = await request(app)
      .post(`/api/v1/matching/sessions/${sessionId}/end`)
      .set('Authorization', `Bearer ${tokenA}`);

    expect(endResponse.status).toBe(200);
    expect(endResponse.body.data.session.status).toBe('ended_early');
    expect(endResponse.body.data.session.canSendMessage).toBe(false);

    const sendAfterEnd = await request(app)
      .post(`/api/v1/matching/sessions/${sessionId}/messages`)
      .set('Authorization', `Bearer ${tokenB}`)
      .send({ content: 'should fail' });

    expect(sendAfterEnd.status).toBe(400);
    expect(sendAfterEnd.body.error.code).toBe('SESSION_NOT_ACTIVE');
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
