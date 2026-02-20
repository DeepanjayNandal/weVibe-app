import { PrismaClient } from '@prisma/client';
import { faker } from '@faker-js/faker';
import 'dotenv/config';

const prisma = new PrismaClient();

describe('User Registration Integration Flow', () => {
  
  beforeAll(async () => {
    await prisma.$connect();
  });

  afterAll(async () => {
    await prisma.$disconnect();
  });

  test('should create a new user account, register profile details, and display them', async () => {
    // 1. generate Fake Data
    const mockUser = {
      email: faker.internet.email(),
      firebase_uid: faker.string.uuid(),
      display_name: faker.person.fullName(),
      bio: faker.lorem.sentence(),
      gender: faker.person.sex(),

      lat: 25.0330 + (Math.random() * 0.01), 
      lng: 121.5654 + (Math.random() * 0.01)
    };

    console.log('🆕 Test: Attempting to register user:', mockUser.display_name);

    // 2. Insert into users
    // Use raw query to ensure execution even if Prisma Client types are not updated
    const userResult = await prisma.$queryRaw<any[]>`
      INSERT INTO users (email, firebase_uid, auth_provider, created_at)
      VALUES (${mockUser.email}, ${mockUser.firebase_uid}, 'google', NOW())
      RETURNING id;
    `;
    
    const userId = userResult[0].id;
    expect(userId).toBeDefined();

    // 3. Register profile details (Insert into profiles)
    // Include PostGIS location setting
    await prisma.$executeRaw`
      INSERT INTO profiles (user_id, display_name, details, gender, location_point)
      VALUES (
        ${userId}::uuid, 
        ${mockUser.display_name}, 
        ${JSON.stringify({ bio: mockUser.bio })}::json, 
        ${mockUser.gender},
        ST_SetSRID(ST_MakePoint(${mockUser.lng}, ${mockUser.lat}), 4326)
      );
    `;

    // 4. Verify Data (Retrieve and Verify)
    // Join query to confirm correct data association
    const savedData = await prisma.$queryRaw<any[]>`
      SELECT u.email, u.firebase_uid, u.auth_provider, p.display_name, p.details, p.gender
      FROM users u
      JOIN profiles p ON u.id = p.user_id
      WHERE u.id = ${userId}::uuid;
    `;

    // 5. Display Result
    console.log('✅ Registration Successful! Retrieved User Data:', savedData[0]);

    expect(savedData.length).toBe(1);
    expect(savedData[0].email).toBe(mockUser.email);
    expect(savedData[0].firebase_uid).toBe(mockUser.firebase_uid);
    expect(savedData[0].auth_provider).toBe('google');
    expect(savedData[0].display_name).toBe(mockUser.display_name);
    expect(savedData[0].details.bio).toBe(mockUser.bio);
  });
});