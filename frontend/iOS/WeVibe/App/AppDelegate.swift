import UIKit
import FirebaseMessaging
import UserNotifications

final class AppDelegate: NSObject, UIApplicationDelegate {

    // Latest FCM token — read by AuthManager after login to sync with backend.
    static var fcmToken: String?

    // The matchId of the permanent chat currently visible on screen.
    // Set by PermanentChatView.onAppear / cleared by onDisappear.
    // Used to suppress push notifications when the user is already reading that conversation.
    static var activeMatchId: String?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        Messaging.messaging().delegate = self
        UNUserNotificationCenter.current().delegate = self
        UIApplication.shared.registerForRemoteNotifications()
        return true
    }

    // Passes the APNs device token to FCM so it can map APNs → FCM token.
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Messaging.messaging().apnsToken = deviceToken
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        AppLogger.recordError(error, context: "APNs registration failed", logger: AppLogger.apns)
    }
}

// MARK: - MessagingDelegate

extension AppDelegate: MessagingDelegate {

    // Called whenever FCM issues or refreshes the registration token.
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let fcmToken else { return }
        AppDelegate.fcmToken = fcmToken
        NotificationCenter.default.post(
            name: .fcmTokenRefreshed,
            object: nil,
            userInfo: ["token": fcmToken]
        )
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension AppDelegate: UNUserNotificationCenterDelegate {

    // Show banner + sound in foreground, but suppress if user is already in that chat.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        let userInfo = notification.request.content.userInfo
        if let matchId = userInfo["matchId"] as? String,
           matchId == AppDelegate.activeMatchId {
            // User is already viewing this conversation — no banner needed.
            return []
        }
        return [.banner, .sound, .badge]
    }

    // Handle tap on notification — deep link into the right screen when needed.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let userInfo = response.notification.request.content.userInfo
        NotificationCenter.default.post(
            name: .pushNotificationTapped,
            object: nil,
            userInfo: userInfo
        )
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let fcmTokenRefreshed = Notification.Name("FCMTokenRefreshed")
    static let pushNotificationTapped = Notification.Name("PushNotificationTapped")
}
