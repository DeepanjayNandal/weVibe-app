import SwiftUI
import FirebaseCore
import FirebaseAnalytics
import FirebaseAuth
import FirebaseCrashlytics
import FirebaseMessaging
import GoogleSignIn
import UserNotifications

@main
struct WeVibeApp: App {

    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    @State private var authManager = AuthManager()
    @State private var onboardingData = OnboardingData()
    @State private var profileStore = UserProfileStore()
    @State private var chatStore = ChatStore()
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
        Task {
            try? await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
        }
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
                .environment(chatStore)
                .environment(networkMonitor)
                .environment(socketService)
                .environment(matchmakingService)
                .environmentObject(locationManager)
                .task {
                    // Wire location sync once at launch. The callback is a no-op until
                    // the user is authenticated (syncLocation guards on appState).
                    locationManager.onLocationUpdated = { lat, lng, city, state, zip in
                        Task { @MainActor in
                            await authManager.syncLocation(lat: lat, lng: lng, city: city, state: state, zip: zip)
                        }
                    }
                    // Re-sync FCM token whenever Firebase refreshes it.
                    authManager.observeFCMTokenRefresh()
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
                            // Initial chat list load — store caches data so views never re-fetch on navigation.
                            async let matches: () = chatStore.fetchMatches(token: token)
                            async let sessions: () = chatStore.fetchSessions(token: token)
                            _ = await (matches, sessions)
                        }
                    } else if newState == .unauthenticated {
                        socketService.disconnect()
                    }
                }
                .onChange(of: socketService.lastPermanentMessage) { _, event in
                    // Push incoming permanent-chat messages into the list preview without a re-fetch.
                    guard let event else { return }
                    let uid = Auth.auth().currentUser?.uid
                    chatStore.applyIncomingMessage(event, currentUserId: uid)
                }
                .onChange(of: socketService.lastSpeedDatingMessage) { _, event in
                    guard let event else { return }
                    let uid = Auth.auth().currentUser?.uid
                    let found = chatStore.applyIncomingSpeedDatingMessage(event, currentUserId: uid)
                    if !found {
                        // Session not yet in list (e.g. match just created) — fetch to add it.
                        Task {
                            guard let token = try? await Auth.auth().currentUser?.getIDToken() else { return }
                            await chatStore.fetchSessions(token: token)
                        }
                    }
                }
                .onChange(of: socketService.lastPermanentTyping) { _, event in
                    guard let event else { return }
                    let uid = Auth.auth().currentUser?.uid
                    chatStore.applyPermanentTyping(event, currentUserId: uid)
                }
                .onChange(of: socketService.lastSpeedDatingTyping) { _, event in
                    guard let event else { return }
                    let uid = Auth.auth().currentUser?.uid
                    chatStore.applySpeedDatingTyping(event, currentUserId: uid)
                }
                .onChange(of: socketService.lastPermanentMatchRemoved) { _, event in
                    guard let event else { return }
                    chatStore.removeMatch(matchId: event.matchId)
                }
                .onChange(of: socketService.lastPermanentMatchBlocked) { _, event in
                    guard let event else { return }
                    chatStore.removeMatch(matchId: event.matchId)
                }
                .onChange(of: socketService.lastSpeedDatingSessionEnded) { _, event in
                    guard let event else { return }
                    chatStore.applySessionEnded(event)
                }
                .onChange(of: socketService.lastMoveToPermanentUpdated) { _, event in
                    // Session graduated to a permanent match — refresh matches tab so the new row appears.
                    guard event != nil else { return }
                    Task {
                        guard let token = try? await Auth.auth().currentUser?.getIDToken() else { return }
                        await chatStore.fetchMatches(token: token)
                    }
                }
                .onChange(of: socketService.lastMatchEvent) { _, event in
                    // A match was found — fetch sessions immediately so the new session is in the
                    // list before any socket messages for it arrive (applyIncomingSpeedDatingMessage
                    // is a no-op when the session isn't cached yet).
                    guard event != nil else { return }
                    Task {
                        guard let token = try? await Auth.auth().currentUser?.getIDToken() else { return }
                        await chatStore.fetchSessions(token: token)
                    }
                }
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase == .active, authManager.appState == .authenticated {
                        // Re-fetch when app comes to foreground so missed socket events don't
                        // leave the chat list stale (e.g. messages received while backgrounded).
                        Task {
                            guard let token = try? await Auth.auth().currentUser?.getIDToken() else { return }
                            async let matches: () = chatStore.fetchMatches(token: token)
                            async let sessions: () = chatStore.fetchSessions(token: token)
                            _ = await (matches, sessions)
                        }
                    }
                    // EC2: app goes to background while searching — cancel search and notify user.
                    if newPhase == .background, matchmakingService.isSearching {
                        matchmakingService.cancelSearch()
                        scheduleRemovedFromQueueNotification()
                    }
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
