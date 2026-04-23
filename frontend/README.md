# weVibe iOS App

SwiftUI app for iOS 17+. The Xcode project (`WeVibe.xcodeproj`) is not committed — it is generated locally from `frontend/iOS/project.yml` via XcodeGen.

---

## Requirements

- Xcode 16 or later
- iOS 17.0+ deployment target
- macOS Sonoma or later
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) — `brew install xcodegen`
- [fastlane](https://fastlane.tools) — `brew install fastlane`

---

## First-time Setup

### 1. Install tools

```bash
brew install xcodegen fastlane
```

### 2. Activate git hooks

Run from the **repo root** — auto-regenerates the Xcode project when `project.yml` changes after a pull or branch switch.

```bash
git config core.hooksPath .githooks
```

### 3. Get these files from the team

| File | Purpose |
|------|---------|
| `frontend/iOS/WeVibe/Firebase/GoogleService-Info-Dev.plist` | Firebase config for Debug builds |
| `frontend/iOS/WeVibe/Firebase/GoogleService-Info-Prod.plist` | Firebase config for Release builds |
| `frontend/iOS/fastlane/api_key.json` | App Store Connect API key for TestFlight uploads |
| Match encryption passphrase | Used to decrypt certs from the `wevibe-certs` repo |

All of these are gitignored — ask a team member.

### 4. Install Ruby dependencies

```bash
cd frontend/iOS && bundle install
```

### 5. Sync certificates and provisioning profiles

```bash
bundle exec fastlane sync_dev
```

Enter the Match encryption passphrase when prompted. This installs the development certificate and provisioning profile into your Keychain — no Apple account login needed.

### 6. Generate the Xcode project

```bash
xcodegen generate
```

### 7. Open and build

```bash
open WeVibe.xcodeproj
```

Press **Cmd + R**, select your device or an iOS 17+ simulator.

---

## Backend

By default the app points to the production Cloud Run backend:

```
https://wevibe-backend19-1001323522506.us-central1.run.app
```

To test against a local backend, update `AppConfig.apiBaseURL` in `frontend/iOS/WeVibe/App/AppConfig.swift` to your machine's LAN IP (e.g. `http://192.168.0.28:3000`).

---

## Bundle IDs

| Config | Bundle ID | Purpose |
|--------|-----------|---------|
| Debug | `com.wevibe1.appdev` | Local development and device testing |
| Release | `com.wevibe1.app` | TestFlight and App Store |

---

## Adding Your iPhone for Device Testing

1. Connect your iPhone to your Mac
2. Open Finder → click your iPhone → click the model line until **UDID** appears → right-click → Copy
3. Add your UDID to `frontend/iOS/fastlane/devices.txt`:
   ```
   Device ID	Device Name
   YOUR_UDID	Your Name iPhone
   ```
4. Run:
   ```bash
   bundle exec fastlane add_device
   ```

This registers your device with Apple and regenerates the provisioning profile automatically — no client involvement needed.

---

## TestFlight

```bash
cd frontend/iOS
bundle exec fastlane beta
```

Builds a Release archive and uploads it to TestFlight. The build appears in App Store Connect within ~10 minutes. Requires `fastlane/api_key.json` (gitignored).

---

## Regenerating the Xcode Project

Any time you modify `project.yml` (new files, build settings, dependencies):

```bash
cd frontend/iOS && xcodegen generate
```

Git hooks run this automatically after `git pull` and branch switches.

---

## Code Signing

The project uses **manual signing** via [fastlane match](https://docs.fastlane.tools/actions/match/).

- Certificates and provisioning profiles are stored encrypted in a private `wevibe-certs` repo
- `bundle exec fastlane sync_dev` pulls and installs everything locally
- You do **not** need to be logged into the Apple Developer account in Xcode
- If your device changes, update `devices.txt` and run `bundle exec fastlane add_device`

---

## Architecture

| Layer | Description |
|-------|-------------|
| `AppState` | Enum driving the entire view hierarchy via `RootView` |
| `AuthManager` | Firebase Auth — email/password, Google Sign-In, Apple Sign-In |
| `UserProfileStore` | In-memory profile state — fetched from backend, no local caching |
| `OnboardingData` | Onboarding survey draft — persisted to disk with file protection |
| `LocationManager` | CLLocationManager wrapper — reverse geocodes and syncs to backend on movement |
| `SocketService` | Socket.IO client — real-time messaging and match events |
| `MatchmakingService` | Speed dating queue join/leave + match-found coordination |
| `APIClient` | All REST calls to the backend (auth, profile, photos, speed-dating, permanent chat) |
| `ChatAPIClient` | Response model structs only (`SpeedDatingDetail`, `ActiveChatDetail`) |

---

## SPM Dependencies

| Package | Version |
|---------|---------|
| `firebase-ios-sdk` | >= 12.10.0 |
| `GoogleSignIn-iOS` | >= 9.1.0 |
| `socket.io-client-swift` | >= 16.1.0 |
