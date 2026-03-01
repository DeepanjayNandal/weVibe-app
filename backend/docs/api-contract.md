# WeVibe API Contract

**Base URL:** `http://localhost:3000/api/v1`
**Owner:** Backend Team

---

## Authentication Flow (Important for Frontend Team)

Firebase issues the `idToken` **on the client side** after the user signs in (Google, Apple, email/password). The Swift app is responsible for obtaining this token from Firebase SDK and sending it to the backend. The backend does **not** issue tokens — it only verifies them.

```
Swift App
  → Firebase SDK (sign in with Google / Apple / email)
  → Firebase returns idToken (JWT)
  → Swift sends idToken to backend endpoint
  → Backend verifies token + creates/fetches user in PostgreSQL
```

For local development (no Firebase credentials), use mock tokens in the format:
```
mock:<provider>:<uid>:<email>
Example: mock:google:uid123:user@example.com
```
Set `AUTH_PROVIDER_MODE=mock` in `.env` to enable this.

---

## Endpoints

### 1. Register

Creates a new user account. Fails if the Firebase UID or email already exists.

```
POST /api/v1/auth/register
Content-Type: application/json
```

**Request Body**
```json
{
  "provider": "google",
  "idToken": "<firebase-id-token>"
}
```

| Field | Type | Required | Values |
|---|---|---|---|
| `provider` | string | yes | `google`, `apple`, `facebook`, `twitter`, `email` |
| `idToken` | string | yes | Firebase ID token from client-side sign-in |

**Response 201 — Success**
```json
{
  "success": true,
  "data": {
    "user": {
      "id": "uuid",
      "email": "user@example.com",
      "phone": null,
      "firebaseUid": "firebase-uid",
      "authProvider": "google",
      "createdAt": "2025-01-01T00:00:00.000Z",
      "lastActiveAt": null,
      "isBanned": false
    }
  }
}
```

**Error Responses**

| Status | `error.code` | Cause |
|---|---|---|
| 400 | `INVALID_PROVIDER` | Provider is not one of the allowed values |
| 400 | `MISSING_ID_TOKEN` | `idToken` missing or empty string |
| 401 | `INVALID_ID_TOKEN` | Token failed Firebase/mock verification |
| 409 | `USER_ALREADY_EXISTS` | Firebase UID already registered |
| 409 | `EMAIL_ALREADY_EXISTS` | Email already registered with a different provider |

---

### 2. Login

Fetches an existing user. Creates one automatically on first social login (Google/Apple) if not found.

```
POST /api/v1/auth/login
Content-Type: application/json
```

**Request Body**
```json
{
  "provider": "google",
  "idToken": "<firebase-id-token>"
}
```

| Field | Type | Required | Values |
|---|---|---|---|
| `provider` | string | yes | `google`, `apple`, `facebook`, `twitter`, `email` |
| `idToken` | string | yes | Firebase ID token from client-side sign-in |

**Response 200 — Success**
```json
{
  "success": true,
  "data": {
    "user": {
      "id": "uuid",
      "email": "user@example.com",
      "phone": null,
      "firebaseUid": "firebase-uid",
      "authProvider": "google",
      "createdAt": "2025-01-01T00:00:00.000Z",
      "lastActiveAt": "2025-01-01T00:00:00.000Z",
      "isBanned": false
    }
  }
}
```

**Error Responses**

| Status | `error.code` | Cause |
|---|---|---|
| 400 | `INVALID_PROVIDER` | Provider is not one of the allowed values |
| 400 | `MISSING_ID_TOKEN` | `idToken` missing or empty string |
| 401 | `INVALID_ID_TOKEN` | Token failed Firebase/mock verification |
| 403 | `USER_BANNED` | User account is banned |

---

### 3. Get Current User

Returns the authenticated user's account data.

```
GET /api/v1/auth/me
Authorization: Bearer <firebase-id-token>
```

**Response 200 — Success**
```json
{
  "success": true,
  "data": {
    "user": {
      "id": "uuid",
      "email": "user@example.com",
      "phone": null,
      "firebaseUid": "firebase-uid",
      "authProvider": "google",
      "createdAt": "2025-01-01T00:00:00.000Z",
      "lastActiveAt": "2025-01-01T00:00:00.000Z",
      "isBanned": false
    }
  }
}
```

**Error Responses**

| Status | `error.code` | Cause |
|---|---|---|
| 401 | `MISSING_BEARER_TOKEN` | No `Authorization` header or not `Bearer` format |
| 401 | `INVALID_ID_TOKEN` | Token failed Firebase/mock verification |
| 401 | `USER_NOT_FOUND` | Verified token but no matching user in DB |
| 403 | `USER_BANNED` | User account is banned |

---

### 4. Logout

Stateless logout. Verifies the token is valid and returns 204. Firebase session revocation is handled client-side.

```
POST /api/v1/auth/logout
Authorization: Bearer <firebase-id-token>
```

**Response 204 — Success**

No body.

**Error Responses**

| Status | `error.code` | Cause |
|---|---|---|
| 401 | `MISSING_BEARER_TOKEN` | No `Authorization` header or not `Bearer` format |
| 401 | `INVALID_ID_TOKEN` | Token failed Firebase/mock verification |

---

### 5. Create Profile

Creates the dating profile for an authenticated user. Must be called after `/auth/register`.
`first_name` and `last_name` are concatenated into `display_name` on the backend.

```
POST /api/v1/users/profile
Authorization: Bearer <firebase-id-token>
Content-Type: application/json
```

**Request Body**
```json
{
  "first_name": "Alice",
  "last_name": "Smith",
  "birth_date": "1998-05-20",
  "gender": "Female"
}
```

| Field | Type | Required | Values |
|---|---|---|---|
| `first_name` | string | yes | Any non-empty string |
| `last_name` | string | yes | Any non-empty string |
| `birth_date` | string | yes | ISO date format `YYYY-MM-DD` |
| `gender` | string | yes | `Male`, `Female`, `Non-binary`, `Prefer not to say` |

**Response 201 — Success**
```json
{
  "success": true,
  "data": {
    "profile": {
      "userId": "uuid",
      "displayName": "Alice Smith",
      "birthDate": "1998-05-20T00:00:00.000Z",
      "gender": "Female"
    }
  }
}
```

**Error Responses**

| Status | `error.code` | Cause |
|---|---|---|
| 400 | `MISSING_FIRST_NAME` | `first_name` missing or empty |
| 400 | `MISSING_LAST_NAME` | `last_name` missing or empty |
| 400 | `MISSING_BIRTH_DATE` | `birth_date` missing or empty |
| 400 | `INVALID_BIRTH_DATE` | `birth_date` not a valid date |
| 400 | `INVALID_AGE` | User is under 18 years old |
| 400 | `MISSING_GENDER` | `gender` missing or empty |
| 400 | `INVALID_GENDER` | `gender` not one of the allowed values |
| 401 | `MISSING_BEARER_TOKEN` | No `Authorization` header or not `Bearer` format |
| 401 | `INVALID_ID_TOKEN` | Token failed Firebase/mock verification |
| 401 | `USER_NOT_FOUND` | Verified token but no matching user in DB |
| 409 | `PROFILE_ALREADY_EXISTS` | Profile already created for this user |

---

### 6. Get Profile *(coming — Sprint 2)*

> **Status:** In progress. Endpoint not yet available.
> Returns the authenticated user's dating profile.

```
GET /api/v1/users/profile
Authorization: Bearer <firebase-id-token>
```

---

## Error Response Shape

All errors follow this structure:

```json
{
  "success": false,
  "error": {
    "message": "Human readable message",
    "code": "MACHINE_READABLE_CODE"
  }
}
```

---

## Health Check

```
GET /health
```

**Response 200**
```json
{
  "success": true,
  "data": { "status": "ok" }
}
```
