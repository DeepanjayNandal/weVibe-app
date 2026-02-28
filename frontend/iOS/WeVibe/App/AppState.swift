enum AppState: Equatable {
    /// Checking stored session on launch — brief, silent
    case launching
    /// No valid session — show auth flow (Splash → Login/Register)
    case unauthenticated
    /// Account created, Firebase verification email sent — waiting for deep link
    case pendingVerification
    /// Logged in, email verified, but profile not yet complete — show survey
    case onboarding
    /// Fully authenticated with complete profile — show main app
    case authenticated
}
