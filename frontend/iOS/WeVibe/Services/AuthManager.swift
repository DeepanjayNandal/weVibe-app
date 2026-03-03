import Foundation
import Observation

// MARK: - Auth Errors

enum AuthError: LocalizedError {
    case notVerified
    case sessionExpired
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .notVerified:      return "Email not yet verified. Please check your inbox."
        case .sessionExpired:   return "Your session has expired. Please sign in again."
        case .unknown(let msg): return msg
        }
    }
}

// MARK: - AuthManager

@Observable
@MainActor
final class AuthManager {

    // MARK: - State

    var appState: AppState = .launching

    /// Shown as a global toast for unexpected/background errors.
    var globalError: String?

    /// The email address that verification was sent to — displayed on ConfirmScreen.
    var pendingVerificationEmail: String = ""

    // MARK: - Launch

    // Called on launch to restore a saved session if one exists.
    func checkAuthState() async {
        // TODO: Replace with Firebase Auth state listener:
        //
        // Auth.auth().addStateDidChangeListener { [weak self] _, user in
        //     guard let self else { return }
        //     guard let user else { self.appState = .unauthenticated; return }
        //
        //     if !user.isEmailVerified {
        //         self.appState = .pendingVerification
        //         self.pendingVerificationEmail = user.email ?? ""
        //         return
        //     }
        //     Task { await self.resolvePostAuthState() }
        // }

        // Stub: brief delay to simulate token check, then fall through to unauthenticated.
        try? await Task.sleep(nanoseconds: 800_000_000)
        appState = .unauthenticated
    }

    // MARK: - Email / Password Auth

    func login(email: String, password: String) async throws {
        // TODO: try await Auth.auth().signIn(withEmail: email, password: password)
        try await Task.sleep(nanoseconds: 1_500_000_000) // stub network delay
        await resolvePostAuthState()
    }

    func register(email: String, password: String, firstName: String, lastName: String) async throws {
        // TODO:
        // 1. let result = try await Auth.auth().createUser(withEmail: email, password: password)
        //
        // 2. Configure deep-link email verification (no website needed — uses Firebase Hosting
        //    domain for the redirect, custom URL scheme opens the app):
        //    let settings = ActionCodeSettings()
        //    settings.url = URL(string: "https://<your-project>.firebaseapp.com")!
        //    settings.handleCodeInApp = true
        //    settings.setIOSBundleID(Bundle.main.bundleIdentifier!)
        //    try await result.user.sendEmailVerification(with: settings)
        //
        // 3. POST user record to your backend (firstName, lastName, Firebase UID)
        //    so the backend can create the user profile row.

        try await Task.sleep(nanoseconds: 1_500_000_000) // stub
        pendingVerificationEmail = email
        appState = .pendingVerification
    }

    func resendVerificationEmail() async throws {
        // TODO: try await Auth.auth().currentUser?.sendEmailVerification(with: actionCodeSettings)
        try await Task.sleep(nanoseconds: 500_000_000) // stub
    }

    func forgotPassword(email: String) async throws {
        // TODO: try await Auth.auth().sendPasswordReset(withEmail: email)
        //
        // Firebase sends a reset email with a 1-hour expiring link.
        // The link opens Firebase's hosted web page where the user sets a new password.
        // Resetting the password invalidates all existing sessions on other devices
        // (their refresh tokens are revoked; those devices are logged out within ~1 hour).
        //
        // Note: Firebase throws AuthErrorCode.userNotFound if the email isn't registered.
        // The caller (ForgotPasswordScreen) intentionally silences all errors and always
        // shows the same success message to prevent email enumeration attacks.

        try await Task.sleep(nanoseconds: 1_000_000_000) // stub network delay
    }

    // For when the deep link didn't fire — reloads the user and checks isEmailVerified manually.
    func checkEmailVerified() async throws {
        // TODO:
        // try await Auth.auth().currentUser?.reload()
        // guard Auth.auth().currentUser?.isEmailVerified == true else {
        //     throw AuthError.notVerified
        // }
        // await resolvePostAuthState()

        try await Task.sleep(nanoseconds: 1_000_000_000) // stub
        appState = .onboarding
    }

    // MARK: - SSO Auth (skips email verification — providers confirm identity)

    func loginWithGoogle() async throws {
        // TODO:
        // 1. let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootVC)
        // 2. let credential = GoogleAuthProvider.credential(
        //        withIDToken: result.user.idToken!.tokenString,
        //        accessToken: result.user.accessToken.tokenString)
        // 3. try await Auth.auth().signIn(with: credential)

        try await Task.sleep(nanoseconds: 1_500_000_000) // stub
        await resolvePostAuthState()
    }

    func loginWithApple() async throws {
        // TODO:
        // 1. ASAuthorizationAppleIDProvider → ASAuthorizationController (nonce-based)
        // 2. let credential = OAuthProvider.appleCredential(
        //        withIDToken: String(data: appleIDToken, encoding: .utf8)!,
        //        rawNonce: nonce,
        //        fullName: appleIDCredential.fullName)
        // 3. try await Auth.auth().signIn(with: credential)

        try await Task.sleep(nanoseconds: 1_500_000_000) // stub
        await resolvePostAuthState()
    }

    // MARK: - Deep Link Handling

    // Called from onOpenURL. Returns true if we handled it (i.e. it was a Firebase verification link).
    @discardableResult
    func handleDeepLink(_ url: URL) -> Bool {
        // TODO:
        // guard Auth.auth().isSignIn(withEmailLink: url.absoluteString) else { return false }
        //
        // Extract oobCode from url, then:
        // Auth.auth().applyActionCode(oobCode) { [weak self] error in
        //     guard error == nil else { return }
        //     Task { await self?.resolvePostAuthState() }
        // }
        //
        // Alternatively use the new async API when available.

        // Stub: any URL matching our scheme is treated as a successful verification.
        appState = .onboarding
        return true
    }

    // MARK: - Onboarding Completion

    /// Called by SurveyStep5 "Finish" button after profile data is submitted.
    func completeOnboarding() {
        // TODO: POST /users/profile to backend to mark isProfileComplete = true.
        // The backend should update the user record so resolvePostAuthState()
        // returns .authenticated on next launch.
        appState = .authenticated
    }

    // MARK: - Sign Out

    func logout() {
        // TODO: try? Auth.auth().signOut()
        pendingVerificationEmail = ""
        appState = .unauthenticated
    }

    // MARK: - Private

    // After sign-in, asks the backend if the user's profile is done and picks the right state.
    private func resolvePostAuthState() async {
        // TODO:
        // 1. let token = try await Auth.auth().currentUser?.getIDToken()
        // 2. let response = try await apiClient.post("/auth/session", bearer: token)
        //    → response: { isProfileComplete: Bool, userId: String, ... }
        // 3. appState = response.isProfileComplete ? .authenticated : .onboarding

        // Stub: always route to onboarding until backend is ready.
        appState = .onboarding
    }
}
