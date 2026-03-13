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

    // MARK: - Private

    /// Nonce used for Apple Sign-In — must be stored for Firebase credential creation.
    private var currentNonce: String?

    private let apiClient = APIClient()

    // MARK: - Launch

    /// Registers a persistent Firebase Auth state listener. Fires immediately with current state.
    func checkAuthState() async {
        Auth.auth().addStateDidChangeListener { [weak self] _, user in
            guard let self else { return }
            guard let user else {
                Task { @MainActor in self.appState = .unauthenticated }
                return
            }
            if !user.isEmailVerified {
                Task { @MainActor in
                    self.appState = .pendingVerification
                    self.pendingVerificationEmail = user.email ?? ""
                }
                return
            }
            Task { await self.resolvePostAuthState() }
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
                globalError = error.localizedDescription
            }
        }
    }

    // MARK: - Sign Out

    func logout() {
        try? Auth.auth().signOut()
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
            let hasProfile = try await apiClient.checkProfile(token: token)
            appState = hasProfile ? .authenticated : .onboarding
        } catch APIError.noProfile {
            appState = .onboarding
        } catch APIError.unauthorized {
            appState = .unauthenticated
        } catch {
            appState = .onboarding
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
        var randomBytes = [UInt8](repeating: 0, count: length)
        let errorCode = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        if errorCode != errSecSuccess {
            fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
        }
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        return String(randomBytes.map { byte in charset[Int(byte) % charset.count] })
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
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            fatalError("No window available for Apple Sign-In presentation")
        }
        return window
    }
}
