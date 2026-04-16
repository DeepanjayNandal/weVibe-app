import request from 'supertest';
import { PrismaClient } from '@prisma/client';
import { createApp } from '../src/app';

const prisma = new PrismaClient();
const app = createApp();

describe('FCM Token — PATCH /api/v1/users/fcm-token', () => {
  beforeAll(async () => {
    await prisma.$connect();
  });

  beforeEach(async () => {
    await prisma.$executeRaw`DELETE FROM users WHERE email LIKE '%@fcm.test'`;
  });

  afterAll(async () => {
    await prisma.$disconnect();
  });

  test('returns 200 and stores the token in the database', async () => {
    await request(app)
      .post('/api/v1/auth/register')
      .send({ provider: 'email', idToken: 'mock:email:fcm-001:user1@fcm.test' });

    const res = await request(app)
      .patch('/api/v1/users/fcm-token')
      .set('Authorization', 'Bearer mock:email:fcm-001:user1@fcm.test')
      .send({ fcmToken: 'device-token-abc123' });

    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);

    const user = await prisma.users.findUnique({ where: { email: 'user1@fcm.test' } });
    expect(user?.fcm_token).toBe('device-token-abc123');
  });

  test('overwrites an existing FCM token on second call', async () => {
    await request(app)
      .post('/api/v1/auth/register')
      .send({ provider: 'email', idToken: 'mock:email:fcm-002:user2@fcm.test' });

    await request(app)
      .patch('/api/v1/users/fcm-token')
      .set('Authorization', 'Bearer mock:email:fcm-002:user2@fcm.test')
      .send({ fcmToken: 'old-token' });

    await request(app)
      .patch('/api/v1/users/fcm-token')
      .set('Authorization', 'Bearer mock:email:fcm-002:user2@fcm.test')
      .send({ fcmToken: 'new-token' });

    const user = await prisma.users.findUnique({ where: { email: 'user2@fcm.test' } });
    expect(user?.fcm_token).toBe('new-token');
  });

  test('trims whitespace from the token before storing', async () => {
    await request(app)
      .post('/api/v1/auth/register')
      .send({ provider: 'email', idToken: 'mock:email:fcm-003:user3@fcm.test' });

    const res = await request(app)
      .patch('/api/v1/users/fcm-token')
      .set('Authorization', 'Bearer mock:email:fcm-003:user3@fcm.test')
      .send({ fcmToken: '  trimmed-token  ' });

    expect(res.status).toBe(200);

    const user = await prisma.users.findUnique({ where: { email: 'user3@fcm.test' } });
    expect(user?.fcm_token).toBe('trimmed-token');
  });

  test('returns 400 when fcmToken is missing', async () => {
    await request(app)
      .post('/api/v1/auth/register')
      .send({ provider: 'email', idToken: 'mock:email:fcm-004:user4@fcm.test' });

    const res = await request(app)
      .patch('/api/v1/users/fcm-token')
      .set('Authorization', 'Bearer mock:email:fcm-004:user4@fcm.test')
      .send({});

    expect(res.status).toBe(400);
    expect(res.body.success).toBe(false);
    expect(res.body.error.code).toBe('INVALID_FCM_TOKEN');
  });

  test('returns 400 when fcmToken is an empty string', async () => {
    await request(app)
      .post('/api/v1/auth/register')
      .send({ provider: 'email', idToken: 'mock:email:fcm-005:user5@fcm.test' });

    const res = await request(app)
      .patch('/api/v1/users/fcm-token')
      .set('Authorization', 'Bearer mock:email:fcm-005:user5@fcm.test')
      .send({ fcmToken: '' });

    expect(res.status).toBe(400);
    expect(res.body.error.code).toBe('INVALID_FCM_TOKEN');
  });

  test('returns 400 when fcmToken is whitespace only', async () => {
    await request(app)
      .post('/api/v1/auth/register')
      .send({ provider: 'email', idToken: 'mock:email:fcm-006:user6@fcm.test' });

    const res = await request(app)
      .patch('/api/v1/users/fcm-token')
      .set('Authorization', 'Bearer mock:email:fcm-006:user6@fcm.test')
      .send({ fcmToken: '   ' });

    expect(res.status).toBe(400);
    expect(res.body.error.code).toBe('INVALID_FCM_TOKEN');
  });

  test('returns 400 when fcmToken is not a string', async () => {
    await request(app)
      .post('/api/v1/auth/register')
      .send({ provider: 'email', idToken: 'mock:email:fcm-007:user7@fcm.test' });

    const res = await request(app)
      .patch('/api/v1/users/fcm-token')
      .set('Authorization', 'Bearer mock:email:fcm-007:user7@fcm.test')
      .send({ fcmToken: 12345 });

    expect(res.status).toBe(400);
    expect(res.body.error.code).toBe('INVALID_FCM_TOKEN');
  });

  test('returns 401 without Authorization header', async () => {
    const res = await request(app)
      .patch('/api/v1/users/fcm-token')
      .send({ fcmToken: 'some-token' });

    expect(res.status).toBe(401);
    expect(res.body.error.code).toBe('MISSING_BEARER_TOKEN');
  });

  test('returns 401 with invalid token', async () => {
    const res = await request(app)
      .patch('/api/v1/users/fcm-token')
      .set('Authorization', 'Bearer not-a-valid-mock-token')
      .send({ fcmToken: 'some-token' });

    expect(res.status).toBe(401);
  });
});
