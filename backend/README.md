# WeVibe Backend

Unified Node.js backend for WeVibe — serves both the web frontend and iOS app from a single API.

## Runtime Requirements

- Node.js v20.x
- npm v10+
- PostgreSQL v14+

## Architecture

Single Express API serving all clients (Next.js web, Swift iOS).
Routes delegate to controllers, which call services for business logic.
Repositories handle all direct database queries via pg.

## API Overview

Current implementation supports three providers: `google`, `apple`, `email`.

| Method | Endpoint | Auth | Description |
|--------|----------|------|-------------|
| GET | `/health` | No | Health check |
| POST | `/api/v1/auth/register` | Bearer | Create user row from Firebase token |
| POST | `/api/v1/auth/login` | Bearer | Verify token, return user record |
| POST | `/api/v1/auth/logout` | Bearer | Logout |
| GET | `/api/v1/auth/me` | Bearer | Get current user |
| POST | `/api/v1/users/profile` | Bearer | Submit full onboarding survey — creates profile |
| GET | `/api/v1/users/profile` | Bearer | Get profile (401 PROFILE_NOT_FOUND if not created yet) |
| PATCH | `/api/v1/users/profile` | Bearer | Partial profile update — only fields sent are updated |
| POST | `/api/v1/matching/queue/join` | Bearer | Join matchmaking queue |
| POST | `/api/v1/matching/queue/leave` | Bearer | Leave matchmaking queue |
| GET | `/api/v1/matching/queue/status` | Bearer | Check queue status |

For full request/response shapes and field-level docs see `API_SPEC.md` (project root).
For enum values accepted by the API see `ENUM_REFERENCE.md` (project root).



### Mock Token Rules (Local Development)

When `AUTH_PROVIDER_MODE=mock`, backend accepts this token format:

`mock:<provider>:<uid>:<email>`

Examples:

- `mock:google:g-001:alice@gmail.com`
- `mock:apple:a-001:bob@icloud.com`
- `mock:email:e-001:charlie@example.com`

## Database Setup & Testing

Run all commands from the `weVibe-app/` directory using `--prefix backend`.

1. **Install Dependencies**
   ```bash
   npm ci --prefix backend
   ```

2. **Open Docker Desktop** (the app on your Mac — must be running before any DB commands)

3. **Start Database (Docker)**
   ```bash
   npm run db:start --prefix backend
   ```

4. **Create DB and apply schema**
   ```bash
   docker exec -i wevibe_postgres psql -U admin -d template1 -c "CREATE DATABASE wevibe_dev;"
   docker exec -i wevibe_postgres psql -U admin -d wevibe_dev < backend/src/db/schema.sql
   ```

   > **Port conflict (Mac only):** If you have a local Postgres already running on port 5432, it will
   > block the Docker container. Stop it first:
   > ```bash
   > launchctl unload ~/Library/LaunchAgents/homebrew.mxcl.postgresql@14.plist
   > ```

5. **Sync Prisma schema → DB** (adds all new columns from `schema.prisma`)
   ```bash
   cd backend && npx prisma db push --schema=src/db/schema.prisma
   ```

6. **Set auth mode for local testing**
   In `backend/.env`, set:
   ```
   AUTH_PROVIDER_MODE=mock
   ```

7. **Run API Server**
   ```bash
   npm start --prefix backend
   ```

8. **Test with mock auth**
   ```bash
   # Register a user
   curl -X POST http://localhost:3000/api/v1/auth/register \
     -H "Content-Type: application/json" \
     -d '{"provider": "google", "idToken": "mock:google:g-001:alice@gmail.com"}'

   # Get profile (returns PROFILE_NOT_FOUND until onboarding POST is done)
   curl http://localhost:3000/api/v1/users/profile \
     -H "Authorization: Bearer mock:google:g-001:alice@gmail.com"
   ```

9. **Inspect Database (Prisma Studio)**
   ```bash
   cd backend && npx prisma studio --schema=src/db/schema.prisma
   ```

10. **Check Connection (Optional)**
    ```bash
    npm run db:check --prefix backend
    ```

## Folder Structure

```
src/
  routes/        API route definitions
  controllers/   Request/response handling
  services/      Business logic
  repositories/  Database query layer
  middleware/    Auth, error handling
  db/            DB connection and setup
  utils/         Shared helpers
  config/        Environment and app config

tests/           Test suites
docs/            API and architecture docs
```
