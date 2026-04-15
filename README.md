# weVibe

iOS dating app (SwiftUI) with a Node.js/Express backend — speed dating sessions, permanent matches, real-time messaging, and profile-driven matchmaking.

---

## Project Structure

```
weVibe-app/
  frontend/iOS/       SwiftUI app (XcodeGen-generated Xcode project)
  backend/            Node.js/Express API (TypeScript, Prisma, Socket.IO)
  docs/               API contracts and design docs
```

Sub-workspace guides:
- [frontend/iOS/CLAUDE.md](frontend/iOS/CLAUDE.md) — iOS architecture, state machine, conventions
- [backend/CLAUDE.md](backend/CLAUDE.md) — backend architecture, API endpoints, conventions

---

## iOS App

### Requirements

- Xcode 16 or later
- iOS 17.0+ deployment target
- macOS Sonoma or later
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) — `brew install xcodegen`
- [fastlane](https://fastlane.tools) — `brew install fastlane`

> The Xcode project (`WeVibe.xcodeproj`) is not checked in. It is generated locally from
> [frontend/iOS/project.yml](frontend/iOS/project.yml) via XcodeGen.

### Setup

1. **Install tools** (one-time)
   ```bash
   brew install xcodegen fastlane
   ```

2. **Activate git hooks** (one-time) — auto-regenerates the project when `project.yml` changes after a pull or branch switch
   ```bash
   git config core.hooksPath .githooks
   ```

3. **Sync certificates and provisioning profiles** (one-time)
   ```bash
   cd frontend/iOS && bundle install && bundle exec fastlane sync_dev
   ```
   You will need the **Match encryption passphrase** — get it from the team.

4. **Add Firebase config files** (git-ignored — get from team)
   ```
   frontend/iOS/WeVibe/Firebase/GoogleService-Info-Dev.plist   ← Debug builds
   frontend/iOS/WeVibe/Firebase/GoogleService-Info-Prod.plist  ← Release builds
   ```

5. **Generate the Xcode project**
   ```bash
   cd frontend/iOS && xcodegen generate
   ```

6. **Open and build**
   ```bash
   open frontend/iOS/WeVibe.xcodeproj
   ```
   Press **Cmd + R**, select an iOS 17+ simulator or device.

### Regenerating the project

If you modify `project.yml` (add files, change build settings, add dependencies), regenerate with:
```bash
cd frontend/iOS && xcodegen generate
```
The git hooks handle this automatically after pulls and branch switches.

### TestFlight

```bash
cd frontend/iOS && bundle exec fastlane beta
```

Requires `fastlane/api_key.json` (git-ignored) — get it from the team.

### Adding your device

Add your iPhone UDID to `frontend/iOS/fastlane/devices.txt`, then:
```bash
cd frontend/iOS && bundle exec fastlane add_device
```

### Architecture

| Layer | Description |
|-------|-------------|
| `AppState` | Enum driving the entire view hierarchy via `RootView` |
| `AuthManager` | Firebase Auth — email/password, Google Sign-In, Apple Sign-In |
| `UserProfileStore` | In-memory profile state — fetched from backend, no local caching |
| `OnboardingData` | Onboarding survey draft — persisted to disk |
| `LocationManager` | CLLocationManager wrapper — reverse geocodes and syncs to backend |
| `SocketService` | Socket.IO client — real-time messaging and match events |
| `MatchmakingService` | Speed dating queue join/leave + match-found coordination |
| `APIClient` | All REST calls to the backend |
| `ChatAPIClient` | REST calls for speed-dating and permanent chat |

### SPM Dependencies

| Package | Version |
|---------|---------|
| `firebase-ios-sdk` | >= 12.10.0 |
| `GoogleSignIn-iOS` | >= 9.1.0 |
| `socket.io-client-swift` | >= 16.1.0 |

---

## Backend

Node.js/Express API serving the iOS app.

### Requirements

- Node.js v20.x
- npm v10+
- Docker (for PostgreSQL + Redis)

### Setup

1. **Install dependencies**
   ```bash
   cd backend && npm ci
   ```

2. **Configure environment**
   ```bash
   cp .env.example .env
   ```

   Edit `.env` with the following required values:

   | Variable | Description |
   |----------|-------------|
   | `DATABASE_URL` | PostgreSQL connection string — `postgresql://admin:password@localhost:5432/wevibe_dev` |
   | `AUTH_PROVIDER_MODE` | `firebase` for real auth (requires service account), `mock` for local testing without Firebase |
   | `FIREBASE_PROJECT_ID` | Firebase project ID — `wevibe-dev` (dev) or `wevibe-prod` (prod) |
   | `GOOGLE_APPLICATION_CREDENTIALS` | Path to Firebase service account JSON — place in `backend/secrets/` (gitignored) |
   | `PORT` | API port — defaults to `3000` |
   | `APPLE_TEAM_ID` | Apple Developer Team ID |
   | `APPLE_KEY_ID` | Sign in with Apple key ID (from Apple Developer portal) |
   | `APPLE_PRIVATE_KEY` | Contents of the `.p8` private key file — encode newlines as `\n` in `.env` |

   **Firebase service account files** (required when `AUTH_PROVIDER_MODE=firebase`):
   ```
   backend/secrets/firebase-service-account-dev.json   ← dev
   backend/secrets/firebase-service-account-prod.json  ← prod
   ```
   These are gitignored — get them from a team member.

3. **Set up database**
   ```bash
   npm run db:start                                        # start PostgreSQL + Redis (Docker)
   npm run db:push                                         # apply schema
   npx prisma generate --schema src/db/schema.prisma      # generate Prisma client
   npm run db:seed                                         # optional: seed fake data
   ```

4. **Start the server**
   ```bash
   npm start
   # → API server running on port 3000
   ```

5. **Run tests**
   ```bash
   npm test
   ```

### Backend Scripts

| Command | Description |
|---------|-------------|
| `npm start` | Start the API server (`ts-node src/server.ts`) |
| `npm test` | Run Jest test suite |
| `npm run db:start` | Start PostgreSQL + Redis via Docker Compose |
| `npm run db:stop` | Stop Docker services |
| `npm run db:push` | Apply Prisma schema to the database |
| `npm run db:generate` | Regenerate Prisma client |
| `npm run db:seed` | Seed the database with fake data |
| `npm run db:setup` | Initial database setup |

### API Endpoints

**Auth**

| Method | Path | Description |
|--------|------|-------------|
| `POST` | `/api/v1/auth/register` | Create backend user after Firebase registration |
| `POST` | `/api/v1/auth/login` | Login / upsert backend user after Firebase sign-in |
| `POST` | `/api/v1/auth/logout` | Logout (Bearer token required) |
| `GET` | `/api/v1/auth/me` | Get current user auth state |

**Profile**

| Method | Path | Description |
|--------|------|-------------|
| `POST` | `/api/v1/users/profile` | Submit onboarding data, create profile |
| `GET` | `/api/v1/users/profile` | Fetch full profile |
| `PATCH` | `/api/v1/users/profile` | Update profile fields (partial) |
| `POST` | `/api/v1/users/profile/photos/upload-url` | Get signed GCS PUT URL |
| `POST` | `/api/v1/users/profile/photos/finalize` | Confirm upload, write photo record |
| `DELETE` | `/api/v1/users/profile/photos/:photoId` | Delete photo |
| `PATCH` | `/api/v1/users/profile/photos/reorder` | Update photo display order |
| `POST` | `/api/v1/users/profile/personality` | Submit personality test answers |

**Matchmaking / Queue**

| Method | Path | Description |
|--------|------|-------------|
| `POST` | `/api/v1/matching/queue/join` | Join speed-dating queue |
| `POST` | `/api/v1/matching/queue/leave` | Leave queue |
| `GET` | `/api/v1/matching/queue/status` | Queue status |
| `GET` | `/api/v1/matching/sessions` | List active speed-dating sessions |

**Speed Dating Sessions**

| Method | Path | Description |
|--------|------|-------------|
| `GET` | `/api/v1/matching/sessions/:sessionId` | Session detail |
| `GET` | `/api/v1/matching/sessions/:sessionId/messages` | Session message history |
| `POST` | `/api/v1/matching/sessions/:sessionId/messages` | Send message |
| `PATCH` | `/api/v1/matching/sessions/:sessionId/read` | Mark session messages read |
| `POST` | `/api/v1/matching/sessions/:sessionId/move-to-permanent/request` | Request permanent match |
| `POST` | `/api/v1/matching/sessions/:sessionId/move-to-permanent/respond` | Respond to permanent match request |
| `POST` | `/api/v1/matching/sessions/:sessionId/final-decision` | Submit final like/pass decision |
| `POST` | `/api/v1/matching/sessions/:sessionId/end` | End session early |

**Permanent Chat (Matches)**

| Method | Path | Description |
|--------|------|-------------|
| `GET` | `/api/v1/matching/matches` | List permanent matches |
| `GET` | `/api/v1/matching/matches/:matchId` | Match detail |
| `GET` | `/api/v1/matching/matches/:matchId/messages` | Match message history |
| `GET` | `/api/v1/matching/matches/:matchId/profile` | Matched user's profile |
| `PATCH` | `/api/v1/matching/matches/:matchId/read` | Mark match messages read |
| `POST` | `/api/v1/matching/matches/:matchId/messages` | Send message |
| `POST` | `/api/v1/matching/matches/:matchId/remove` | Remove match |
| `POST` | `/api/v1/matching/matches/:matchId/block` | Block counterpart |
| `POST` | `/api/v1/matching/matches/:matchId/report` | Report counterpart |

**Account**

| Method | Path | Description |
|--------|------|-------------|
| `PATCH` | `/api/v1/users/fcm-token` | Store/refresh device FCM token |
| `GET` | `/api/v1/matching/chats/badges` | Unread badge counts |
| `DELETE` | `/api/v1/users/me` | Soft-delete account (30-day grace period) |

Full API contract: [docs/api-contract.md](docs/api-contract.md)

### WebSocket (Socket.IO)

The backend runs Socket.IO with a Redis adapter for horizontal scaling. Authentication uses a Firebase Bearer token passed during handshake.

**Client → Server**

| Event | Payload | Description |
|-------|---------|-------------|
| `typing` | `{ chatType, chatId, isTyping }` | Relay typing indicator to peer |
| `ping` | — | Keepalive |

**Server → Client**

| Event | Payload | Description |
|-------|---------|-------------|
| `matching.queue.matched` | `{ sessionId }` | Match found |
| `speed_dating.message.created` | `{ sessionId, message }` | Incoming speed-dating message |
| `speed_dating.typing.updated` | `{ sessionId, userId, isTyping }` | Typing indicator |
| `speed_dating.session.ended` | `{ sessionId }` | Session expired or ended |
| `permanent.message.created` | `{ matchId, message }` | Incoming permanent-chat message |
| `error` | `{ code, message }` | Server-side error |

### Folder Structure

```
backend/src/
  routes/         Route definitions
  controllers/    Request/response handling + validation
  services/       Business logic
  repositories/   Database query layer (Prisma)
  middleware/     Auth, error handling
  websocket/      Socket.IO server + Redis pub/sub
  db/             Schema (src/db/schema.prisma) and DB setup
  utils/          Shared helpers (errors.ts — AppError factories)
  config/         Environment config (env.ts)
  types/          Shared type definitions
```

### Deployment

The backend is containerized. Cloud Build (`cloudbuild.yaml`) builds and pushes a Docker image to Google Container Registry on every push.

```bash
# Local container build
docker build -t wevibe-api ./backend
```

The Docker image exposes port `8080` and uses `node:20` as the base image.
