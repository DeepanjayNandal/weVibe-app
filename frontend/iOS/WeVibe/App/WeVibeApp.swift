import SwiftUI
import FirebaseCore
import FirebaseAnalytics
import GoogleSignIn

@main
struct WeVibeApp: App {

    @State private var authManager = AuthManager()
    @StateObject private var locationManager = LocationManager()

    init() {
        FirebaseApp.configure()
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
