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
