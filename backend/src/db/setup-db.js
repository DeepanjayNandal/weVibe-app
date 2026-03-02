const { Client } = require('pg');
const fs = require('fs');
const path = require('path');
// Load .env from project root (two levels up from this file)
require('dotenv').config({ path: path.resolve(__dirname, '../../.env') });

async function runSetup() {
  // 1. Connect to default 'postgres' DB to check/create target DB
  const defaultClient = new Client({
    host: process.env.DB_HOST,
    port: process.env.DB_PORT,
    user: process.env.DB_USER,
    password: process.env.DB_PASS,
    database: 'postgres', // Connect to default DB first
  });

  try {
    await defaultClient.connect();
    const dbName = process.env.DB_NAME;
    
    // Check if DB exists
    const res = await defaultClient.query(`SELECT 1 FROM pg_database WHERE datname = $1`, [dbName]);
    if (res.rowCount > 0) {
      console.log(`Database '${dbName}' already exists. Dropping it to apply new schema...`);
      // Terminate other connections to allow DROP DATABASE
      await defaultClient.query(`
        SELECT pg_terminate_backend(pg_stat_activity.pid)
        FROM pg_stat_activity
        WHERE pg_stat_activity.datname = $1
        AND pid <> pg_backend_pid()
      `, [dbName]);
      await defaultClient.query(`DROP DATABASE "${dbName}"`);
    }
    console.log(`Creating Database '${dbName}'...`);
    await defaultClient.query(`CREATE DATABASE "${dbName}"`);
    await defaultClient.end();

    // 2. Connect to the target DB to run schema
    const targetClient = new Client({
      host: process.env.DB_HOST,
      port: process.env.DB_PORT,
      user: process.env.DB_USER,
      password: process.env.DB_PASS,
      database: dbName,
    });

    console.log(`Connecting to [${dbName}]...`);
    await targetClient.connect();

    const sqlPath = path.join(__dirname, 'schema.sql');
    const schemaSQL = fs.readFileSync(sqlPath, 'utf8');
    
    console.log('Executing schema.sql...');
    await targetClient.query(schemaSQL);
    
    console.log('Success! Database architecture is fully deployed in Docker.');
    await targetClient.end();
  } catch (err) {
    console.error(' Setup Failed!');
    console.error('Error Detail:', err.message || err);
    console.log('\n Tip: Make sure your Docker container is running and .env values are correct.');
    process.exit(1);
  }
}

runSetup();