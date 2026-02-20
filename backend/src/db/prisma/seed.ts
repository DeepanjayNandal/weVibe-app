import { PrismaClient } from '@prisma/client';
import { faker } from '@faker-js/faker';

const prisma = new PrismaClient();

async function main() {
  console.log('🌱 Seeding fake data...');

  // 1. Clean up old data (Order matters due to Foreign Key constraints)
  // Note: Prisma's deleteMany does not reset Auto Increment ID, but it doesn't matter for UUIDs
  await prisma.$executeRaw`TRUNCATE TABLE messages, matches, profiles, users CASCADE`;

  // 2. Create 10 fake users
  for (let i = 0; i < 10; i++) {
    const sex = faker.person.sexType();
    const firstName = faker.person.firstName(sex);
    const lastName = faker.person.lastName();
    
    // Create User
    const user = await prisma.users.create({
      data: {
        email: faker.internet.email({ firstName, lastName }),
        firebase_uid: faker.string.uuid(),
        auth_provider: 'email',
        password_hash: '$2b$10$EpQqjFwOWI7NYrEn8xtzPO5/8Kx.J.a/lam/a.a.a.a', // Fake hash
        phone: faker.phone.number(),
        current_status: 'active',
        search_radius_km: 50,
        search_age_min: 18,
        search_age_max: 35,
        preferences: {
          accepts_smoker: faker.datatype.boolean(),
          accepts_pets: true,
        },
      },
    });

    // Simulate location: Random point within 10km of Taipei 101
    // Taipei 101 coordinates: 25.0330, 121.5654
    const location = faker.location.nearbyGPSCoordinate({
      origin: [25.0330, 121.5654],
      radius: 10, // km
      isMetric: true,
    });
    const lat = location[0];
    const lng = location[1];

    // Create Profile
    // Note: Prisma does not support writing PostGIS geography directly, so we create Profile first, then update location with Raw SQL
    await prisma.profiles.create({
      data: {
        user_id: user.id,
        display_name: `${firstName} ${lastName}`,
        gender: sex,
        birth_date: faker.date.birthdate({ min: 18, max: 35, mode: 'age' }),
        personality_primary: faker.helpers.arrayElement(['Serene Soul', 'Wild Heart', 'Quiet Observer']),
        personality_secondary: 'Empathetic Companion',
        tags: [faker.word.noun(), faker.word.noun()], // Prisma handles JSON serialization automatically
        details: {
          zodiac: "Leo",
          bio: faker.lorem.sentence(),
          job: faker.person.jobTitle(),
        },
        likes_received_count: faker.number.int({ min: 0, max: 100 }),
      },
    });

    // 🔥 Update PostGIS coordinates
    // ST_SetSRID(ST_MakePoint(lng, lat), 4326)
    await prisma.$executeRaw`
      UPDATE profiles 
      SET location_point = ST_SetSRID(ST_MakePoint(${lng}, ${lat}), 4326)::geography
      WHERE user_id = ${user.id}::uuid
    `;

    console.log(`Created user: ${firstName} at [${lat}, ${lng}]`);
  }

  console.log('✅ Seeding completed!');
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });