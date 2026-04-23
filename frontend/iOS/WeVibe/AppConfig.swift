import Foundation

enum AppConfig {
    // MARK: - Backend
    #if DEBUG
    private static let backendHost = "https://wevibe-backend19-1001323522506.us-central1.run.app"
    #else
    private static let backendHost = "https://wevibe-backend-prod-1001323522506.us-central1.run.app"
    #endif
    static let apiBaseURL = "\(backendHost)/api/v1"
    static let wsBaseURL  = backendHost
    // MARK: - Firebase
    /// Firebase Hosting domain used in ActionCodeSettings for email verification deep links.
    /// Format: https://<PROJECT-ID>.firebaseapp.com
    /// PROJECT_IDs are sourced from GoogleService-Info-Dev.plist (wevibe-dev) and
    /// GoogleService-Info-Prod.plist (wevibe-prod).
    #if DEBUG
    static let firebaseHostingDomain = "https://wevibe-dev.firebaseapp.com"
    #else
    static let firebaseHostingDomain = "https://wevibe-prod.firebaseapp.com"
    #endif
}

