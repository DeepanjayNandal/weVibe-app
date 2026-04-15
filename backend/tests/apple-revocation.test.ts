import request from 'supertest';
import { PrismaClient } from '@prisma/client';
import { createApp } from '../src/app';
import { exchangeAppleCode, revokeAppleToken } from '../src/services/apple-auth-service';

const prisma = new PrismaClient();
const app = createApp();

describe('Apple Sign-In — auth code passthrough on login', () => {
  beforeAll(async () => {
    await prisma.$connect();
  });

  beforeEach(async () => {
    await prisma.$executeRaw`DELETE FROM users WHERE email LIKE '%@apple.test'`;
  });

  afterAll(async () => {
    await prisma.$disconnect();
  });

  test('login with apple provider succeeds without appleAuthCode (backward compat)', async () => {
    const res = await request(app)
      .post('/api/v1/auth/login')
      .send({
        provider: 'apple',
        idToken: 'mock:apple:a-login-001:user1@apple.test',
      });

    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
    expect(res.body.data.user.authProvider).toBe('apple');
  });

  test('login with apple provider + appleAuthCode returns 200 (code exchange is fire-and-forget)', async () => {
    // In test env, Apple credentials are not configured so exchangeAppleCode is a no-op.
    // This verifies the endpoint accepts the fields without error.
    const res = await request(app)
      .post('/api/v1/auth/login')
      .send({
        provider: 'apple',
        idToken: 'mock:apple:a-login-002:user2@apple.test',
        appleAuthCode: 'c7a8f2b3.some-one-time-code',
        appleBundleId: 'com.wevibe1.app',
      });

    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
  });

  test('login with apple + appleAuthCode does not store refresh token when Apple credentials are absent', async () => {
    // Apple env vars are not set in test environment — exchangeAppleCode returns null
    await request(app)
      .post('/api/v1/auth/login')
      .send({
        provider: 'apple',
        idToken: 'mock:apple:a-login-003:user3@apple.test',
        appleAuthCode: 'c7a8f2b3.some-one-time-code',
        appleBundleId: 'com.wevibe1.app',
      });

    // Give fire-and-forget time to settle
    await new Promise((r) => setTimeout(r, 100));

    const user = await prisma.users.findUnique({ where: { email: 'user3@apple.test' } });
    expect(user?.apple_refresh_token).toBeNull();
  });
});

describe('Apple Sign-In — account deletion with Apple provider', () => {
  beforeAll(async () => {
    await prisma.$connect();
  });

  beforeEach(async () => {
    await prisma.$executeRaw`DELETE FROM users WHERE email LIKE '%@apple-delete.test'`;
  });

  afterAll(async () => {
    await prisma.$disconnect();
  });

  test('DELETE /users/me succeeds for Apple user without stored refresh token', async () => {
    await request(app)
      .post('/api/v1/auth/register')
      .send({ provider: 'apple', idToken: 'mock:apple:a-del-001:del1@apple-delete.test' });

    const res = await request(app)
      .delete('/api/v1/users/me')
      .set('Authorization', 'Bearer mock:apple:a-del-001:del1@apple-delete.test');

    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);

    const user = await prisma.users.findUnique({ where: { email: 'del1@apple-delete.test' } });
    expect(user?.deleted_at).not.toBeNull();
  });

  test('DELETE /users/me succeeds for Apple user even when stored refresh token revocation is a no-op', async () => {
    await request(app)
      .post('/api/v1/auth/register')
      .send({ provider: 'apple', idToken: 'mock:apple:a-del-002:del2@apple-delete.test' });

    // Manually plant a fake refresh token to trigger the revocation path
    await prisma.users.updateMany({
      where: { email: 'del2@apple-delete.test' },
      data: { apple_refresh_token: 'fake-refresh-token-for-test' },
    });

    const res = await request(app)
      .delete('/api/v1/users/me')
      .set('Authorization', 'Bearer mock:apple:a-del-002:del2@apple-delete.test');

    // Deletion must succeed even though Apple credentials are absent and revocation is a no-op
    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);

    const user = await prisma.users.findUnique({ where: { email: 'del2@apple-delete.test' } });
    expect(user?.deleted_at).not.toBeNull();
  });
});

describe('apple-auth-service unit tests', () => {
  test('exchangeAppleCode returns null when Apple credentials are not configured', async () => {
    // In test environment APPLE_TEAM_ID / APPLE_KEY_ID / APPLE_PRIVATE_KEY are unset
    const result = await exchangeAppleCode('any-auth-code', 'com.wevibe1.app');
    expect(result).toBeNull();
  });

  test('revokeAppleToken is a no-op when Apple credentials are not configured', async () => {
    // Should resolve without throwing
    await expect(
      revokeAppleToken('any-refresh-token', 'com.wevibe1.app'),
    ).resolves.toBeUndefined();
  });
});
