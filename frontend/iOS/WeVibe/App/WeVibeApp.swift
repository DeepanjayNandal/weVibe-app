import SwiftUI
import FirebaseCore
import FirebaseAnalytics
import GoogleSignIn

@main
struct WeVibeApp: App {

    @State private var authManager = AuthManager()
    @State private var onboardingData = OnboardingData()
    @State private var profileStore = UserProfileStore()
    @State private var networkMonitor = NetworkMonitor()
    @StateObject private var locationManager = LocationManager()

    init() {
        // Verify plist was copied by the "Firebase Plist Copy" Run Script before configuring.
        // Missing plist → Firebase initialises with defaults and auth silently fails.
        let plistName = "GoogleService-Info"
        guard Bundle.main.path(forResource: plistName, ofType: "plist") != nil else {
            fatalError(
                "GoogleService-Info.plist not found in the app bundle. " +
                "Run the 'Firebase Plist Copy' build phase and rebuild."
            )
        }
        FirebaseApp.configure()
        guard FirebaseApp.app() != nil else {
            fatalError("FirebaseApp.configure() failed — check your GoogleService-Info.plist.")
        }
        #if DEBUG
        Analytics.setAnalyticsCollectionEnabled(false)
        #endif
        // GoogleSignIn v7+ requires explicit client ID configuration.
        if let clientID = FirebaseApp.app()?.options.clientID {
            GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(authManager)
                .environment(onboardingData)
                .environment(profileStore)
                .environment(networkMonitor)
                .environmentObject(locationManager)
                .task {
                    // Restores a saved Firebase session on every launch.
                    await authManager.checkAuthState()
                }
                .onOpenURL { url in
                    // Firebase email verification deep links arrive here.
                    authManager.handleDeepLink(url)
                }
        }
    }
}
