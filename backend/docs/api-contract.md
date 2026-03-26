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

### 6. Get Profile

Returns the authenticated user's dating profile.

```
GET /api/v1/users/profile
Authorization: Bearer <firebase-id-token>
```

**Response 200 — Success**
```json
{
  "success": true,
  "data": {
    "profile": {
      "userId": "uuid",
      "displayName": "Alice Smith",
      "birthDate": "1998-05-20T00:00:00.000Z",
      "gender": "Female",
      "personality_type": "Serene Soul",
      "personality_primary": "A",
      "personality_secondary": null,
      "is_personality_test_complete": true
    }
  }
}
```

> `personality_type`, `personality_primary`, `personality_secondary` are `null` until the personality test is submitted.
> `is_personality_test_complete` is `false` until the test is submitted.

**Error Responses**

| Status | `error.code` | Cause |
|---|---|---|
| 401 | `MISSING_BEARER_TOKEN` | No `Authorization` header or not `Bearer` format |
| 401 | `INVALID_ID_TOKEN` | Token failed Firebase/mock verification |
| 401 | `USER_NOT_FOUND` | Verified token but no matching user in DB |
| 401 | `PROFILE_NOT_FOUND` | User exists but has no profile yet |

---

### 7. Join Matching Queue

Adds the authenticated user to the matching queue and tries to match immediately.

```
POST /api/v1/matching/queue/join
Authorization: Bearer <firebase-id-token>
```

**Response 200 — Waiting**
```json
{
  "success": true,
  "data": {
    "state": "waiting",
    "queueJoinedAt": "2026-01-01T00:00:00.000Z",
    "poolSize": 0
  }
}
```

**Response 200 — Matched**
```json
{
  "success": true,
  "data": {
    "state": "matched",
    "queueJoinedAt": "2026-01-01T00:00:00.000Z",
    "poolSize": 1,
    "selectedCandidate": {
      "userId": "uuid",
      "displayName": "Alice Smith",
      "scoreForward": 82,
      "scoreBackward": 79,
      "scoreCombined": 80.5
    },
    "sessionId": "uuid",
    "sessionExpiresAt": "2026-01-02T00:00:00.000Z"
  }
}
```

**Error Responses**

| Status | `error.code` | Cause |
|---|---|---|
| 400 | `PROFILE_REQUIRED` | User must complete profile before queue join |
| 400 | `QUEUE_JOIN_FAILED` | Queue entry could not be created |
| 401 | `MISSING_BEARER_TOKEN` | No `Authorization` header or not `Bearer` format |
| 401 | `INVALID_ID_TOKEN` | Token failed Firebase/mock verification |
| 401 | `USER_NOT_FOUND` | Verified token but no matching user in DB |

---

### 8. Leave Matching Queue

Removes the authenticated user from the matching queue.

```
POST /api/v1/matching/queue/leave
Authorization: Bearer <firebase-id-token>
```

**Response 200 — Success**
```json
{
  "success": true,
  "data": {
    "state": "left_queue"
  }
}
```

**Error Responses**

| Status | `error.code` | Cause |
|---|---|---|
| 401 | `MISSING_BEARER_TOKEN` | No `Authorization` header or not `Bearer` format |
| 401 | `INVALID_ID_TOKEN` | Token failed Firebase/mock verification |
| 401 | `USER_NOT_FOUND` | Verified token but no matching user in DB |

---

### 9. Get Matching Queue Status

Returns whether the authenticated user is currently in queue.

```
GET /api/v1/matching/queue/status
Authorization: Bearer <firebase-id-token>
```

**Response 200 — Success**
```json
{
  "success": true,
  "data": {
    "inQueue": true
  }
}
```

**Error Responses**

| Status | `error.code` | Cause |
|---|---|---|
| 401 | `MISSING_BEARER_TOKEN` | No `Authorization` header or not `Bearer` format |
| 401 | `INVALID_ID_TOKEN` | Token failed Firebase/mock verification |
| 401 | `USER_NOT_FOUND` | Verified token but no matching user in DB |

---

### 10. List Permanent Matches

Returns all permanent chat matches for the authenticated user.

```
GET /api/v1/matching/matches
Authorization: Bearer <firebase-id-token>
```

**Response 200 — Success**
```json
{
  "success": true,
  "data": {
    "matches": [
      {
        "matchId": "uuid",
        "status": "active",
        "createdAt": "2026-01-01T00:00:00.000Z",
        "lastMessageAt": "2026-01-01T00:10:00.000Z",
        "lastMessageContent": "Hello",
        "messageCount": 24,
        "canOpen": true,
        "canSendMessage": true,
        "unreadCount": 2,
        "counterpart": {
          "userId": "uuid",
          "displayName": "Alice Smith",
          "photoUrl": "https://..."
        }
      }
    ]
  }
}
```

**Error Responses**

| Status | `error.code` | Cause |
|---|---|---|
| 401 | `MISSING_BEARER_TOKEN` | No `Authorization` header or not `Bearer` format |
| 401 | `INVALID_ID_TOKEN` | Token failed Firebase/mock verification |
| 401 | `USER_NOT_FOUND` | Verified token but no matching user in DB |

---

### 11. Get Permanent Match Detail

Returns one permanent match conversation summary.

```
GET /api/v1/matching/matches/:matchId
Authorization: Bearer <firebase-id-token>
```

**Response 200 — Success**
```json
{
  "success": true,
  "data": {
    "match": {
      "matchId": "uuid",
      "status": "active",
      "createdAt": "2026-01-01T00:00:00.000Z",
      "lastMessageAt": "2026-01-01T00:10:00.000Z",
      "lastMessageContent": "Hello",
      "messageCount": 24,
      "canOpen": true,
      "canSendMessage": true,
      "unreadCount": 2,
      "counterpart": {
        "userId": "uuid",
        "displayName": "Alice Smith",
        "photoUrl": "https://..."
      }
    }
  }
}
```

**Error Responses**

| Status | `error.code` | Cause |
|---|---|---|
| 400 | `MISSING_MATCH_ID` | `matchId` path param is missing or empty |
| 401 | `MISSING_BEARER_TOKEN` | No `Authorization` header or not `Bearer` format |
| 401 | `INVALID_ID_TOKEN` | Token failed Firebase/mock verification |
| 401 | `USER_NOT_FOUND` | Verified token but no matching user in DB |
| 403 | `CHAT_FORBIDDEN` | User is not a participant of this match |
| 404 | `MATCH_NOT_FOUND` | Match does not exist |

---

### 12. Get Permanent Match Messages

Returns one permanent match plus all messages in chronological order.

```
GET /api/v1/matching/matches/:matchId/messages
Authorization: Bearer <firebase-id-token>
```

**Response 200 — Success**
```json
{
  "success": true,
  "data": {
    "match": {
      "matchId": "uuid",
      "status": "active",
      "messageCount": 24
    },
    "messages": [
      {
        "id": "1",
        "matchId": "uuid",
        "senderId": "uuid",
        "content": "Hello",
        "createdAt": "2026-01-01T00:00:10.000Z",
        "readAt": null
      }
    ]
  }
}
```

**Error Responses**

| Status | `error.code` | Cause |
|---|---|---|
| 400 | `MISSING_MATCH_ID` | `matchId` path param is missing or empty |
| 401 | `MISSING_BEARER_TOKEN` | No `Authorization` header or not `Bearer` format |
| 401 | `INVALID_ID_TOKEN` | Token failed Firebase/mock verification |
| 401 | `USER_NOT_FOUND` | Verified token but no matching user in DB |
| 403 | `CHAT_FORBIDDEN` | User is not a participant of this match |
| 404 | `MATCH_NOT_FOUND` | Match does not exist |

---

### 13. Mark Permanent Match Messages Read

Marks all unread incoming messages in a permanent match as read for the authenticated user.

```
PATCH /api/v1/matching/matches/:matchId/read
Authorization: Bearer <firebase-id-token>
```

**Response 200 - Success**
```json
{
  "success": true,
  "data": {
    "match": {
      "matchId": "uuid",
      "status": "active",
      "unreadCount": 0
    }
  }
}
```

**Error Responses**

| Status | `error.code` | Cause |
|---|---|---|
| 400 | `MISSING_MATCH_ID` | `matchId` path param is missing or empty |
| 401 | `MISSING_BEARER_TOKEN` | No `Authorization` header or not `Bearer` format |
| 401 | `INVALID_ID_TOKEN` | Token failed Firebase/mock verification |
| 401 | `USER_NOT_FOUND` | Verified token but no matching user in DB |
| 403 | `CHAT_FORBIDDEN` | User is not a participant of this match |
| 404 | `MATCH_NOT_FOUND` | Match does not exist |

---

### 14. Send Permanent Match Message

Sends one message in an active permanent match.

```
POST /api/v1/matching/matches/:matchId/messages
Authorization: Bearer <firebase-id-token>
Content-Type: application/json
```

**Request Body**
```json
{
  "content": "Hello"
}
```

**Response 201 — Success**
```json
{
  "success": true,
  "data": {
    "message": {
      "id": "1",
      "matchId": "uuid",
      "senderId": "uuid",
      "content": "Hello",
      "createdAt": "2026-01-01T00:00:10.000Z",
      "readAt": null
    },
    "match": {
      "matchId": "uuid",
      "status": "active",
      "lastMessageContent": "Hello",
      "messageCount": 25,
      "canSendMessage": true
    }
  }
}
```

**Error Responses**

| Status | `error.code` | Cause |
|---|---|---|
| 400 | `MISSING_MATCH_ID` | `matchId` path param is missing or empty |
| 400 | `MISSING_MESSAGE_CONTENT` | `content` missing, not a string, or empty after trim |
| 400 | `MATCH_NOT_ACTIVE` | Match is not in active state for messaging |
| 401 | `MISSING_BEARER_TOKEN` | No `Authorization` header or not `Bearer` format |
| 401 | `INVALID_ID_TOKEN` | Token failed Firebase/mock verification |
| 401 | `USER_NOT_FOUND` | Verified token but no matching user in DB |
| 403 | `CHAT_FORBIDDEN` | User is not a participant of this match |
| 404 | `MATCH_NOT_FOUND` | Match does not exist |

---

### 15. List Speed Dating Sessions

Returns speed dating sessions for the authenticated user with message progress and anonymous counterpart summary.

```
GET /api/v1/matching/sessions
Authorization: Bearer <firebase-id-token>
```

**Response 200 — Success**
```json
{
  "success": true,
  "data": {
    "sessions": [
      {
        "sessionId": "uuid",
        "status": "active",
        "startedAt": "2026-01-01T00:00:00.000Z",
        "expiresAt": "2026-01-02T00:00:00.000Z",
        "remainingSeconds": 3600,
        "canOpen": true,
        "canSendMessage": true,
        "myMessageCount": 3,
        "otherMessageCount": 5,
        "messageLimit": 20,
        "unreadCount": 1,
        "counterpart": {
          "userId": "uuid",
          "firstName": "Alice",
          "initials": "AS",
          "blurredPhotoUrl": "https://..."
        },
        "moveToPermanent": {
          "myDecision": "pending",
          "otherDecision": "pending",
          "requestStatus": "none",
          "canRequest": true,
          "canRespond": false,
          "canSubmitFinalDecision": false
        }
      }
    ]
  }
}
```

**Error Responses**

| Status | `error.code` | Cause |
|---|---|---|
| 401 | `MISSING_BEARER_TOKEN` | No `Authorization` header or not `Bearer` format |
| 401 | `INVALID_ID_TOKEN` | Token failed Firebase/mock verification |
| 401 | `USER_NOT_FOUND` | Verified token but no matching user in DB |

---

### 16. Get Speed Dating Session Detail

Returns one speed dating session for the authenticated participant.

```
GET /api/v1/matching/sessions/:sessionId
Authorization: Bearer <firebase-id-token>
```

**Response 200 — Success**
```json
{
  "success": true,
  "data": {
    "session": {
      "sessionId": "uuid",
      "status": "active",
      "startedAt": "2026-01-01T00:00:00.000Z",
      "expiresAt": "2026-01-02T00:00:00.000Z",
      "remainingSeconds": 3590,
      "canOpen": true,
      "canSendMessage": true,
      "myMessageCount": 4,
      "otherMessageCount": 6,
      "messageLimit": 20,
      "unreadCount": 0,
      "counterpart": {
        "userId": "uuid",
        "firstName": "Alice",
        "initials": "AS",
        "blurredPhotoUrl": "https://..."
      },
      "moveToPermanent": {
        "myDecision": "pending",
        "otherDecision": "pending",
        "requestStatus": "none",
        "canRequest": true,
        "canRespond": false,
        "canSubmitFinalDecision": false
      }
    }
  }
}
```

**Error Responses**

| Status | `error.code` | Cause |
|---|---|---|
| 400 | `MISSING_SESSION_ID` | `sessionId` path param is missing or empty |
| 401 | `MISSING_BEARER_TOKEN` | No `Authorization` header or not `Bearer` format |
| 401 | `INVALID_ID_TOKEN` | Token failed Firebase/mock verification |
| 401 | `USER_NOT_FOUND` | Verified token but no matching user in DB |
| 403 | `CHAT_FORBIDDEN` | User is not a participant of this session |
| 404 | `SESSION_NOT_FOUND` | Session does not exist |

---

### 17. Get Speed Dating Session Messages

Returns one session plus all messages in chronological order.

```
GET /api/v1/matching/sessions/:sessionId/messages
Authorization: Bearer <firebase-id-token>
```

**Response 200 — Success**
```json
{
  "success": true,
  "data": {
    "session": {
      "sessionId": "uuid",
      "status": "active",
      "myMessageCount": 4,
      "otherMessageCount": 6,
      "messageLimit": 20,
      "unreadCount": 0,
      "moveToPermanent": {
        "myDecision": "pending",
        "otherDecision": "pending",
        "requestStatus": "none",
        "canRequest": true,
        "canRespond": false,
        "canSubmitFinalDecision": false
      }
    },
    "messages": [
      {
        "id": "1",
        "sessionId": "uuid",
        "senderId": "uuid",
        "content": "Hello",
        "createdAt": "2026-01-01T00:00:10.000Z",
        "readAt": null
      }
    ]
  }
}
```

**Error Responses**

| Status | `error.code` | Cause |
|---|---|---|
| 400 | `MISSING_SESSION_ID` | `sessionId` path param is missing or empty |
| 401 | `MISSING_BEARER_TOKEN` | No `Authorization` header or not `Bearer` format |
| 401 | `INVALID_ID_TOKEN` | Token failed Firebase/mock verification |
| 401 | `USER_NOT_FOUND` | Verified token but no matching user in DB |
| 403 | `CHAT_FORBIDDEN` | User is not a participant of this session |
| 404 | `SESSION_NOT_FOUND` | Session does not exist |

---

### 18. Mark Speed Dating Session Messages Read

Marks all unread incoming messages in a speed dating session as read for the authenticated user.

```
PATCH /api/v1/matching/sessions/:sessionId/read
Authorization: Bearer <firebase-id-token>
```

**Response 200 - Success**
```json
{
  "success": true,
  "data": {
    "session": {
      "sessionId": "uuid",
      "status": "active",
      "unreadCount": 0
    }
  }
}
```

**Error Responses**

| Status | `error.code` | Cause |
|---|---|---|
| 400 | `MISSING_SESSION_ID` | `sessionId` path param is missing or empty |
| 401 | `MISSING_BEARER_TOKEN` | No `Authorization` header or not `Bearer` format |
| 401 | `INVALID_ID_TOKEN` | Token failed Firebase/mock verification |
| 401 | `USER_NOT_FOUND` | Verified token but no matching user in DB |
| 403 | `CHAT_FORBIDDEN` | User is not a participant of this session |
| 404 | `SESSION_NOT_FOUND` | Session does not exist |

---

### 19. Send Speed Dating Message

Sends one message in an active speed dating session.

```
POST /api/v1/matching/sessions/:sessionId/messages
Authorization: Bearer <firebase-id-token>
Content-Type: application/json
```

**Request Body**
```json
{
  "content": "Hello"
}
```

**Response 201 — Success**
```json
{
  "success": true,
  "data": {
    "message": {
      "id": "1",
      "sessionId": "uuid",
      "senderId": "uuid",
      "content": "Hello",
      "createdAt": "2026-01-01T00:00:10.000Z",
      "readAt": null
    },
    "session": {
      "sessionId": "uuid",
      "status": "active",
      "myMessageCount": 5,
      "otherMessageCount": 6,
      "messageLimit": 20,
      "canSendMessage": true,
      "unreadCount": 0,
      "moveToPermanent": {
        "myDecision": "pending",
        "otherDecision": "pending",
        "requestStatus": "none",
        "canRequest": true,
        "canRespond": false,
        "canSubmitFinalDecision": false
      }
    }
  }
}
```

**Error Responses**

| Status | `error.code` | Cause |
|---|---|---|
| 400 | `MISSING_SESSION_ID` | `sessionId` path param is missing or empty |
| 400 | `MISSING_MESSAGE_CONTENT` | `content` missing, not a string, or empty after trim |
| 400 | `MESSAGE_LIMIT_REACHED` | Sender already sent 20 messages in this session |
| 400 | `SESSION_NOT_ACTIVE` | Session is not in active state for sending messages |
| 401 | `MISSING_BEARER_TOKEN` | No `Authorization` header or not `Bearer` format |
| 401 | `INVALID_ID_TOKEN` | Token failed Firebase/mock verification |
| 401 | `USER_NOT_FOUND` | Verified token but no matching user in DB |
| 403 | `CHAT_FORBIDDEN` | User is not a participant of this session |
| 404 | `SESSION_NOT_FOUND` | Session does not exist |

---

### 20. Request Move to Permanent

Creates a move-to-permanent request during an active session, or sends the one allowed counter-request after a decline. When accepted, the session graduates immediately and its full speed dating history is copied into permanent chat.

```
POST /api/v1/matching/sessions/:sessionId/move-to-permanent/request
Authorization: Bearer <firebase-id-token>
```

**Response 200 — Success**
```json
{
  "success": true,
  "data": {
    "session": {
      "sessionId": "uuid",
      "status": "active",
      "moveToPermanent": {
        "myDecision": "yes",
        "otherDecision": "pending",
        "requestStatus": "sent",
        "canRequest": false,
        "canRespond": false,
        "canSubmitFinalDecision": false
      }
    },
    "match": null
  }
}
```

**Error Responses**

| Status | `error.code` | Cause |
|---|---|---|
| 400 | `MISSING_SESSION_ID` | `sessionId` path param is missing or empty |
| 400 | `MOVE_TO_PERMANENT_NOT_ALLOWED` | Session state or current decision flow does not allow creating a request |
| 401 | `MISSING_BEARER_TOKEN` | No `Authorization` header or not `Bearer` format |
| 401 | `INVALID_ID_TOKEN` | Token failed Firebase/mock verification |
| 401 | `USER_NOT_FOUND` | Verified token but no matching user in DB |
| 403 | `CHAT_FORBIDDEN` | User is not a participant of this session |
| 404 | `SESSION_NOT_FOUND` | Session does not exist |

---

### 21. Respond to Move to Permanent

Accepts or declines a pending move-to-permanent request.

```
POST /api/v1/matching/sessions/:sessionId/move-to-permanent/respond
Authorization: Bearer <firebase-id-token>
Content-Type: application/json
```

**Request Body**
```json
{
  "accept": true
}
```

**Response 200 — Accepted**
```json
{
  "success": true,
  "data": {
    "session": {
      "sessionId": "uuid",
      "status": "graduated"
    },
    "match": {
      "matchId": "uuid",
      "status": "active",
      "messageCount": 12
    }
  }
}
```

**Response 200 — Declined**
```json
{
  "success": true,
  "data": {
    "session": {
      "sessionId": "uuid",
      "status": "active",
      "moveToPermanent": {
        "myDecision": "no",
        "otherDecision": "yes",
        "requestStatus": "counter_available",
        "canRequest": true,
        "canRespond": false,
        "canSubmitFinalDecision": false
      }
    },
    "match": null
  }
}
```

**Error Responses**

| Status | `error.code` | Cause |
|---|---|---|
| 400 | `MISSING_SESSION_ID` | `sessionId` path param is missing or empty |
| 400 | `INVALID_MOVE_TO_PERMANENT_RESPONSE` | `accept` is missing or not a boolean |
| 400 | `MOVE_TO_PERMANENT_RESPONSE_NOT_ALLOWED` | There is no pending request for the user to accept or decline |
| 401 | `MISSING_BEARER_TOKEN` | No `Authorization` header or not `Bearer` format |
| 401 | `INVALID_ID_TOKEN` | Token failed Firebase/mock verification |
| 401 | `USER_NOT_FOUND` | Verified token but no matching user in DB |
| 403 | `CHAT_FORBIDDEN` | User is not a participant of this session |
| 404 | `SESSION_NOT_FOUND` | Session does not exist |

---

### 22. Submit Final Decision

Records the user's yes/no answer once a session reaches `awaiting_decision`. If both users answer yes, the session graduates to permanent chat. If both answer no, the session is archived.

```
POST /api/v1/matching/sessions/:sessionId/final-decision
Authorization: Bearer <firebase-id-token>
Content-Type: application/json
```

**Request Body**
```json
{
  "decision": "yes"
}
```

**Error Responses**

| Status | `error.code` | Cause |
|---|---|---|
| 400 | `MISSING_SESSION_ID` | `sessionId` path param is missing or empty |
| 400 | `INVALID_FINAL_DECISION` | `decision` is missing or not one of `yes`, `no` |
| 400 | `FINAL_DECISION_NOT_ALLOWED` | Session is not in final decision phase or has a pending move request |
| 401 | `MISSING_BEARER_TOKEN` | No `Authorization` header or not `Bearer` format |
| 401 | `INVALID_ID_TOKEN` | Token failed Firebase/mock verification |
| 401 | `USER_NOT_FOUND` | Verified token but no matching user in DB |
| 403 | `CHAT_FORBIDDEN` | User is not a participant of this session |
| 404 | `SESSION_NOT_FOUND` | Session does not exist |

---

### 23. End Speed Dating Session Early

Ends the session immediately without graduating it to permanent chat.

```
POST /api/v1/matching/sessions/:sessionId/end
Authorization: Bearer <firebase-id-token>
```

**Response 200 — Success**
```json
{
  "success": true,
  "data": {
    "session": {
      "sessionId": "uuid",
      "status": "ended_early",
      "canOpen": false,
      "canSendMessage": false
    },
    "match": null
  }
}
```

**Error Responses**

| Status | `error.code` | Cause |
|---|---|---|
| 400 | `MISSING_SESSION_ID` | `sessionId` path param is missing or empty |
| 400 | `SESSION_END_NOT_ALLOWED` | Session is already finished and cannot be ended again |
| 401 | `MISSING_BEARER_TOKEN` | No `Authorization` header or not `Bearer` format |
| 401 | `INVALID_ID_TOKEN` | Token failed Firebase/mock verification |
| 401 | `USER_NOT_FOUND` | Verified token but no matching user in DB |
| 403 | `CHAT_FORBIDDEN` | User is not a participant of this session |
| 404 | `SESSION_NOT_FOUND` | Session does not exist |

---

### 24. Get Chat Badge Summary

Returns unread counts for each Chats sub-tab and the combined badge count.

```
GET /api/v1/matching/chats/badges
Authorization: Bearer <firebase-id-token>
```

**Response 200 — Success**
```json
{
  "success": true,
  "data": {
    "speedDatingUnread": 3,
    "matchesUnread": 5,
    "totalUnread": 8
  }
}
```

**Error Responses**

| Status | `error.code` | Cause |
|---|---|---|
| 401 | `MISSING_BEARER_TOKEN` | No `Authorization` header or not `Bearer` format |
| 401 | `INVALID_ID_TOKEN` | Token failed Firebase/mock verification |
| 401 | `USER_NOT_FOUND` | Verified token but no matching user in DB |

---

### 25. Remove Permanent Match

Removes a permanent match from active conversation and sets the relationship to unmatched.

```
POST /api/v1/matching/matches/:matchId/remove
Authorization: Bearer <firebase-id-token>
```

**Response 200 — Success**
```json
{
  "success": true,
  "data": {
    "counterpartUserId": "uuid",
    "match": {
      "matchId": "uuid",
      "status": "unmatched",
      "createdAt": "2026-01-01T00:00:00.000Z",
      "lastMessageAt": "2026-01-01T00:10:00.000Z",
      "lastMessageContent": "Hello",
      "messageCount": 24,
      "canOpen": false,
      "canSendMessage": false,
      "unreadCount": 0,
      "counterpart": {
        "userId": "uuid",
        "displayName": "Alice Smith",
        "photoUrl": "https://..."
      }
    }
  }
}
```

**Error Responses**

| Status | `error.code` | Cause |
|---|---|---|
| 400 | `MISSING_MATCH_ID` | `matchId` path param is missing or empty |
| 401 | `MISSING_BEARER_TOKEN` | No `Authorization` header or not `Bearer` format |
| 401 | `INVALID_ID_TOKEN` | Token failed Firebase/mock verification |
| 401 | `USER_NOT_FOUND` | Verified token but no matching user in DB |
| 403 | `CHAT_FORBIDDEN` | User is not a participant of this match |
| 404 | `MATCH_NOT_FOUND` | Match does not exist |

---

### 26. Block Permanent Match Counterpart

Blocks the counterpart user, and also removes the permanent match.

```
POST /api/v1/matching/matches/:matchId/block
Authorization: Bearer <firebase-id-token>
Content-Type: application/json
```

**Request Body (Optional)**
```json
{
  "reason": "harassment"
}
```

| Field | Type | Required | Description |
|---|---|---|---|
| `reason` | string | no | Optional block reason, stored in `user_blocks.reason` |

**Response 200 — Success**
```json
{
  "success": true,
  "data": {
    "blockId": "uuid",
    "counterpartUserId": "uuid",
    "match": {
      "matchId": "uuid",
      "status": "unmatched",
      "canOpen": false,
      "canSendMessage": false
    }
  }
}
```

**Error Responses**

| Status | `error.code` | Cause |
|---|---|---|
| 400 | `MISSING_MATCH_ID` | `matchId` path param is missing or empty |
| 401 | `MISSING_BEARER_TOKEN` | No `Authorization` header or not `Bearer` format |
| 401 | `INVALID_ID_TOKEN` | Token failed Firebase/mock verification |
| 401 | `USER_NOT_FOUND` | Verified token but no matching user in DB |
| 403 | `CHAT_FORBIDDEN` | User is not a participant of this match |
| 404 | `MATCH_NOT_FOUND` | Match does not exist |

---

### 27. Report Permanent Match Counterpart

Reports the counterpart user, sets match status to `reported`, and stores the report record.

```
POST /api/v1/matching/matches/:matchId/report
Authorization: Bearer <firebase-id-token>
Content-Type: application/json
```

**Request Body**
```json
{
  "reason": "spam",
  "details": "unsolicited messages"
}
```

| Field | Type | Required | Description |
|---|---|---|---|
| `reason` | string | yes | Report reason, must be non-empty after trim |
| `details` | string | no | Additional context text |

**Response 200 — Success**
```json
{
  "success": true,
  "data": {
    "reportId": "uuid",
    "counterpartUserId": "uuid",
    "match": {
      "matchId": "uuid",
      "status": "reported",
      "canOpen": false,
      "canSendMessage": false
    }
  }
}
```

**Error Responses**

| Status | `error.code` | Cause |
|---|---|---|
| 400 | `MISSING_MATCH_ID` | `matchId` path param is missing or empty |
| 400 | `MISSING_REPORT_REASON` | `reason` is missing, not a string, or empty after trim |
| 401 | `MISSING_BEARER_TOKEN` | No `Authorization` header or not `Bearer` format |
| 401 | `INVALID_ID_TOKEN` | Token failed Firebase/mock verification |
| 401 | `USER_NOT_FOUND` | Verified token but no matching user in DB |
| 403 | `CHAT_FORBIDDEN` | User is not a participant of this match |
| 404 | `MATCH_NOT_FOUND` | Match does not exist |

---

### 28. Submit Personality Test

Submits the user's 6 quiz answers, computes their personality type, and saves it to their profile. After this call, `GET /users/profile` will return the personality fields populated.

```
POST /api/v1/users/profile/personality
Authorization: Bearer <firebase-id-token>
Content-Type: application/json
```

**Request Body**
```json
{
  "answers": [0, 2, 1, 3, 0, 2]
}
```

| Field | Type | Required | Description |
|---|---|---|---|
| `answers` | number[] | yes | Exactly 6 integers, each between 0–3 (0=A, 1=B, 2=C, 3=D) |

**Response 200 — Success**
```json
{
  "personality_type": "Serene Soul",
  "personality_primary": "A",
  "personality_secondary": null
}
```

> If two letters tie, `personality_secondary` will be the second letter and `personality_type` will be `"Hybrid (A/B)"` (example).

**Personality Type Labels**

| Letter | Label |
|---|---|
| A | Serene Soul |
| B | Empathetic Companion |
| C | Radiant Dreamer |
| D | Fierce Spark |

**Error Responses**

| Status | `error.code` | Cause |
|---|---|---|
| 400 | `INVALID_ANSWERS` | `answers` is not an array of exactly 6 integers each between 0 and 3 |
| 401 | `MISSING_BEARER_TOKEN` | No `Authorization` header or not `Bearer` format |
| 401 | `INVALID_ID_TOKEN` | Token failed Firebase/mock verification |
| 401 | `USER_NOT_FOUND` | Verified token but no matching user in DB |

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
