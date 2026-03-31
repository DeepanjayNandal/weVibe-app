import SwiftUI
import FirebaseCore
import FirebaseAnalytics
import FirebaseAuth
import GoogleSignIn
import UserNotifications

@main
struct WeVibeApp: App {

    @State private var authManager = AuthManager()
    @State private var onboardingData = OnboardingData()
    @State private var profileStore = UserProfileStore()
    @State private var networkMonitor = NetworkMonitor()
    @State private var socketService = SocketService()
    @State private var matchmakingService = MatchmakingService()
    @StateObject private var locationManager = LocationManager()
    @Environment(\.scenePhase) private var scenePhase

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
                .environment(socketService)
                .environment(matchmakingService)
                .environmentObject(locationManager)
                .task {
                    // Restores a saved Firebase session on every launch.
                    await authManager.checkAuthState()
                }
                .onOpenURL { url in
                    // Firebase email verification deep links arrive here.
                    authManager.handleDeepLink(url)
                }
                .onChange(of: authManager.appState) { _, newState in
                    // Connect socket when authenticated, disconnect on sign-out.
                    if newState == .authenticated {
                        Task {
                            guard let token = try? await Auth.auth().currentUser?.getIDToken()
                            else { return }
                            socketService.connect(token: token)
                        }
                    } else if newState == .unauthenticated {
                        socketService.disconnect()
                    }
                }
                .onChange(of: scenePhase) { _, newPhase in
                    // EC2: app goes to background while searching — cancel search and notify user.
                    guard newPhase == .background, matchmakingService.isSearching else { return }
                    matchmakingService.cancelSearch()
                    scheduleRemovedFromQueueNotification()
                }
        }
    }

    // MARK: - Local Notification (EC2)

    private func scheduleRemovedFromQueueNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Removed from queue"
        content.body = "You've been removed from the speed dating queue. Open the app to rejoin."
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "queue_removed",
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request)
    }
}
