import request from 'supertest';
import { PrismaClient } from '@prisma/client';
import { createApp } from '../src/app';

const prisma = new PrismaClient();

const app = createApp();

describe('Auth API', () => {
  beforeAll(async () => {
    await prisma.$connect();
  });

  beforeEach(async () => {
    await prisma.$executeRaw`DELETE FROM users WHERE email LIKE '%@auth.test'`;
  });

  afterAll(async () => {
    await prisma.$disconnect();
  });

  test('POST /api/v1/auth/register should register a new user', async () => {
    const response = await request(app)
      .post('/api/v1/auth/register')
      .send({
        provider: 'google',
        idToken: 'mock:google:g-001:alice@auth.test',
      });

    expect(response.status).toBe(201);
    expect(response.body.success).toBe(true);
    expect(response.body.data.user.email).toBe('alice@auth.test');
    expect(response.body.data.user.firebaseUid).toBe('g-001');
    expect(response.body.data.user.authProvider).toBe('google');
  });

  test('POST /api/v1/auth/register should return 409 if user exists', async () => {
    await request(app)
      .post('/api/v1/auth/register')
      .send({
        provider: 'google',
        idToken: 'mock:google:g-001:alice@auth.test',
      });

    const response = await request(app)
      .post('/api/v1/auth/register')
      .send({
        provider: 'google',
        idToken: 'mock:google:g-001:alice@auth.test',
      });

    expect(response.status).toBe(409);
    expect(response.body.success).toBe(false);
    expect(response.body.error.code).toBe('USER_ALREADY_EXISTS');
  });

  test('POST /api/v1/auth/login should create user on first social login', async () => {
    const response = await request(app)
      .post('/api/v1/auth/login')
      .send({
        provider: 'apple',
        idToken: 'mock:apple:a-001:bob@auth.test',
      });

    expect(response.status).toBe(200);
    expect(response.body.success).toBe(true);
    expect(response.body.data.user.email).toBe('bob@auth.test');
    expect(response.body.data.user.authProvider).toBe('apple');
  });

  test('GET /api/v1/auth/me should return current user with bearer token', async () => {
    await request(app)
      .post('/api/v1/auth/register')
      .send({
        provider: 'email',
        idToken: 'mock:email:e-001:charlie@auth.test',
      });

    const response = await request(app)
      .get('/api/v1/auth/me')
      .set('Authorization', 'Bearer mock:email:e-001:charlie@auth.test');

    expect(response.status).toBe(200);
    expect(response.body.success).toBe(true);
    expect(response.body.data.user.email).toBe('charlie@auth.test');
  });

  test('POST /api/v1/auth/logout should return 204', async () => {
    const response = await request(app)
      .post('/api/v1/auth/logout')
      .set('Authorization', 'Bearer mock:google:g-logout:user@gmail.com');

    expect(response.status).toBe(204);
  });

  test('DELETE /api/v1/auth/me should delete the account and related records', async () => {
    const token = 'mock:google:g-delete:delete@auth.test';
    const counterpartToken = 'mock:apple:a-delete:counterpart@auth.test';

    const registerResponse = await request(app)
      .post('/api/v1/auth/register')
      .send({
        provider: 'google',
        idToken: token,
      });

    const userId = registerResponse.body.data.user.id;

    const counterpartResponse = await request(app)
      .post('/api/v1/auth/register')
      .send({
        provider: 'apple',
        idToken: counterpartToken,
      });

    const counterpartUserId = counterpartResponse.body.data.user.id;

    await prisma.$executeRaw`
      INSERT INTO profiles (user_id)
      VALUES (CAST(${userId} AS uuid))
    `;

    await prisma.$executeRaw`
      INSERT INTO profiles (user_id)
      VALUES (CAST(${counterpartUserId} AS uuid))
    `;

    const match = await prisma.matches.create({
      data: {
        user_a_id: userId,
        user_b_id: counterpartUserId,
        status: 'active',
      },
    });

    const message = await prisma.messages.create({
      data: {
        match_id: match.id,
        sender_id: userId,
        content: 'hello there',
      },
    });

    const queueJoinResponse = await request(app)
      .post('/api/v1/matching/queue/join')
      .set('Authorization', `Bearer ${token}`);

    expect(queueJoinResponse.status).toBe(200);

    expect(await prisma.matching_queue.findUnique({ where: { user_id: userId } })).not.toBeNull();

    const deleteResponse = await request(app)
      .delete('/api/v1/auth/me')
      .set('Authorization', `Bearer ${token}`);

    expect(deleteResponse.status).toBe(204);

    expect(await prisma.users.findUnique({ where: { id: userId } })).toBeNull();
    expect(await prisma.profiles.findUnique({ where: { user_id: userId } })).toBeNull();
    expect(await prisma.matching_queue.findUnique({ where: { user_id: userId } })).toBeNull();
    expect(await prisma.matches.findUnique({ where: { id: match.id } })).toBeNull();
    expect(await prisma.messages.findUnique({ where: { id: message.id } })).toBeNull();
    expect(await prisma.users.findUnique({ where: { id: counterpartUserId } })).not.toBeNull();

    const meAfterDelete = await request(app)
      .get('/api/v1/auth/me')
      .set('Authorization', `Bearer ${token}`);

    expect(meAfterDelete.status).toBe(401);
    expect(meAfterDelete.body.error.code).toBe('USER_NOT_FOUND');
  });

  test('GET /api/v1/auth/me should return 401 without bearer token', async () => {
    const response = await request(app).get('/api/v1/auth/me');

    expect(response.status).toBe(401);
    expect(response.body.success).toBe(false);
    expect(response.body.error.code).toBe('MISSING_BEARER_TOKEN');
  });

  test('POST /api/v1/auth/register should return 400 for invalid provider', async () => {
    const response = await request(app)
      .post('/api/v1/auth/register')
      .send({
        provider: 'linkedin',
        idToken: 'mock:linkedin:l-001:user@auth.test',
      });

    expect(response.status).toBe(400);
    expect(response.body.success).toBe(false);
    expect(response.body.error.code).toBe('INVALID_PROVIDER');
  });

  test('POST /api/v1/auth/register should return 400 for missing idToken', async () => {
    const response = await request(app)
      .post('/api/v1/auth/register')
      .send({
        provider: 'google',
      });

    expect(response.status).toBe(400);
    expect(response.body.success).toBe(false);
    expect(response.body.error.code).toBe('MISSING_ID_TOKEN');
  });

  test('POST /api/v1/auth/register should return 400 for empty idToken', async () => {
    const response = await request(app)
      .post('/api/v1/auth/register')
      .send({
        provider: 'google',
        idToken: '   ',
      });

    expect(response.status).toBe(400);
    expect(response.body.success).toBe(false);
    expect(response.body.error.code).toBe('MISSING_ID_TOKEN');
  });

  test('GET /api/v1/auth/me should return 401 for invalid token format', async () => {
    const response = await request(app)
      .get('/api/v1/auth/me')
      .set('Authorization', 'Bearer invalid-token-format');

    expect(response.status).toBe(401);
    expect(response.body.success).toBe(false);
    expect(response.body.error.code).toBe('INVALID_ID_TOKEN');
  });

  test('POST /api/v1/auth/register should return 409 for duplicate email with different provider', async () => {
    await request(app)
      .post('/api/v1/auth/register')
      .send({
        provider: 'google',
        idToken: 'mock:google:g-001:duplicate@auth.test',
      });

    const response = await request(app)
      .post('/api/v1/auth/register')
      .send({
        provider: 'apple',
        idToken: 'mock:apple:a-001:duplicate@auth.test',
      });

    expect(response.status).toBe(409);
    expect(response.body.success).toBe(false);
    expect(response.body.error.code).toBe('EMAIL_ALREADY_EXISTS');
  });

  test('GET /api/v1/auth/me should return 401 without Authorization header', async () => {
    const response = await request(app)
      .get('/api/v1/auth/me')
      .set('Authorization', '');

    expect(response.status).toBe(401);
    expect(response.body.error.code).toBe('MISSING_BEARER_TOKEN');
  });

  test('GET /api/v1/auth/me should return 401 with malformed Authorization header', async () => {
    const response = await request(app)
      .get('/api/v1/auth/me')
      .set('Authorization', 'Basic some-token');

    expect(response.status).toBe(401);
    expect(response.body.error.code).toBe('MISSING_BEARER_TOKEN');
  });

  test('POST /api/v1/auth/login should return 200 for existing user', async () => {
    await request(app)
      .post('/api/v1/auth/register')
      .send({
        provider: 'google',
        idToken: 'mock:google:g-login:login@auth.test',
      });

    const response = await request(app)
      .post('/api/v1/auth/login')
      .send({
        provider: 'google',
        idToken: 'mock:google:g-login:login@auth.test',
      });

    expect(response.status).toBe(200);
    expect(response.body.success).toBe(true);
    expect(response.body.data.user.email).toBe('login@auth.test');
  });

  test('POST /api/v1/auth/login should return 400 for invalid provider', async () => {
    const response = await request(app)
      .post('/api/v1/auth/login')
      .send({
        provider: 'linkedin',
        idToken: 'mock:linkedin:l-001:user@auth.test',
      });

    expect(response.status).toBe(400);
    expect(response.body.error.code).toBe('INVALID_PROVIDER');
  });

  test('POST /api/v1/auth/logout should return 401 with invalid token', async () => {
    const response = await request(app)
      .post('/api/v1/auth/logout')
      .set('Authorization', 'Bearer invalid-token');

    expect(response.status).toBe(401);
    expect(response.body.error.code).toBe('INVALID_ID_TOKEN');
  });
});
