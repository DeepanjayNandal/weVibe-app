const { Pool } = require('pg');
import 'dotenv/config';

describe('Database Connectivity & Health', () => {
  // Use 'any' to bypass missing type definitions if @types/pg is not installed
  let pool: any;

  beforeAll(() => {
    // Initialize connection pool using environment variables
    pool = new Pool({
      connectionString: process.env.DATABASE_URL,
    });
  });

  afterAll(async () => {
    await pool.end();
  });

  test('should successfully connect to the database', async () => {
    const client = await pool.connect();
    try {
      const res = await client.query('SELECT 1 as connected');
      expect(res.rows[0].connected).toBe(1);
    } finally {
      client.release();
    }
  });

  test('should return the current server time', async () => {
    const client = await pool.connect();
    try {
      const res = await client.query('SELECT NOW() as now');
      expect(res.rows[0].now).toBeDefined();
    } finally {
      client.release();
    }
  });
});