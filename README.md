# weVibe

iOS dating app with a Node.js/Express backend.

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

### API Endpoints

| Method | Path | Description |
|--------|------|-------------|
| `POST` | `/api/v1/auth/register` | Register with Firebase token |
| `POST` | `/api/v1/auth/login` | Login with Firebase token |
| `POST` | `/api/v1/auth/logout` | Logout (Bearer token required) |
| `GET` | `/api/v1/auth/me` | Get current user (Bearer token required) |
| `GET` | `/api/v1/users/profile` | Get own profile |
| `PATCH` | `/api/v1/users/profile` | Update own profile |
| `PATCH` | `/api/v1/users/fcm-token` | Update FCM push notification token |

### Folder Structure

```
backend/src/
  routes/         Route definitions
  controllers/    Request/response handling + validation
  services/       Business logic
  repositories/   Database query layer (Prisma)
  middleware/     Auth, error handling
  websocket/      Socket.IO server + Redis pub/sub
  db/             Schema and DB setup
  utils/          Shared helpers
  config/         Environment config
```
