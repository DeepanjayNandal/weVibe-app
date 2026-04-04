import request from 'supertest';
import { PrismaClient } from '@prisma/client';
import { createApp } from '../src/app';

const prisma = new PrismaClient();
const app = createApp();

describe('Soft Delete — DELETE /api/v1/users/me', () => {
  beforeAll(async () => {
    await prisma.$connect();
  });

  beforeEach(async () => {
    await prisma.$executeRaw`DELETE FROM users WHERE email LIKE '%@softdelete.test'`;
  });

  afterAll(async () => {
    await prisma.$disconnect();
  });

  test('returns 200 and sets deleted_at on the user row', async () => {
    await request(app)
      .post('/api/v1/auth/register')
      .send({ provider: 'email', idToken: 'mock:email:sd-001:user@softdelete.test' });

    const res = await request(app)
      .delete('/api/v1/users/me')
      .set('Authorization', 'Bearer mock:email:sd-001:user@softdelete.test');

    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);

    const user = await prisma.users.findUnique({ where: { email: 'user@softdelete.test' } });
    expect(user?.deleted_at).not.toBeNull();
  });

  test('returns 400 when account is already deleted', async () => {
    await request(app)
      .post('/api/v1/auth/register')
      .send({ provider: 'email', idToken: 'mock:email:sd-002:user2@softdelete.test' });

    await request(app)
      .delete('/api/v1/users/me')
      .set('Authorization', 'Bearer mock:email:sd-002:user2@softdelete.test');

    const res = await request(app)
      .delete('/api/v1/users/me')
      .set('Authorization', 'Bearer mock:email:sd-002:user2@softdelete.test');

    expect(res.status).toBe(400);
    expect(res.body.error.code).toBe('ACCOUNT_ALREADY_DELETED');
  });

  test('GET /auth/me returns 403 USER_DELETED after account is deleted', async () => {
    await request(app)
      .post('/api/v1/auth/register')
      .send({ provider: 'email', idToken: 'mock:email:sd-003:user3@softdelete.test' });

    await request(app)
      .delete('/api/v1/users/me')
      .set('Authorization', 'Bearer mock:email:sd-003:user3@softdelete.test');

    const res = await request(app)
      .get('/api/v1/auth/me')
      .set('Authorization', 'Bearer mock:email:sd-003:user3@softdelete.test');

    expect(res.status).toBe(403);
    expect(res.body.error.code).toBe('USER_DELETED');
  });

  test('login within 30 days reactivates account and clears deleted_at', async () => {
    await request(app)
      .post('/api/v1/auth/register')
      .send({ provider: 'email', idToken: 'mock:email:sd-004:user4@softdelete.test' });

    await request(app)
      .delete('/api/v1/users/me')
      .set('Authorization', 'Bearer mock:email:sd-004:user4@softdelete.test');

    const res = await request(app)
      .post('/api/v1/auth/login')
      .send({ provider: 'email', idToken: 'mock:email:sd-004:user4@softdelete.test' });

    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);

    const user = await prisma.users.findUnique({ where: { email: 'user4@softdelete.test' } });
    expect(user?.deleted_at).toBeNull();
  });

  test('purgeDeletedUsers only hard-deletes rows older than 30 days', async () => {
    await request(app)
      .post('/api/v1/auth/register')
      .send({ provider: 'email', idToken: 'mock:email:sd-005:user5@softdelete.test' });

    await request(app)
      .delete('/api/v1/users/me')
      .set('Authorization', 'Bearer mock:email:sd-005:user5@softdelete.test');

    // Set deleted_at to 1 day ago — within grace period, should NOT be purged
    await prisma.users.updateMany({
      where: { email: 'user5@softdelete.test' },
      data: { deleted_at: new Date(Date.now() - 1 * 24 * 60 * 60 * 1000) },
    });

    const { UserRepository } = await import('../src/repositories/user-repository');
    const repo = new UserRepository();
    const purged = await repo.purgeDeletedUsers();

    expect(purged).toBe(0);

    const user = await prisma.users.findUnique({ where: { email: 'user5@softdelete.test' } });
    expect(user).not.toBeNull();
  });

  test('purgeDeletedUsers hard-deletes rows older than 30 days', async () => {
    await request(app)
      .post('/api/v1/auth/register')
      .send({ provider: 'email', idToken: 'mock:email:sd-006:user6@softdelete.test' });

    // Set deleted_at to 31 days ago — outside grace period, should be purged
    await prisma.users.updateMany({
      where: { email: 'user6@softdelete.test' },
      data: { deleted_at: new Date(Date.now() - 31 * 24 * 60 * 60 * 1000) },
    });

    const { UserRepository } = await import('../src/repositories/user-repository');
    const repo = new UserRepository();
    const purged = await repo.purgeDeletedUsers();

    expect(purged).toBeGreaterThanOrEqual(1);

    const user = await prisma.users.findUnique({ where: { email: 'user6@softdelete.test' } });
    expect(user).toBeNull();
  });
});
