import path from 'path';
import dotenv from 'dotenv';

dotenv.config({ path: path.resolve(process.cwd(), '.env') });

function parseCsvEnv(value: string | undefined): string[] {
  if (!value) return [];
  return value
    .split(',')
    .map((item) => item.trim())
    .filter((item) => item.length > 0);
}

function parseBooleanEnv(value: string | undefined): boolean | undefined {
  if (value === undefined) return undefined;

  const normalized = value.trim().toLowerCase();
  if (['1', 'true', 'yes', 'on'].includes(normalized)) return true;
  if (['0', 'false', 'no', 'off'].includes(normalized)) return false;

  throw new Error(`Invalid boolean env value: ${value}`);
}

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
  // Firebase Storage bucket — required when AUTH_PROVIDER_MODE=firebase
  firebaseStorageBucket: process.env.FIREBASE_STORAGE_BUCKET ?? '',
  // Optional comma-separated CORS allowlist for socket.io browser clients.
  // Leave empty for native apps (iOS) where CORS does not apply.
  wsCorsOrigins: parseCsvEnv(process.env.WS_CORS_ORIGINS),
  get matchmakingRecentMatchCooldownEnabled(): boolean {
    return parseBooleanEnv(process.env.MATCHMAKING_RECENT_MATCH_COOLDOWN_ENABLED) ?? process.env.NODE_ENV === 'production';
  },
  // Upstash Redis URL for Socket.IO multi-instance adapter (Cloud Run).
  // Must use rediss:// scheme (TLS). Omit in local dev to use in-memory adapter.
  upstashRedisUrl: process.env.UPSTASH_REDIS_URL ?? null,

  // Apple Sign-In credentials — required for Apple refresh token exchange and revocation
  // on account deletion (App Store Review Guideline 5.1.1).
  // APPLE_PRIVATE_KEY: content of the .p8 file from Apple Developer portal.
  //   Newlines must be encoded as \n in the .env file.
  appleTeamId: process.env.APPLE_TEAM_ID ?? '',
  appleKeyId: process.env.APPLE_KEY_ID ?? '',
  applePrivateKey: (process.env.APPLE_PRIVATE_KEY ?? '').replace(/\\n/g, '\n'),
};
