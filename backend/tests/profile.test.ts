import request from 'supertest';
import { PrismaClient } from '@prisma/client';
import { createApp } from '../src/app';

const prisma = new PrismaClient();
const app = createApp();

describe('Profile API - POST /api/v1/users/profile', () => {
  beforeAll(async () => {
    await prisma.$connect();
  });

  beforeEach(async () => {
    await prisma.$executeRaw`DELETE FROM profiles WHERE user_id IN (SELECT id FROM users WHERE email LIKE '%@profile.test')`;
    await prisma.$executeRaw`DELETE FROM users WHERE email LIKE '%@profile.test'`;
  });

  afterAll(async () => {
    await prisma.$disconnect();
  });

  // Helper: register a user and return their mock token
  async function registerUser(token: string): Promise<void> {
    await request(app)
      .post('/api/v1/auth/register')
      .send({ provider: 'google', idToken: token });
  }

  test('should create a profile for a registered user', async () => {
    const token = 'mock:google:p-001:alice@profile.test';
    await registerUser(token);

    const response = await request(app)
      .post('/api/v1/users/profile')
      .set('Authorization', `Bearer ${token}`)
      .send({
        first_name: 'Alice',
        last_name: 'Smith',
        birth_date: '1998-05-20',
        gender: 'Female',
      });

    expect(response.status).toBe(201);
    expect(response.body.success).toBe(true);
    expect(response.body.data.profile.displayName).toBe('Alice Smith');
    expect(response.body.data.profile.gender).toBe('Female');
    expect(response.body.data.profile.birthDate).toBeDefined();
  });

  test('should return 409 if profile already exists', async () => {
    const token = 'mock:google:p-002:bob@profile.test';
    await registerUser(token);

    await request(app)
      .post('/api/v1/users/profile')
      .set('Authorization', `Bearer ${token}`)
      .send({
        first_name: 'Bob',
        last_name: 'Jones',
        birth_date: '1995-03-10',
        gender: 'Male',
      });

    const response = await request(app)
      .post('/api/v1/users/profile')
      .set('Authorization', `Bearer ${token}`)
      .send({
        first_name: 'Bob',
        last_name: 'Jones',
        birth_date: '1995-03-10',
        gender: 'Male',
      });

    expect(response.status).toBe(409);
    expect(response.body.success).toBe(false);
    expect(response.body.error.code).toBe('PROFILE_ALREADY_EXISTS');
  });

  test('should return 401 without bearer token', async () => {
    const response = await request(app)
      .post('/api/v1/users/profile')
      .send({
        first_name: 'Alice',
        last_name: 'Smith',
        birth_date: '1998-05-20',
        gender: 'Female',
      });

    expect(response.status).toBe(401);
    expect(response.body.error.code).toBe('MISSING_BEARER_TOKEN');
  });

  test('should return 400 for missing first_name', async () => {
    const token = 'mock:google:p-003:charlie@profile.test';
    await registerUser(token);

    const response = await request(app)
      .post('/api/v1/users/profile')
      .set('Authorization', `Bearer ${token}`)
      .send({
        last_name: 'Brown',
        birth_date: '1998-05-20',
        gender: 'Male',
      });

    expect(response.status).toBe(400);
    expect(response.body.error.code).toBe('MISSING_FIRST_NAME');
  });

  test('should return 400 for missing last_name', async () => {
    const token = 'mock:google:p-004:diana@profile.test';
    await registerUser(token);

    const response = await request(app)
      .post('/api/v1/users/profile')
      .set('Authorization', `Bearer ${token}`)
      .send({
        first_name: 'Diana',
        birth_date: '1998-05-20',
        gender: 'Female',
      });

    expect(response.status).toBe(400);
    expect(response.body.error.code).toBe('MISSING_LAST_NAME');
  });

  test('should return 400 for missing birth_date', async () => {
    const token = 'mock:google:p-005:evan@profile.test';
    await registerUser(token);

    const response = await request(app)
      .post('/api/v1/users/profile')
      .set('Authorization', `Bearer ${token}`)
      .send({
        first_name: 'Evan',
        last_name: 'White',
        gender: 'Male',
      });

    expect(response.status).toBe(400);
    expect(response.body.error.code).toBe('MISSING_BIRTH_DATE');
  });

  test('should return 400 for invalid birth_date format', async () => {
    const token = 'mock:google:p-006:fiona@profile.test';
    await registerUser(token);

    const response = await request(app)
      .post('/api/v1/users/profile')
      .set('Authorization', `Bearer ${token}`)
      .send({
        first_name: 'Fiona',
        last_name: 'Green',
        birth_date: 'not-a-date',
        gender: 'Female',
      });

    expect(response.status).toBe(400);
    expect(response.body.error.code).toBe('INVALID_BIRTH_DATE');
  });

  test('should return 400 for missing gender', async () => {
    const token = 'mock:google:p-007:george@profile.test';
    await registerUser(token);

    const response = await request(app)
      .post('/api/v1/users/profile')
      .set('Authorization', `Bearer ${token}`)
      .send({
        first_name: 'George',
        last_name: 'Black',
        birth_date: '1998-05-20',
      });

    expect(response.status).toBe(400);
    expect(response.body.error.code).toBe('MISSING_GENDER');
  });

  test('should return 400 for invalid gender value', async () => {
    const token = 'mock:google:p-008:hannah@profile.test';
    await registerUser(token);

    const response = await request(app)
      .post('/api/v1/users/profile')
      .set('Authorization', `Bearer ${token}`)
      .send({
        first_name: 'Hannah',
        last_name: 'Blue',
        birth_date: '1998-05-20',
        gender: 'attack_helicopter',
      });

    expect(response.status).toBe(400);
    expect(response.body.error.code).toBe('INVALID_GENDER');
  });

  test('should accept all valid gender values', async () => {
    const genders = ['Male', 'Female', 'Non-binary', 'Prefer not to say'];

    for (let i = 0; i < genders.length; i++) {
      const token = `mock:google:p-gender-${i}:gendertest${i}@profile.test`;
      await registerUser(token);

      const response = await request(app)
        .post('/api/v1/users/profile')
        .set('Authorization', `Bearer ${token}`)
        .send({
          first_name: 'Test',
          last_name: 'User',
          birth_date: '1998-05-20',
          gender: genders[i],
        });

      expect(response.status).toBe(201);
      expect(response.body.data.profile.gender).toBe(genders[i]);
    }
  });
});

describe('Profile API - GET /api/v1/users/profile', () => {
  beforeAll(async () => {
    await prisma.$connect();
  });

  beforeEach(async () => {
    await prisma.$executeRaw`DELETE FROM profiles WHERE user_id IN (SELECT id FROM users WHERE email LIKE '%@get.profile.test')`;
    await prisma.$executeRaw`DELETE FROM users WHERE email LIKE '%@get.profile.test'`;
  });

  afterAll(async () => {
    await prisma.$disconnect();
  });

  async function registerUser(token: string): Promise<void> {
    await request(app)
      .post('/api/v1/auth/register')
      .send({ provider: 'google', idToken: token });
  }

  async function createProfile(token: string): Promise<void> {
    await request(app)
      .post('/api/v1/users/profile')
      .set('Authorization', `Bearer ${token}`)
      .send({
        first_name: 'Alice',
        last_name: 'Smith',
        birth_date: '1998-05-20',
        gender: 'Female',
      });
  }

  test('should return profile for authenticated user', async () => {
    const token = 'mock:google:g-001:alice@get.profile.test';
    await registerUser(token);
    await createProfile(token);

    const response = await request(app)
      .get('/api/v1/users/profile')
      .set('Authorization', `Bearer ${token}`);

    expect(response.status).toBe(200);
    expect(response.body.success).toBe(true);
    expect(response.body.data.profile.displayName).toBe('Alice Smith');
    expect(response.body.data.profile.gender).toBe('Female');
  });

  test('should return 401 without bearer token', async () => {
    const response = await request(app).get('/api/v1/users/profile');

    expect(response.status).toBe(401);
    expect(response.body.error.code).toBe('MISSING_BEARER_TOKEN');
  });

  test('should return 401 if profile does not exist', async () => {
    const token = 'mock:google:g-002:bob@get.profile.test';
    await registerUser(token);

    const response = await request(app)
      .get('/api/v1/users/profile')
      .set('Authorization', `Bearer ${token}`);

    expect(response.status).toBe(401);
    expect(response.body.error.code).toBe('PROFILE_NOT_FOUND');
  });
});
