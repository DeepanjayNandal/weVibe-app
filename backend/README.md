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

1. **Install Dependencies**
   ```bash
   npm ci
   ```

2. **Start Database (Docker)**
   ```bash
   npm run db:start
   ```

3. **Apply Schema to Database**
   This will drop the existing database (if any) and recreate it using `src/db/schema.sql`:
   ```bash
   node src/db/setup-db.js
   ```

   > **Note (schema changes):** The Prisma schema (`src/db/schema.prisma`) has been updated with new
   > profile columns (first_name, last_name, height_unit, height_ft, height_in, location_city,
   > latitude, longitude, bio, relationship_goals, meet_preference, min/max_age_preference,
   > distance_preference_miles). To apply these to your local database run:
   > ```bash
   > npx prisma migrate dev
   > ```
   > or if you just want to push without creating a migration file:
   > ```bash
   > npx prisma db push
   > ```

4. **Generate Prisma Client**
   ```bash
   npm run db:generate
   ```

5. **Seed Fake Data**
   ```bash
   npm run db:seed
   ```

6. **Run Tests**
   ```bash
   npm install firebase-admin
   npm test
   ```
   > Ensure the database is running (`npm run db:start`) to pass connectivity tests.

7. **Check Connection (Optional)**
   ```bash
   npm run db:check
   ```

8. **Run API Server**
   ```bash
   npm start
   ```

9. **Inspect Database (Prisma Studio)**
   Launch a visual editor to view and edit your data:
   ```bash
   npx prisma studio
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
