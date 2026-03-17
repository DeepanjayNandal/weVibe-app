# weVibe iOS App

## Requirements

- Xcode 16 or later
- iOS 17.0+ deployment target
- macOS Sonoma or later

## Setup

1. **Clone the repository**
   ```bash
   git clone https://github.com/honganhnguyen-lab/weVibe-app.git
   ```

2. **Add Firebase config files**

   The real plist files are git-ignored. Copy your downloaded files into:
   ```
   frontend/iOS/WeVibe/Firebase/GoogleService-Info-Dev.plist   (Debug builds)
   frontend/iOS/WeVibe/Firebase/GoogleService-Info-Prod.plist  (Release builds)
   ```

3. **Open the project**
   ```bash
   open frontend/iOS/WeVibe.xcodeproj
   ```

4. **Build and run**
   - Select an iPhone simulator running iOS 17.0+ or a connected device
   - Press **Cmd + R**

## Architecture

- `AppState` enum drives the entire view hierarchy via `RootView`
- `AuthManager` — handles all Firebase Auth operations (email, Google Sign-In)
- `UserProfileStore` — holds the user's profile in memory; always fetched from the backend, no local caching
- `OnboardingData` — holds onboarding flow state
- `APIClient` — handles all REST calls to the backend
