# WeVibe

iOS dating app featuring real-time speed dating sessions, matchmaking queue, persistent chat for matched users, personality-based profiles, photo uploads, push notifications, and AI-generated bios.

---

## Tech Stack

| Layer | Tech |
|-------|------|
| iOS App | Swift / SwiftUI, Firebase Auth, Socket.IO |
| Backend API | Node.js / Express (TypeScript), Prisma, PostgreSQL + PostGIS |
| Real-time | Socket.IO + Upstash Redis (pub/sub) |
| Auth | Firebase Authentication (Google, Apple, Email) |
| Push Notifications | Firebase Cloud Messaging (FCM) |
| Storage | Google Cloud Storage (signed URL photo uploads) |
| AI | Google Gemini 2.5 Flash (AI bio generation) |
| Deployment | Google Cloud Run (Docker) |

---

## System Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                        iOS App (SwiftUI)                     │
│   AuthManager │ APIClient │ SocketService │ MatchmakingService│
└───────────────────────────┬─────────────────────────────────┘
                            │  HTTPS + Socket.IO
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                   Express API (Node.js / TypeScript)         │
│                                                              │
│  ┌──────────┐  ┌─────────────┐  ┌──────────┐  ┌─────────┐ │
│  │  Routes  │→ │ Controllers │→ │ Services │→ │  Repos  │ │
│  └──────────┘  └─────────────┘  └──────────┘  └────┬────┘ │
│                                                      │       │
│  Middleware: Firebase JWT verify → authenticate()    │       │
│  Error Handler: AppError → structured JSON response  │       │
└──────────────────────────────────────────────────────┼──────┘
                                                       │
              ┌────────────────────────────────────────┤
              │                                        │
              ▼                                        ▼
┌─────────────────────────┐              ┌─────────────────────┐
│  PostgreSQL + PostGIS   │              │   Upstash Redis      │
│  (Prisma ORM)           │              │   (Socket.IO pub/sub)│
│                         │              └─────────────────────┘
│  users, profiles,       │
│  matches, messages,     │              ┌─────────────────────┐
│  speed_dating_sessions  │              │  Google Cloud        │
└─────────────────────────┘              │  Storage (photos)    │
                                         └─────────────────────┘
              ┌──────────────────────────────────────────┐
              │           External Services               │
              │  Firebase Auth  │  FCM  │  Gemini AI      │
              └──────────────────────────────────────────┘
```

### Request Flow

1. iOS sends HTTP request with Firebase Bearer token
2. `authenticate` middleware verifies JWT via Firebase Admin SDK
3. Request hits Controller — validates input, calls Service
4. Service runs business logic, calls Repository
5. Repository queries PostgreSQL via Prisma
6. Response returned as `{ success, data }` or `{ success, error }` envelope

### Real-time Flow

1. iOS connects to Socket.IO with Bearer token
2. Server verifies token, joins user to their room
3. On message send → REST API saves to DB → emits Socket.IO event to counterpart
4. In production: Redis pub/sub allows multiple server instances to relay events

---

## Project Structure

```
weVibe-app/
  frontend/iOS/     SwiftUI iOS app
  backend/          Node.js/Express API
```

### Backend Structure

```
backend/src/
  routes/           API route definitions
  controllers/      Input validation + request/response handling
  services/         Business logic
  repositories/     Database queries (Prisma)
  middleware/       authenticate.ts, error-handler.ts
  websocket/        Socket.IO server + Redis pub/sub
  db/               schema.prisma, migrations, prisma-client
  utils/            errors.ts — AppError factory functions
  config/           env.ts — validated environment config
  types/            Shared TypeScript types
  jobs/             Background jobs (photo cleanup)
backend/tests/      Jest integration test suites
```

---

## Features

- **Speed dating** — timed matchmaking sessions with a queue system
- **Permanent matches** — messaging for mutually liked pairs after a session
- **Real-time chat** — Socket.IO with typing indicators and instant delivery
- **Personality test** — 6-question survey that determines user personality type
- **Photo uploads** — direct-to-GCS via signed URLs, stored as signed read URLs
- **AI bio generation** — Gemini 2.5 Flash with rate limiting (5/day, 60s cooldown)
- **Push notifications** — FCM for new messages in speed dating and permanent chat
- **Apple Sign-In** — full token exchange and revocation on account deletion
- **Soft delete** — 30-day grace period with reactivation on explicit login
- **Block & report** — in-match moderation

---

## Backend Setup

### Requirements

- Node.js v20.x
- npm v10+
- Docker (for PostgreSQL + Redis)

### Local Setup

1. **Install dependencies**
   ```bash
   cd backend && npm ci
   ```

2. **Configure environment**
   ```bash
   cp .env.example .env
   ```

   | Variable | Description |
   |----------|-------------|
   | `DATABASE_URL` | `postgresql://admin:password@localhost:5432/wevibe_dev` |
   | `AUTH_PROVIDER_MODE` | `firebase` (prod) or `mock` (local — no Firebase needed) |
   | `FIREBASE_PROJECT_ID` | Firebase project ID |
   | `GOOGLE_APPLICATION_CREDENTIALS` | Path to Firebase service account JSON |
   | `GEMINI_API_KEY` | Google Gemini API key |
   | `APPLE_TEAM_ID` | Apple Developer Team ID |
   | `APPLE_KEY_ID` | Sign in with Apple key ID |
   | `APPLE_PRIVATE_KEY` | Contents of `.p8` file (newlines as `\n`) |

3. **Start database**
   ```bash
   npm run db:start
   npm run db:push
   npx prisma generate --schema src/db/schema.prisma
   ```

4. **Start server**
   ```bash
   npm start
   # → http://localhost:3000
   ```

5. **Run tests**
   ```bash
   npm test
   ```
   Covers auth, matchmaking, speed dating, permanent chat, photo uploads, soft-delete, and Apple revocation.

### Mock Auth (Local Dev)

Set `AUTH_PROVIDER_MODE=mock` — no Firebase needed. Token format:

```
mock:<provider>:<uid>:<email>
```

Example: `mock:google:g-001:alice@gmail.com`

---

## Key API Endpoints

| Method | Path | Description |
|--------|------|-------------|
| `POST` | `/api/v1/auth/register` | Register user after Firebase sign-up |
| `POST` | `/api/v1/auth/login` | Login / upsert user |
| `GET` | `/api/v1/auth/me` | Get current user session |
| `POST` | `/api/v1/users/profile` | Submit onboarding survey |
| `PATCH` | `/api/v1/users/profile` | Update profile |
| `POST` | `/api/v1/users/profile/generate-bio` | Generate AI bio (Gemini) |
| `POST` | `/api/v1/matching/queue/join` | Join speed dating queue |
| `GET` | `/api/v1/matching/sessions/:id` | Speed dating session detail |
| `POST` | `/api/v1/matching/sessions/:id/messages` | Send message in session |
| `GET` | `/api/v1/matching/matches` | List permanent matches |
| `POST` | `/api/v1/matching/matches/:id/messages` | Send message to match |
| `DELETE` | `/api/v1/users/me` | Delete account (soft delete + Apple revocation) |

---

## Deployment

Containerized on Google Cloud Run via Cloud Build.

```bash
bash upload_gcp.sh
```

The Docker image exposes port `8080` on a `node:20` base image.
