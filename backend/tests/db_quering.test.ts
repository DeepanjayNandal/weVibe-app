import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

// Define the shape of the raw query result for type safety
interface NearbyUser {
  display_name: string;
  distance_meters: number;
}

describe('Matching System Logic Test', () => {
  
  beforeAll(async () => {
    await prisma.$connect();
  });

  afterAll(async () => {
    await prisma.$disconnect();
  });

  test('Should find users within 50km of Taipei 101', async () => {
    // 1. Setup: Assume I am a user located at Taipei 101
    const myLat = 25.0330;
    const myLng = 121.5654; 

    // 2. Execute: Run raw SQL (Simulate PostGIS query)
    // Note: Prisma queryRaw returns an array
    const nearbyUsers = await prisma.$queryRaw<NearbyUser[]>`
      SELECT 
        display_name, 
        ST_Distance(
          location_point, 
          ST_SetSRID(ST_MakePoint(${myLng}, ${myLat}), 4326)::geography
        ) as distance_meters
      FROM profiles
      WHERE ST_DWithin(
        location_point,
        ST_SetSRID(ST_MakePoint(${myLng}, ${myLat}), 4326)::geography,
        50000 -- 50km
      )
      ORDER BY distance_meters ASC;
    `;

    // 3. Assert
    console.log(`🔍 Found ${nearbyUsers.length} nearby users`);
    if (nearbyUsers.length > 0) {
      console.log('   First closest user:', nearbyUsers[0]);
    }

    // Since we just seeded 10 users within 10km, we should find at least 1
    expect(nearbyUsers.length).toBeGreaterThan(0);
    
    // Verify distance is actually less than 50000 meters
    // Since we already expected length > 0, we can safely take the first one
    const firstUser = nearbyUsers[0];
    expect(firstUser.distance_meters).toBeLessThan(50000);
  });
});
