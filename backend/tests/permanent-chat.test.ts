import request from 'supertest';
import { PrismaClient, enum_meet_gender, enum_match_status } from '@prisma/client';
import { createApp } from '../src/app';

const prisma = new PrismaClient();
const app = createApp();

type TestUserSetup = {
  token: string;
  birthDate: string;
  gender: string;
  searchGender: enum_meet_gender;
  latitude: number;
  longitude: number;
};

async function registerUser(token: string): Promise<void> {
  await request(app)
    .post('/api/v1/auth/register')
    .send({ provider: 'google', idToken: token });
}

async function setupUser(config: TestUserSetup): Promise<{ userId: string }> {
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
      search_age_min: 18,
      search_age_max: 35,
      search_radius_km: 50,
      current_status: 'active',
    },
  });

  await prisma.profiles.upsert({
    where: { user_id: user.id },
    update: {
      display_name: uid,
      birth_date: new Date(config.birthDate),
      gender: config.gender,
      personality_primary: 'A',
    },
    create: {
      user_id: user.id,
      display_name: uid,
      birth_date: new Date(config.birthDate),
      gender: config.gender,
      personality_primary: 'A',
    },
  });

  await prisma.$executeRaw`
    UPDATE profiles
    SET location_point = ST_SetSRID(ST_MakePoint(${config.longitude}, ${config.latitude}), 4326)::geography
    WHERE user_id = ${user.id}::uuid
  `;

  return { userId: user.id };
}

async function createMatch(
  userAId: string,
  userBId: string,
  status: enum_match_status = 'active',
): Promise<string> {
  const row = await prisma.matches.create({
    data: {
      user_a_id: userAId,
      user_b_id: userBId,
      status,
      created_at: new Date(),
      message_count: 0,
    },
  });

  return row.id;
}

describe('Permanent Chat API', () => {
  beforeAll(async () => {
    await prisma.$connect();
  });

  beforeEach(async () => {
    await prisma.$executeRaw`DELETE FROM user_reports`;
    await prisma.$executeRaw`DELETE FROM messages`;
    await prisma.$executeRaw`DELETE FROM matches`;
    await prisma.$executeRaw`DELETE FROM speed_dating_messages`;
    await prisma.$executeRaw`DELETE FROM speed_dating_sessions`;
    await prisma.$executeRaw`DELETE FROM matching_queue`;
    await prisma.$executeRaw`DELETE FROM user_blocks`;
    await prisma.$executeRaw`DELETE FROM profiles WHERE user_id IN (SELECT id FROM users WHERE email LIKE '%@permanent-chat.test')`;
    await prisma.$executeRaw`DELETE FROM users WHERE email LIKE '%@permanent-chat.test'`;
  });

  afterAll(async () => {
    await prisma.$disconnect();
  });

  test('lists matches and supports permanent message send/read', async () => {
    const tokenA = 'mock:google:pc-a-001:pc-a-001@permanent-chat.test';
    const tokenB = 'mock:google:pc-b-001:pc-b-001@permanent-chat.test';

    const userA = await setupUser({
      token: tokenA,
      birthDate: '1996-06-10',
      gender: 'Male',
      searchGender: 'women',
      latitude: 25.033,
      longitude: 121.5654,
    });

    const userB = await setupUser({
      token: tokenB,
      birthDate: '1997-08-14',
      gender: 'Female',
      searchGender: 'men',
      latitude: 25.034,
      longitude: 121.565,
    });

    const matchId = await createMatch(userA.userId, userB.userId, 'active');

    const listResponse = await request(app)
      .get('/api/v1/matching/matches')
      .set('Authorization', `Bearer ${tokenA}`);

    expect(listResponse.status).toBe(200);
    expect(Array.isArray(listResponse.body.data.matches)).toBe(true);
    expect(listResponse.body.data.matches[0].matchId).toBe(matchId);
    expect(listResponse.body.data.matches[0].canSendMessage).toBe(true);

    const sendResponse = await request(app)
      .post(`/api/v1/matching/matches/${matchId}/messages`)
      .set('Authorization', `Bearer ${tokenA}`)
      .send({ content: 'hello permanent' });

    expect(sendResponse.status).toBe(201);
    expect(sendResponse.body.data.match.matchId).toBe(matchId);
    expect(sendResponse.body.data.match.lastMessageContent).toBe('hello permanent');
    expect(sendResponse.body.data.match.messageCount).toBe(1);

    const messagesResponse = await request(app)
      .get(`/api/v1/matching/matches/${matchId}/messages`)
      .set('Authorization', `Bearer ${tokenB}`);

    expect(messagesResponse.status).toBe(200);
    expect(messagesResponse.body.data.match.matchId).toBe(matchId);
    expect(messagesResponse.body.data.messages.length).toBe(1);
    expect(messagesResponse.body.data.messages[0].content).toBe('hello permanent');
  });

  test('blocks non-participants from accessing match messages', async () => {
    const tokenA = 'mock:google:pc-a-002:pc-a-002@permanent-chat.test';
    const tokenB = 'mock:google:pc-b-002:pc-b-002@permanent-chat.test';
    const tokenC = 'mock:google:pc-c-002:pc-c-002@permanent-chat.test';

    const userA = await setupUser({
      token: tokenA,
      birthDate: '1996-06-10',
      gender: 'Male',
      searchGender: 'women',
      latitude: 25.033,
      longitude: 121.5654,
    });

    const userB = await setupUser({
      token: tokenB,
      birthDate: '1997-08-14',
      gender: 'Female',
      searchGender: 'men',
      latitude: 25.034,
      longitude: 121.565,
    });

    await setupUser({
      token: tokenC,
      birthDate: '1997-08-14',
      gender: 'Female',
      searchGender: 'men',
      latitude: 25.034,
      longitude: 121.565,
    });

    const matchId = await createMatch(userA.userId, userB.userId, 'active');

    const response = await request(app)
      .get(`/api/v1/matching/matches/${matchId}/messages`)
      .set('Authorization', `Bearer ${tokenC}`);

    expect(response.status).toBe(403);
    expect(response.body.error.code).toBe('CHAT_FORBIDDEN');
  });

  test('blocks messaging for non-active matches', async () => {
    const tokenA = 'mock:google:pc-a-003:pc-a-003@permanent-chat.test';
    const tokenB = 'mock:google:pc-b-003:pc-b-003@permanent-chat.test';

    const userA = await setupUser({
      token: tokenA,
      birthDate: '1996-06-10',
      gender: 'Male',
      searchGender: 'women',
      latitude: 25.033,
      longitude: 121.5654,
    });

    const userB = await setupUser({
      token: tokenB,
      birthDate: '1997-08-14',
      gender: 'Female',
      searchGender: 'men',
      latitude: 25.034,
      longitude: 121.565,
    });

    const matchId = await createMatch(userA.userId, userB.userId, 'expired');

    const response = await request(app)
      .post(`/api/v1/matching/matches/${matchId}/messages`)
      .set('Authorization', `Bearer ${tokenA}`)
      .send({ content: 'should fail' });

    expect(response.status).toBe(400);
    expect(response.body.error.code).toBe('MATCH_NOT_ACTIVE');
  });

  test('updates permanent unread state and contributes to badge aggregation', async () => {
    const tokenA = 'mock:google:pc-a-unread-001:pc-a-unread-001@permanent-chat.test';
    const tokenB = 'mock:google:pc-b-unread-001:pc-b-unread-001@permanent-chat.test';

    const userA = await setupUser({
      token: tokenA,
      birthDate: '1996-06-10',
      gender: 'Male',
      searchGender: 'women',
      latitude: 25.033,
      longitude: 121.5654,
    });

    const userB = await setupUser({
      token: tokenB,
      birthDate: '1997-08-14',
      gender: 'Female',
      searchGender: 'men',
      latitude: 25.034,
      longitude: 121.565,
    });

    const matchId = await createMatch(userA.userId, userB.userId, 'active');

    await request(app)
      .post(`/api/v1/matching/matches/${matchId}/messages`)
      .set('Authorization', `Bearer ${tokenA}`)
      .send({ content: 'permanent unread' });

    const listBeforeRead = await request(app)
      .get('/api/v1/matching/matches')
      .set('Authorization', `Bearer ${tokenB}`);

    expect(listBeforeRead.status).toBe(200);
    expect(listBeforeRead.body.data.matches[0].unreadCount).toBe(1);

    const badgesBeforeRead = await request(app)
      .get('/api/v1/matching/chats/badges')
      .set('Authorization', `Bearer ${tokenB}`);

    expect(badgesBeforeRead.status).toBe(200);
    expect(badgesBeforeRead.body.data.matchesUnread).toBe(1);
    expect(badgesBeforeRead.body.data.totalUnread).toBeGreaterThanOrEqual(1);

    const detailBeforeRead = await request(app)
      .get(`/api/v1/matching/matches/${matchId}`)
      .set('Authorization', `Bearer ${tokenB}`);

    expect(detailBeforeRead.status).toBe(200);
    expect(detailBeforeRead.body.data.match.unreadCount).toBe(1);

    const messagesResponse = await request(app)
      .get(`/api/v1/matching/matches/${matchId}/messages`)
      .set('Authorization', `Bearer ${tokenB}`);

    expect(messagesResponse.status).toBe(200);
    expect(messagesResponse.body.data.messages[0].readAt).toBeNull();

    const markReadResponse = await request(app)
      .patch(`/api/v1/matching/matches/${matchId}/read`)
      .set('Authorization', `Bearer ${tokenB}`);

    expect(markReadResponse.status).toBe(200);
    expect(markReadResponse.body.data.match.unreadCount).toBe(0);

    const messagesAfterRead = await request(app)
      .get(`/api/v1/matching/matches/${matchId}/messages`)
      .set('Authorization', `Bearer ${tokenB}`);

    expect(messagesAfterRead.status).toBe(200);
    expect(messagesAfterRead.body.data.messages[0].readAt).toBeTruthy();

    const badgesAfterRead = await request(app)
      .get('/api/v1/matching/chats/badges')
      .set('Authorization', `Bearer ${tokenB}`);

    expect(badgesAfterRead.status).toBe(200);
    expect(badgesAfterRead.body.data.matchesUnread).toBe(0);

    const detailAfterRead = await request(app)
      .get(`/api/v1/matching/matches/${matchId}`)
      .set('Authorization', `Bearer ${tokenB}`);

    expect(detailAfterRead.status).toBe(200);
    expect(detailAfterRead.body.data.match.unreadCount).toBe(0);
  });

  test('removes a match and marks it as unmatched', async () => {
    const tokenA = 'mock:google:pc-a-remove-001:pc-a-remove-001@permanent-chat.test';
    const tokenB = 'mock:google:pc-b-remove-001:pc-b-remove-001@permanent-chat.test';

    const userA = await setupUser({
      token: tokenA,
      birthDate: '1996-06-10',
      gender: 'Male',
      searchGender: 'women',
      latitude: 25.033,
      longitude: 121.5654,
    });

    const userB = await setupUser({
      token: tokenB,
      birthDate: '1997-08-14',
      gender: 'Female',
      searchGender: 'men',
      latitude: 25.034,
      longitude: 121.565,
    });

    const matchId = await createMatch(userA.userId, userB.userId, 'active');

    const removeResponse = await request(app)
      .post(`/api/v1/matching/matches/${matchId}/remove`)
      .set('Authorization', `Bearer ${tokenA}`);

    expect(removeResponse.status).toBe(200);
    expect(removeResponse.body.data.match.matchId).toBe(matchId);
    expect(removeResponse.body.data.match.status).toBe('unmatched');
    expect(removeResponse.body.data.match.canSendMessage).toBe(false);
    expect(removeResponse.body.data.counterpartUserId).toBe(userB.userId);

    const dbMatch = await prisma.matches.findUnique({ where: { id: matchId } });
    expect(dbMatch?.status).toBe('unmatched');
  });

  test('blocks counterpart and creates user_blocks record', async () => {
    const tokenA = 'mock:google:pc-a-block-001:pc-a-block-001@permanent-chat.test';
    const tokenB = 'mock:google:pc-b-block-001:pc-b-block-001@permanent-chat.test';

    const userA = await setupUser({
      token: tokenA,
      birthDate: '1996-06-10',
      gender: 'Male',
      searchGender: 'women',
      latitude: 25.033,
      longitude: 121.5654,
    });

    const userB = await setupUser({
      token: tokenB,
      birthDate: '1997-08-14',
      gender: 'Female',
      searchGender: 'men',
      latitude: 25.034,
      longitude: 121.565,
    });

    const matchId = await createMatch(userA.userId, userB.userId, 'active');

    const blockResponse = await request(app)
      .post(`/api/v1/matching/matches/${matchId}/block`)
      .set('Authorization', `Bearer ${tokenA}`)
      .send({ reason: 'harassment' });

    expect(blockResponse.status).toBe(200);
    expect(blockResponse.body.data.match.status).toBe('unmatched');
    expect(blockResponse.body.data.counterpartUserId).toBe(userB.userId);
    expect(typeof blockResponse.body.data.blockId).toBe('string');

    const blockRow = await prisma.user_blocks.findUnique({
      where: {
        blocker_user_id_blocked_user_id: {
          blocker_user_id: userA.userId,
          blocked_user_id: userB.userId,
        },
      },
    });

    expect(blockRow).toBeTruthy();
    expect(blockRow?.reason).toBe('harassment');
  });

  test('reports counterpart, sets match to reported, and stores report record', async () => {
    const tokenA = 'mock:google:pc-a-report-001:pc-a-report-001@permanent-chat.test';
    const tokenB = 'mock:google:pc-b-report-001:pc-b-report-001@permanent-chat.test';

    const userA = await setupUser({
      token: tokenA,
      birthDate: '1996-06-10',
      gender: 'Male',
      searchGender: 'women',
      latitude: 25.033,
      longitude: 121.5654,
    });

    const userB = await setupUser({
      token: tokenB,
      birthDate: '1997-08-14',
      gender: 'Female',
      searchGender: 'men',
      latitude: 25.034,
      longitude: 121.565,
    });

    const matchId = await createMatch(userA.userId, userB.userId, 'active');

    const reportResponse = await request(app)
      .post(`/api/v1/matching/matches/${matchId}/report`)
      .set('Authorization', `Bearer ${tokenA}`)
      .send({ reason: 'spam', details: 'unsolicited messages' });

    expect(reportResponse.status).toBe(200);
    expect(reportResponse.body.data.match.status).toBe('reported');
    expect(reportResponse.body.data.counterpartUserId).toBe(userB.userId);
    expect(typeof reportResponse.body.data.reportId).toBe('string');

    const dbMatch = await prisma.matches.findUnique({ where: { id: matchId } });
    expect(dbMatch?.status).toBe('reported');

    const reportRow = await prisma.user_reports.findUnique({
      where: { id: reportResponse.body.data.reportId },
    });

    expect(reportRow).toBeTruthy();
    expect(reportRow?.reporter_user_id).toBe(userA.userId);
    expect(reportRow?.reported_user_id).toBe(userB.userId);
    expect(reportRow?.reason).toBe('spam');
    expect(reportRow?.details).toBe('unsolicited messages');
  });
});
