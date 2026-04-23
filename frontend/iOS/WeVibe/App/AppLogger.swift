import OSLog
import FirebaseCrashlytics

/// Centralised logging for WeVibe.
///
/// All log categories share the app's bundle ID as the subsystem, making it
/// easy to filter the entire app in Console.app: Subsystem = com.wevibe1(.dev).
///
/// Usage:
///   AppLogger.chat.info("Session loaded")
///   AppLogger.recordError(error, context: "loadSession", logger: AppLogger.chat)
enum AppLogger {

    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.wevibe1"

    static let apns          = Logger(subsystem: subsystem, category: "APNs")
    static let chat          = Logger(subsystem: subsystem, category: "ActiveChat")
    static let permanentChat = Logger(subsystem: subsystem, category: "PermanentChat")
    static let socket        = Logger(subsystem: subsystem, category: "SocketService")
    static let chatStore     = Logger(subsystem: subsystem, category: "ChatStore")

    /// Logs at `.error` level via `os.Logger` and records a non-fatal error in
    /// Crashlytics so it surfaces in the Firebase console without crashing the app.
    static func recordError(_ error: Error, context: String, logger: Logger) {
        logger.error("\(context): \(error.localizedDescription, privacy: .public)")
        Crashlytics.crashlytics().log("\(context): \(error.localizedDescription)")
        Crashlytics.crashlytics().record(error: error)
    }
}
