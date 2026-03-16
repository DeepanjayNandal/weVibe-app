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

- `GET /health`
- `POST /api/v1/auth/register`
- `POST /api/v1/auth/login`
- `POST /api/v1/auth/logout` (requires bearer token)
- `GET /api/v1/auth/me` (requires bearer token)
- `POST /api/v1/users/profile` (requires bearer token)
- `POST /api/v1/matching/queue/join` (requires bearer token)
- `POST /api/v1/matching/queue/leave` (requires bearer token)
- `GET /api/v1/matching/queue/status` (requires bearer token)

Detailed endpoint contracts, request/response examples, and auth notes:

- `docs/api-contract.md`



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
   > Ensure the database is running on (`npm run db:start`) to pass connectivity tests.

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
   npx prisma studio --schema=src/db/schema.prisma
   npx prisma db push --schema=src/db/schema.prisma
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
