# WeVibe Backend

Node.js/Express API for the WeVibe iOS app.

**Runtime:** Node.js 20 | **Language:** TypeScript 5.7 (strict) | **Framework:** Express 4  
**ORM:** Prisma 6 → PostgreSQL 15 + PostGIS | **Real-time:** Socket.IO + Upstash Redis | **Tests:** Jest + supertest

---

## Requirements

- Node.js v20.x
- npm v10+
- Docker (for PostgreSQL + Redis)

---

## Local Setup

1. **Install dependencies**
   ```bash
   cd backend && npm ci
   ```

2. **Configure environment**
   ```bash
   cp .env.example .env
   ```
   Edit `.env` — see [Environment Variables](#environment-variables) below.

3. **Start the database**
   ```bash
   npm run db:start    # Docker: starts PostgreSQL + Redis
   ```

   > **Port conflict (Mac):** If a local Postgres is already running on port 5432, stop it first:
   > ```bash
   > launchctl unload ~/Library/LaunchAgents/homebrew.mxcl.postgresql@14.plist
   > ```

4. **Apply schema and generate Prisma client**
   ```bash
   npm run db:push                                         # apply schema to DB
   npx prisma generate --schema src/db/schema.prisma      # generate Prisma client
   ```

5. **Start the server**
   ```bash
   npm start
   # → API running on http://localhost:3000
   ```

6. **Run tests**
   ```bash
   npm test
   ```

---

## Environment Variables

| Variable | Required | Description |
|----------|----------|-------------|
| `DATABASE_URL` | Yes | `postgresql://admin:password@localhost:5432/wevibe_dev` |
| `AUTH_PROVIDER_MODE` | Yes | `firebase` (prod) or `mock` (local dev — no Firebase needed) |
| `FIREBASE_PROJECT_ID` | Firebase only | `wevibe-dev` or `wevibe-prod` |
| `FIREBASE_STORAGE_BUCKET` | Firebase only | Firebase Storage bucket name |
| `GOOGLE_APPLICATION_CREDENTIALS` | Firebase only | Path to service account JSON — place in `backend/secrets/` (gitignored) |
| `PORT` | No | API port — set to `3000` locally; defaults to `8080` (used by Cloud Run) |
| `GEMINI_API_KEY` | Yes | Google Gemini API key — required for AI bio generation |
| `UPSTASH_REDIS_URL` | Prod | Upstash Redis URL (`rediss://...`) — omit locally to use in-memory Socket.IO adapter |
| `APPLE_TEAM_ID` | Yes | Apple Developer Team ID — required for Apple token revocation. Find it at [developer.apple.com](https://developer.apple.com) under Membership. |
| `APPLE_KEY_ID` | Yes | Sign in with Apple key ID from Apple Developer portal |
| `APPLE_PRIVATE_KEY` | Yes | Contents of the `.p8` file — encode newlines as `\n` in `.env` |
| `MATCHMAKING_RECENT_MATCH_COOLDOWN_ENABLED` | No | Block recently-matched pairs for 2 days. Auto-enabled in `NODE_ENV=production`; set to `false` locally. |

**Firebase service account files** (required when `AUTH_PROVIDER_MODE=firebase`):
```
backend/secrets/firebase-service-account-dev.json    ← dev
backend/secrets/firebase-service-account-prod.json   ← prod
```
These are gitignored — get them from a team member.

---

## Mock Auth (Local Development)

Set `AUTH_PROVIDER_MODE=mock` in `.env` to bypass Firebase entirely. The backend accepts tokens in this format:

`mock:<provider>:<uid>:<email>`

Examples:
- `mock:google:g-001:alice@gmail.com`
- `mock:apple:a-001:bob@icloud.com`
- `mock:email:e-001:charlie@example.com`

```bash
# Register a user
curl -X POST http://localhost:3000/api/v1/auth/register \
  -H "Content-Type: application/json" \
  -d '{"provider": "email", "idToken": "mock:email:e-001:charlie@example.com"}'

# Fetch profile
curl http://localhost:3000/api/v1/users/profile \
  -H "Authorization: Bearer mock:email:e-001:charlie@example.com"
```

---

## npm Scripts

| Command | Description |
|---------|-------------|
| `npm start` | Start the API server (`ts-node src/server.ts`) |
| `npm test` | Run Jest test suite |
| `npm run db:start` | Start PostgreSQL + Redis via Docker Compose |
| `npm run db:stop` | Stop Docker services |
| `npm run db:push` | Apply Prisma schema to the database |
| `npm run db:generate` | Regenerate Prisma client |
| `npm run db:seed` | Seed the database with fake data |
| `npm run db:check` | Check database connectivity |

---

## API Endpoints

All routes require a Bearer token unless noted. Full request/response shapes: [docs/api-contract.md](docs/api-contract.md) | [docs/report-api.md](docs/report-api.md)

### Auth

| Method | Path | Description |
|--------|------|-------------|
| `GET` | `/health` | Health check (no auth) |
| `POST` | `/api/v1/auth/register` | Create backend user after Firebase registration |
| `POST` | `/api/v1/auth/login` | Login / upsert backend user after Firebase sign-in |
| `POST` | `/api/v1/auth/logout` | Logout |
| `GET` | `/api/v1/auth/me` | Returns `{ data: { user: { onboardingComplete: bool } } }` |

### Profile

| Method | Path | Description |
|--------|------|-------------|
| `POST` | `/api/v1/users/profile` | Submit onboarding survey — creates profile |
| `GET` | `/api/v1/users/profile` | Get own profile (401 `PROFILE_NOT_FOUND` if not created yet) |
| `PATCH` | `/api/v1/users/profile` | Partial profile update — only sent fields are updated |
| `POST` | `/api/v1/users/profile/photos/upload-url` | Get signed GCS PUT URL for photo upload |
| `POST` | `/api/v1/users/profile/photos/finalize` | Confirm upload, write photo record |
| `DELETE` | `/api/v1/users/profile/photos/:photoId` | Delete photo |
| `PATCH` | `/api/v1/users/profile/photos/reorder` | Update photo display order |
| `POST` | `/api/v1/users/profile/personality` | Submit personality test answers |
| `POST` | `/api/v1/users/:id/generate-bio` | Generate and save AI bio (Gemini 2.5 Flash) — users can only generate their own |

### Account

| Method | Path | Description |
|--------|------|-------------|
| `PATCH` | `/api/v1/users/fcm-token` | Store/refresh device FCM push notification token |
| `DELETE` | `/api/v1/users/me` | Soft-delete account (30-day grace period + Firebase + Apple token revocation) |

### Matchmaking / Queue

| Method | Path | Description |
|--------|------|-------------|
| `POST` | `/api/v1/matching/queue/join` | Join speed-dating queue |
| `POST` | `/api/v1/matching/queue/leave` | Leave queue |
| `GET` | `/api/v1/matching/queue/status` | Queue status |
| `GET` | `/api/v1/matching/sessions` | List active speed-dating sessions for current user |

### Speed Dating Sessions

| Method | Path | Description |
|--------|------|-------------|
| `GET` | `/api/v1/matching/sessions/:sessionId` | Session detail (counterpart, status, timer, limits) |
| `GET` | `/api/v1/matching/sessions/:sessionId/messages` | Message history |
| `POST` | `/api/v1/matching/sessions/:sessionId/messages` | Send message |
| `PATCH` | `/api/v1/matching/sessions/:sessionId/read` | Mark messages read |
| `POST` | `/api/v1/matching/sessions/:sessionId/move-to-permanent/request` | Request permanent match |
| `POST` | `/api/v1/matching/sessions/:sessionId/move-to-permanent/respond` | Respond to permanent match request |
| `POST` | `/api/v1/matching/sessions/:sessionId/final-decision` | Submit final like/pass decision |
| `POST` | `/api/v1/matching/sessions/:sessionId/end` | End session early |

### Permanent Chat

| Method | Path | Description |
|--------|------|-------------|
| `GET` | `/api/v1/matching/matches` | List permanent matches |
| `GET` | `/api/v1/matching/matches/:matchId` | Match detail |
| `GET` | `/api/v1/matching/matches/:matchId/messages` | Message history |
| `GET` | `/api/v1/matching/matches/:matchId/profile` | Matched user's profile |
| `PATCH` | `/api/v1/matching/matches/:matchId/read` | Mark messages read |
| `POST` | `/api/v1/matching/matches/:matchId/messages` | Send message |
| `POST` | `/api/v1/matching/matches/:matchId/remove` | Remove match |
| `POST` | `/api/v1/matching/matches/:matchId/block` | Block counterpart |
| `POST` | `/api/v1/matching/matches/:matchId/report` | Report counterpart |

### Chat Badges

| Method | Path | Description |
|--------|------|-------------|
| `GET` | `/api/v1/matching/chats/badges` | Unread badge counts for speed-dating + permanent chats |

### Reports

| Method | Path | Description |
|--------|------|-------------|
| `POST` | `/api/v1/reports` | Submit a report (`reportedUserId`, `reason`, optional `details`/`matchId`) |
| `GET` | `/api/v1/reports` | Reports submitted by the authenticated user |

Valid `reason` values: `inappropriate_content`, `harassment`, `spam`, `fake_profile`, `underage`, `scam`, `hate_speech`, `violence`, `other`. Duplicate match reports are rejected with `DUPLICATE_REPORT`.

---

## WebSocket (Socket.IO)

Server: `src/websocket/socket-server.ts`. Auth: Bearer token in the Socket.IO handshake auth header.

Uses Upstash Redis adapter in production for horizontal scaling. Falls back to in-memory adapter when `UPSTASH_REDIS_URL` is not set.

### Client → Server

| Event | Payload | Description |
|-------|---------|-------------|
| `typing` | `{ chatType, chatId, isTyping }` | Relay typing indicator to peer |
| `ping` | — | Keepalive; server emits `pong` |

### Server → Client

| Event | Payload | Description |
|-------|---------|-------------|
| `matching.queue.matched` | `{ sessionId }` | Match found — navigate to speed-dating session |
| `speed_dating.message.created` | `{ sessionId, message }` | Incoming speed-dating message |
| `speed_dating.typing.updated` | `{ sessionId, userId, isTyping }` | Typing indicator |
| `speed_dating.session.ended` | `{ sessionId }` | Session expired or ended |
| `permanent.message.created` | `{ matchId, message }` | Incoming permanent-chat message |
| `error` | `{ code, message }` | Server-side error |

---

## Architecture

Layered: **Routes → Controllers → Services → Repositories → Prisma → PostgreSQL**

```
src/
  routes/         Route definitions
  controllers/    Request/response handling + input validation
  services/       Business logic
  repositories/   Database query layer (Prisma)
  middleware/     authenticate.ts, error-handler.ts
  websocket/      socket-server.ts (Socket.IO + Redis pub/sub), socket-auth.middleware.ts
  db/             prisma-client.ts (singleton), schema.prisma
  utils/          errors.ts — AppError + factory functions
  config/         env.ts — validated environment config
  types/          Shared type definitions

tests/            Jest test suites
```

**Auth abstraction:** `AuthVerifier` interface — Firebase (prod) or Mock (tests). Wired at route level via `createAuthVerifier()`.

**Error handling:** Services throw typed errors; routes use `asyncHandler`. No try/catch in controllers.

```typescript
throw unauthorized('Token expired');    // 401
throw badRequest('Invalid input');      // 400
throw forbidden('No access');           // 403
throw conflict('Already exists');       // 409
throw notFound('Resource not found');   // 404
```

Response envelope:
```json
{ "success": true, "data": { ... } }
{ "success": false, "error": { "code": "ERROR_CODE", "message": "..." } }
```

---

## Deployment (Google Cloud Run)

```bash
bash upload_gcp.sh
```

`cloudbuild.yaml` builds and pushes a Docker image to Google Container Registry on every push. The image exposes port `8080` on a `node:20` base.

```bash
# Health check
curl https://wevibe-backend19-1001323522506.us-central1.run.app/health
```

---

## Dev Utilities

**Wipe all user data** (after deleting Firebase accounts to start fresh):
```bash
docker exec -it wevibe_postgres psql -U admin -d wevibe_dev \
  -c "TRUNCATE TABLE users CASCADE;"
```
Cascades to: `profiles`, `matches`, `messages`, `speed_dating_sessions`, `speed_dating_messages`, `matching_queue`, `user_blocks`, `user_reports`.

**Nuclear reset** (drop all data + reapply schema):
```bash
npx prisma db push --force-reset --schema src/db/schema.prisma
```

**Visual DB editor** (Prisma Studio):
```bash
cd backend && npx prisma studio --schema src/db/schema.prisma
```
