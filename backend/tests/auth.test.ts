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
