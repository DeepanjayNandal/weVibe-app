import path from 'path';
import dotenv from 'dotenv';

dotenv.config({ path: path.resolve(process.cwd(), '.env') });

function buildDatabaseUrl(): string {
  if (process.env.DATABASE_URL) {
    return process.env.DATABASE_URL;
  }

  const host = process.env.DB_HOST;
  const port = process.env.DB_PORT;
  const user = process.env.DB_USER;
  const password = process.env.DB_PASS;
  const dbName = process.env.DB_NAME;

  if (!host || !port || !user || !password || !dbName) {
    throw new Error('Missing DB config. Provide DATABASE_URL or DB_HOST/DB_PORT/DB_USER/DB_PASS/DB_NAME');
  }

  return `postgresql://${user}:${password}@${host}:${port}/${dbName}`;
}

export const env = {
  nodeEnv: process.env.NODE_ENV ?? 'development',
  port: Number(process.env.PORT ?? 8080),
  // 'mock' uses fake tokens for local dev; 'firebase' uses real Firebase Admin SDK
  authProviderMode: process.env.AUTH_PROVIDER_MODE ?? 'mock',
  databaseUrl: buildDatabaseUrl(),
  // Firebase project ID — required when AUTH_PROVIDER_MODE=firebase
  firebaseProjectId: process.env.FIREBASE_PROJECT_ID ?? '',
};
