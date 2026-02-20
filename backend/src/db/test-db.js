const { Client } = require('pg');
const path = require('path');
// Load .env from project root
require('dotenv').config({ path: path.resolve(__dirname, '../../.env') });

// Database connection settings
const client = new Client({
  host: process.env.DB_HOST,
  port: process.env.DB_PORT,
  user: process.env.DB_USER,
  password: process.env.DB_PASS,
  database: process.env.DB_NAME,
});

async function checkDatabase() {
  try {
    await client.connect();
    console.log('🚀 Successfully connected to PostgreSQL!');

    // 1. Check PostGIS version
    const gisRes = await client.query('SELECT PostGIS_Full_Version();');
    console.log('🌍 PostGIS Version:', gisRes.rows[0].postgis_full_version.split(' ')[1]);

    // 2. List all tables to see if your schema is there
    const tableRes = await client.query(`
      SELECT table_name 
      FROM information_schema.tables 
      WHERE table_schema = 'public'
    `);
    
    console.log('📊 Tables found in Database:');
    if (tableRes.rows.length === 0) {
      console.log('   (No tables found. Did you run the CREATE TABLE SQL?)');
    } else {
      tableRes.rows.forEach(row => console.log(`   - ${row.table_name}`));
    }

  } catch (err) {
    console.error('❌ Connection Error:', err.stack);
  } finally {
    await client.end();
  }
}

checkDatabase();