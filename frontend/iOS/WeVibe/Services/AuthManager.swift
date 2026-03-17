import Foundation
import Observation
import FirebaseAuth
import GoogleSignIn
import AuthenticationServices
import CryptoKit

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

    /// True while the onboarding POST is in flight — used by SurveyStep5 to show a loader.
    var isSubmittingOnboarding: Bool = false

    // MARK: - Private

    /// Nonce used for Apple Sign-In — must be stored for Firebase credential creation.
    private var currentNonce: String?

    private let apiClient = APIClient()

    // MARK: - Launch

    /// One-time launch check: routes based on existing Firebase session.
    /// Also registers a persistent listener to detect external sign-out (e.g. token revoked).
    func checkAuthState() async {
        // Route immediately based on current session — no listener race possible.
        let user = Auth.auth().currentUser
        if let user {
            if !user.isEmailVerified {
                appState = .pendingVerification
                pendingVerificationEmail = user.email ?? ""
            } else {
                await resolvePostAuthState()
            }
        } else {
            appState = .unauthenticated
        }

        // Persistent listener: only handles external sign-out after launch.
        // All explicit auth operations route themselves — they don't rely on this.
        Auth.auth().addStateDidChangeListener { [weak self] _, user in
            guard let self else { return }
            guard user == nil else { return }
            Task { @MainActor in self.appState = .unauthenticated }
        }
    }

    // MARK: - Email / Password Auth

    func login(email: String, password: String) async throws {
        do {
            try await Auth.auth().signIn(withEmail: email, password: password)
            let token = try await Auth.auth().currentUser?.getIDToken() ?? ""
            try await apiClient.loginUser(idToken: token, provider: "email")
            await resolvePostAuthState()
        } catch {
            throw AuthError.unknown(mapAuthError(error))
        }
    }

    func register(email: String, password: String, firstName: String, lastName: String) async throws {
        do {
            let result = try await Auth.auth().createUser(withEmail: email, password: password)

            let changeRequest = result.user.createProfileChangeRequest()
            changeRequest.displayName = "\(firstName) \(lastName)"
            try await changeRequest.commitChanges()

            try await result.user.sendEmailVerification()

            let token = try await result.user.getIDToken()
            try await apiClient.registerUser(idToken: token, provider: "email")

            pendingVerificationEmail = email
            appState = .pendingVerification
        } catch {
            // Roll back the Firebase account so the user can retry registration cleanly.
            try? await Auth.auth().currentUser?.delete()
            throw AuthError.unknown(mapAuthError(error))
        }
    }

    func resendVerificationEmail() async throws {
        try await Auth.auth().currentUser?.sendEmailVerification()
    }

    func forgotPassword(email: String) async throws {
        // Errors silenced intentionally — always show the same success message
        // to prevent email enumeration attacks. Firebase throws userNotFound
        // for unregistered emails; we don't want to leak that information.
        try? await Auth.auth().sendPasswordReset(withEmail: email)
    }

    // MARK: - Email Verification

    /// For when the deep link didn't fire — reloads the user and checks isEmailVerified manually.
    func checkEmailVerified() async throws {
        guard let user = Auth.auth().currentUser else {
            throw AuthError.sessionExpired
        }
        try await user.reload()
        guard user.isEmailVerified else {
            throw AuthError.notVerified
        }
        await resolvePostAuthState()
    }

    // MARK: - SSO Auth

    func loginWithGoogle() async throws {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = windowScene.windows.first?.rootViewController else {
            throw AuthError.unknown("Unable to present sign-in. Please try again.")
        }

        do {
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootVC)
            guard let idToken = result.user.idToken?.tokenString else {
                throw AuthError.unknown("Google Sign-In returned no ID token.")
            }
            let credential = GoogleAuthProvider.credential(
                withIDToken: idToken,
                accessToken: result.user.accessToken.tokenString
            )
            try await Auth.auth().signIn(with: credential)
            let token = try await Auth.auth().currentUser?.getIDToken() ?? ""
            try await apiClient.loginUser(idToken: token, provider: "google")
            await resolvePostAuthState()
        } catch {
            throw AuthError.unknown(mapAuthError(error))
        }
    }

    func loginWithApple() async throws {
        let nonce = randomNonceString()
        currentNonce = nonce
        let hashedNonce = sha256(nonce)

        let provider = ASAuthorizationAppleIDProvider()
        let request = provider.createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = hashedNonce

        do {
            let appleCredential = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<ASAuthorizationAppleIDCredential, Error>) in
                let coordinator = AppleSignInCoordinator(continuation: continuation)
                let controller = ASAuthorizationController(authorizationRequests: [request])
                controller.delegate = coordinator
                controller.presentationContextProvider = coordinator
                controller.performRequests()
                // Retain coordinator for delegate lifetime
                objc_setAssociatedObject(controller, "coordinator", coordinator, .OBJC_ASSOCIATION_RETAIN)
            }

            guard let identityTokenData = appleCredential.identityToken,
                  let identityToken = String(data: identityTokenData, encoding: .utf8),
                  let storedNonce = currentNonce else {
                throw AuthError.unknown("Apple Sign-In returned incomplete credentials.")
            }

            let firebaseCredential = OAuthProvider.appleCredential(
                withIDToken: identityToken,
                rawNonce: storedNonce,
                fullName: appleCredential.fullName
            )
            try await Auth.auth().signIn(with: firebaseCredential)
            let token = try await Auth.auth().currentUser?.getIDToken() ?? ""
            try await apiClient.loginUser(idToken: token, provider: "apple")
            await resolvePostAuthState()
        } catch {
            throw AuthError.unknown(mapAuthError(error))
        }
    }

    // MARK: - Deep Link Handling

    /// Called from onOpenURL. Checks if the URL is from our Firebase Hosting domain
    /// (email verification redirect) and re-checks verification status if so.
    @discardableResult
    func handleDeepLink(_ url: URL) -> Bool {
        // Firebase Hosting email verification links arrive as Universal Links.
        // The Firebase hosted page applies the OOB code server-side, then redirects
        // back to the app. We reload the user to pick up the newly verified state.
        let hostingHost = AppConfig.firebaseHostingDomain
            .replacingOccurrences(of: "https://", with: "")
            .replacingOccurrences(of: "http://", with: "")

        guard url.host == hostingHost else { return false }

        Task { @MainActor in
            try? await Auth.auth().currentUser?.reload()
            if Auth.auth().currentUser?.isEmailVerified == true {
                await resolvePostAuthState()
            }
        }
        return true
    }

    // MARK: - Onboarding Completion

    /// Called by SurveyStep5 "Finish" — POSTs full profile to backend then routes to main app.
    func completeOnboarding(_ data: OnboardingData) {
        Task {
            isSubmittingOnboarding = true
            defer { isSubmittingOnboarding = false }
            guard let user = Auth.auth().currentUser else {
                appState = .unauthenticated
                return
            }
            do {
                let token = try await user.getIDToken()

                // Split Firebase displayName into first / last name
                let parts = (user.displayName ?? "").split(separator: " ", maxSplits: 1)
                let firstName = parts.first.map(String.init) ?? ""
                let lastName = parts.count > 1 ? String(parts[1]) : ""

                let payload = UserProfilePayload(from: data, firstName: firstName, lastName: lastName)
                try await apiClient.submitProfile(token: token, payload: payload)
                data.clear()
                appState = .authenticated
            } catch {
                globalError = "Couldn't save your profile. Please check your connection and try again."
            }
        }
    }

    // MARK: - Sign Out

    func logout(profileStore: UserProfileStore, onboardingData: OnboardingData) {
        try? Auth.auth().signOut()

        // MARK: - Store Cleanup on Logout
        // When adding new stores, clear them here to prevent data leaking between accounts.
        // Current stores:
        profileStore.clear()          // UserProfileStore — profile/edit fields
        onboardingData.clear()        // OnboardingData — clears partial draft if user abandoned onboarding
        // TODO: chatStore.clear()    — add when chat feature is built

        pendingVerificationEmail = ""
        appState = .unauthenticated
    }

    // MARK: - Private Helpers

    /// After sign-in: verify email, then check backend for an existing profile.
    /// Routes to .authenticated (returning user) or .onboarding (new user).
    private func resolvePostAuthState() async {
        guard let user = Auth.auth().currentUser else {
            appState = .unauthenticated
            return
        }
        if !user.isEmailVerified {
            pendingVerificationEmail = user.email ?? ""
            appState = .pendingVerification
            return
        }
        do {
            let token = try await user.getIDToken()
            let onboardingComplete = try await apiClient.checkProfile(token: token)
            appState = onboardingComplete ? .authenticated : .onboarding
        } catch APIError.unauthorized {
            appState = .unauthenticated
        } catch {
            // Network failure — assume returning user and let them into the app.
            // ProfileView will show the fetch error and offer a retry.
            appState = .authenticated
        }
    }

    /// Maps Firebase AuthErrorCode to user-friendly strings.
    private func mapAuthError(_ error: Error) -> String {
        guard let code = AuthErrorCode(rawValue: (error as NSError).code) else {
            return error.localizedDescription
        }
        switch code {
        case .invalidCredential:    return "Incorrect email or password."
        case .wrongPassword:        return "Incorrect password. Please try again."
        case .userNotFound:         return "No account found with this email."
        case .networkError:         return "Check your connection and try again."
        case .tooManyRequests:      return "Too many attempts. Please wait and try again."
        case .emailAlreadyInUse:    return "An account with this email already exists."
        case .weakPassword:         return "Password is too weak. Please choose a stronger one."
        case .invalidEmail:         return "Please enter a valid email address."
        default:                    return error.localizedDescription
        }
    }

    // MARK: - Apple Sign-In Helpers

    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        // Use rejection sampling to eliminate modulo bias:
        // charset.count (66) does not divide 256 evenly, so bytes >= 66 are discarded.
        var result = [Character]()
        result.reserveCapacity(length)
        while result.count < length {
            var batch = [UInt8](repeating: 0, count: length - result.count)
            let status = SecRandomCopyBytes(kSecRandomDefault, batch.count, &batch)
            if status != errSecSuccess {
                fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(status)")
            }
            for byte in batch where Int(byte) < charset.count && result.count < length {
                result.append(charset[Int(byte)])
            }
        }
        return String(result)
    }

    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        return hashedData.compactMap { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - Apple Sign-In Coordinator

/// Bridges ASAuthorizationControllerDelegate (callback-based) to async/await continuation.
private final class AppleSignInCoordinator: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {

    private let continuation: CheckedContinuation<ASAuthorizationAppleIDCredential, Error>

    init(continuation: CheckedContinuation<ASAuthorizationAppleIDCredential, Error>) {
        self.continuation = continuation
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
            continuation.resume(returning: appleIDCredential)
        } else {
            continuation.resume(throwing: AuthError.unknown("Apple Sign-In returned unexpected credential type."))
        }
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        continuation.resume(throwing: error)
    }

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }
            ?? UIWindow()
    }
}
