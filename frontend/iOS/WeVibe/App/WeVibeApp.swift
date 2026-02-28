import SwiftUI

// TODO: When GoogleService-Info.plist is added, uncomment:
// import FirebaseCore
// import FirebaseAnalytics

@main
struct WeVibeApp: App {

    @State private var authManager = AuthManager()

    init() {
        // TODO: FirebaseApp.configure()
        //
        // Also add to Info.plist once GoogleService-Info.plist is available:
        //   REVERSED_CLIENT_ID  → URL scheme for Google Sign-In
        //   wevibe              → Custom URL scheme for email verification deep links
        //
        // And add a Crashlytics Run Script build phase:
        //   "${PODS_ROOT}/FirebaseCrashlytics/run" (CocoaPods)
        //   or the SPM equivalent via the Xcode build phase editor
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(authManager)
                .task {
                    // Silently check for a stored Firebase session on every launch.
                    await authManager.checkAuthState()
                }
                .onOpenURL { url in
                    // Firebase email verification deep links arrive here.
                    // AuthManager inspects the URL, applies the action code,
                    // and advances appState to .onboarding on success.
                    authManager.handleDeepLink(url)
                }
        }
    }
}
