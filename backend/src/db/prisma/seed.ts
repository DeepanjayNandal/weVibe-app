import { 
  PrismaClient, 
  enum_sex, 
  enum_intent, 
  enum_education, 
  enum_frequency, 
  enum_preference_level, 
  enum_sleep_schedule,
  enum_meet_gender
} from '@prisma/client';
import { faker } from '@faker-js/faker';

const prisma = new PrismaClient();

async function main() {
  console.log('🌱 Seeding fake data...');

  // 1. Clean up old data (Order matters due to Foreign Key constraints)
  // Use TRUNCATE to clear tables cleanly
  try {
    await prisma.$executeRaw`TRUNCATE TABLE user_blocks, matching_queue, speed_dating_messages, speed_dating_sessions, messages, matches, profiles, users CASCADE`;
  } catch (error) {
    console.warn("⚠️  Warning: Could not truncate tables. This is normal if tables don't exist yet or schema is mismatched.");
  }

  // 2. Create Fixed Dev User (Henry)
  // This ensures you always have a known account to log in with after seeding
  const devUser = await prisma.users.create({
    data: {
      email: 'henry.fixed@example.com',
      firebase_uid: 'uid-test-1',
      auth_provider: 'email',
      password_hash: 'mock_hash_secret',
      is_registration_complete: true,
      is_personality_test_complete: true,
      current_status: 'active',
      profiles: {
        create: {
          display_name: 'Henry (Dev)',
          sex: enum_sex.male,
          gender: 'Man',
          birth_date: new Date('1995-01-01'),
          personality_primary: 'Architect',
          personality_secondary: 'Analyst',
          height_cm: 180,
          relationship_intent: enum_intent.long_term,
        }
      }
    }
  });
  // Set location for Dev User (Taipei 101)
  await prisma.$executeRaw`
    UPDATE profiles 
    SET location_point = ST_SetSRID(ST_MakePoint(121.5654, 25.0330), 4326)::geography
    WHERE user_id = ${devUser.id}::uuid
  `;
  console.log(`👤 Created Dev User: henry.fixed@example.com`);

  // 3. Create 10 fake random users
  for (let i = 0; i < 10; i++) {
    const sex = i % 2 === 0 ? enum_sex.male : enum_sex.female;
    const firstName = faker.person.firstName(sex);
    const lastName = faker.person.lastName();
    
    // Create User
    // Added boolean flags to match new schema requirements
    const user = await prisma.users.create({
      data: {
        email: faker.internet.email({ firstName, lastName }),
        firebase_uid: faker.string.uuid(),
        auth_provider: 'email',
        password_hash: 'mock_hash_secret', 
        phone: faker.phone.number(),
        is_registration_complete: true,
        is_personality_test_complete: true,
        current_status: 'active',
        search_radius_km: 50,
        search_age_min: 18,
        search_age_max: 35,
        search_gender: enum_meet_gender.both,
        preferences: {},
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
        sex: sex,
        gender: sex === 'male' ? 'Man' : 'Woman',
        birth_date: faker.date.birthdate({ min: 18, max: 35, mode: 'age' }),
        personality_primary: faker.helpers.arrayElement(['Serene Soul', 'Wild Heart', 'Quiet Observer']),
        personality_secondary: 'Empathetic Companion',
        ethnicity: faker.helpers.arrayElement(['Asian', 'White', 'Hispanic', 'Black', 'Mixed']),
        height_cm: faker.number.int({ min: 150, max: 200 }),
        state: faker.location.state(),
        zip_code: faker.location.zipCode(),
        career_field: faker.person.jobArea(),
        languages: ['English', 'Mandarin'],
        prompts: [
          { question: "My simple pleasure", answer: faker.lorem.sentence() },
          { question: "I'm looking for", answer: faker.lorem.sentence() }
        ],
        photos: [
          faker.image.urlLoremFlickr({ category: 'people' }),
          faker.image.urlLoremFlickr({ category: 'nature' })
        ],
        social_integrations: {
          instagram: faker.internet.userName(),
        },
        education: enum_education.bachelors,
        relationship_intent: enum_intent.long_term,
        lifestyle_drinks: enum_frequency.sometimes,
        lifestyle_smoking: enum_frequency.never,
        lifestyle_workout: enum_frequency.often,
        lifestyle_pets: enum_preference_level.want,
        lifestyle_children: enum_preference_level.unsure,
        lifestyle_sleep: enum_sleep_schedule.flexible,
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