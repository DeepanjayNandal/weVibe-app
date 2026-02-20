# WeVibe Backend

Unified Node.js backend for WeVibe — serves both the web frontend and iOS app from a single API.

## Runtime Requirements

- Node.js v20.x
- npm v10+
- PostgreSQL v14+

## Architecture

Single Express API serving all clients (Next.js web, Swift iOS).
Routes delegate to controllers, which call services for business logic.
Repositories handle all direct database queries via Prisma Client.

## Auth API (Firebase-ready with Mock Verifier)

Current implementation supports providers: `google`, `apple`, `facebook`, `twitter`, `email`.

- `POST /api/v1/auth/register`
- `POST /api/v1/auth/login`
- `POST /api/v1/auth/logout` (requires `Authorization: Bearer <idToken>`, returns `204`)
- `GET /api/v1/auth/me` (requires bearer token)

### Request Body for register/login

```json
{
   "provider": "google",
   "idToken": "mock:google:uid-123:user@example.com"
}
```

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
   npm install
   ```

2. **Start Database (Docker)**
   ```bash
   npm run db:start
   ```

3. **Apply Schema to Database**
   Push the schema defined in `src/db/schema.prisma` to the database:
   ```bash
   npm run db:push
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
