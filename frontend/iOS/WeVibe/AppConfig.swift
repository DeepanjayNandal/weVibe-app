import Foundation

enum AppConfig {
    // MARK: - Backend
    static let apiBaseURL = "http://localhost:3000/api/v1"

    // MARK: - Firebase
    /// Firebase Hosting domain used in ActionCodeSettings for email verification deep links.
    /// Format: https://<PROJECT-ID>.firebaseapp.com
    /// PROJECT_IDs are sourced from GoogleService-Info-Dev.plist (wewibe-dev) and
    /// GoogleService-Info-Prod.plist (wewibe-prod).
    #if DEBUG
    static let firebaseHostingDomain = "https://wewibe-dev.firebaseapp.com"
    #else
    static let firebaseHostingDomain = "https://wewibe-prod.firebaseapp.com"
    #endif
}
