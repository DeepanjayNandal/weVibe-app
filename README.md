# weVibe

iOS dating app with a Node.js/Express backend.

---

## iOS App

### Requirements

- Xcode 16 or later
- iOS 17.6+ deployment target
- macOS Sonoma or later
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) — `brew install xcodegen`

> The Xcode project (`WeVibe.xcodeproj`) is not checked in. It is generated locally from
> [frontend/iOS/project.yml](frontend/iOS/project.yml) via XcodeGen.

### Setup

1. **Install XcodeGen** (one-time)
   ```bash
   brew install xcodegen
   ```

2. **Activate git hooks** (one-time) — auto-regenerates the project when `project.yml` changes after a pull or branch switch
   ```bash
   git config core.hooksPath .githooks
   ```

3. **Generate the Xcode project**
   ```bash
   cd frontend/iOS && xcodegen generate
   ```

4. **Add Firebase config files** (git-ignored — get from team)
   ```
   frontend/iOS/WeVibe/Firebase/GoogleService-Info-Dev.plist   ← Debug builds
   frontend/iOS/WeVibe/Firebase/GoogleService-Info-Prod.plist  ← Release builds
   ```

5. **Open and build**
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

### Architecture

| Layer | Description |
|-------|-------------|
| `AppState` | Enum driving the entire view hierarchy via `RootView` |
| `AuthManager` | Firebase Auth — email/password and Google Sign-In |
| `UserProfileStore` | In-memory profile state — fetched from backend, no local caching |
| `OnboardingData` | Onboarding flow state |
| `APIClient` | All REST calls to the backend |

---

## Backend

Node.js/Express API serving the iOS app.

### Requirements

- Node.js v20.x
- npm v10+
- PostgreSQL v14+

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
   | `APPLE_TEAM_ID` | Apple Developer Team ID — `49DV8UBRZK` (required for Apple token revocation) |
   | `APPLE_KEY_ID` | Sign in with Apple key ID from Apple Developer portal |
   | `APPLE_PRIVATE_KEY` | Contents of the `.p8` private key — encode newlines as `\n` in `.env` |

   **Firebase service account files** (required when `AUTH_PROVIDER_MODE=firebase`):
   ```
   backend/secrets/firebase-service-account-dev.json   ← dev
   backend/secrets/firebase-service-account-prod.json  ← prod
   ```
   These are gitignored — get them from a team member.

3. **Set up database**
   ```bash
   npm run db:start                                        # start PostgreSQL (Docker)
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
| `DELETE` | `/api/v1/users/me` | Delete account (30-day soft delete + Apple token revocation) |

### Folder Structure

```
backend/src/
  routes/         Route definitions
  controllers/    Request/response handling + validation
  services/       Business logic
  repositories/   Database query layer (Prisma)
  middleware/     Auth, error handling
  db/             Schema and DB setup
  utils/          Shared helpers
  config/         Environment config
```
