# weVibe

iOS dating app (SwiftUI) with a Node.js/Express backend — speed dating sessions, permanent matches, real-time messaging, and profile-driven matchmaking.

---

## Tech Stack

| Layer | Tech |
|-------|------|
| iOS App | Swift / SwiftUI, Firebase Auth, Socket.IO |
| Backend API | Node.js / Express (TypeScript), Prisma, PostgreSQL |
| Real-time | Socket.IO + Upstash Redis |
| Auth | Firebase Authentication |
| Push | Firebase Cloud Messaging (FCM) |
| Storage | Google Cloud Storage (photo uploads) |
| AI | Google Gemini 2.5 Flash (AI bio generation) |
| Deployment | Google Cloud Run |

---

## Project Structure

```
weVibe-app/
  frontend/iOS/       iOS SwiftUI app (XcodeGen-generated Xcode project)
  backend/            Node.js/Express API (TypeScript, Prisma, Socket.IO)
  .planning/docs/     API contracts and design docs
  .planning/          GSD planning files (roadmap, phases, codebase maps)
```

- **iOS setup and architecture** → [frontend/README.md](frontend/README.md)
- **Backend setup and API reference** → [backend/README.md](backend/README.md)

---

## Features

- **Speed dating** — timed sessions with queue-based matchmaking
- **Permanent matches** — messaging for mutually liked pairs
- **Real-time chat** — Socket.IO with typing indicators and instant delivery
- **Onboarding** — 5-step survey with GPS location, photo upload, and personality test
- **Authentication** — email/password, Google Sign-In, Apple Sign-In
- **AI bio generation** — Gemini 2.5 Flash persona bios
- **Push notifications** — FCM for new messages (speed dating + permanent chat)
- **Block & report** — in-match moderation flow
- **Soft delete** — 30-day account grace period with reactivation on login