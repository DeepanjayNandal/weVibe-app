import SwiftUI

// MARK: - RootView

// Driven entirely by AuthManager.appState — swapping state swaps the whole view tree.
struct RootView: View {

    @Environment(AuthManager.self) private var authManager
    @Environment(NetworkMonitor.self) private var networkMonitor
    @EnvironmentObject private var locationManager: LocationManager

    var body: some View {
        ZStack {
            switch authManager.appState {
            case .launching:
                LaunchView()
            case .unauthenticated:
                AuthFlowView()
            case .pendingVerification:
                ConfirmScreen()
            case .onboarding:
                OnboardingFlowView()
            case .authenticated:
                HomeScreen()
            case .networkError:
                NetworkErrorView()
            }

            // Block the entire app when location permission is denied/restricted.
            // Dismissed automatically when the user grants permission in Settings and returns.
            if locationManager.authStatus == .denied || locationManager.authStatus == .restricted {
                LocationPermissionScreen()
                    .transition(.opacity)
                    .animation(.easeInOut(duration: 0.3), value: locationManager.authStatus)
                    .zIndex(100)
            }
        }
        .overlay(alignment: .top) {
            VStack(spacing: 0) {
                if !networkMonitor.isConnected {
                    HStack(spacing: 6) {
                        Image(systemName: "wifi.slash")
                            .font(.system(size: 12, weight: .medium))
                        Text("No internet connection")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color.black.opacity(0.85))
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
                if let error = authManager.globalError {
                    ErrorToast(message: error) {
                        authManager.globalError = nil
                    }
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: networkMonitor.isConnected)
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: authManager.globalError != nil)
        }
    }
}

// MARK: - Launch View

// Shown briefly on launch while we check for a saved session.
struct LaunchView: View {
    var body: some View {
        ZStack {
            AppTheme.primaryBackground.ignoresSafeArea()
            LogoView(size: 170)
        }
    }
}

// MARK: - Auth Flow

// Unauthenticated flow: Splash → Login/Register/ForgotPassword
struct AuthFlowView: View {
    @State private var authRouter = AuthRouter()

    var body: some View {
        NavigationStack(path: $authRouter.path) {
            SplashScreen()
                .navigationDestination(for: AuthRoute.self) { route in
                    switch route {
                    case .login:         LoginScreen()
                    case .register:      RegisterScreen()
                    case .forgotPassword: ForgotPasswordScreen()
                    }
                }
        }
        .navigationBarHidden(true)
        .environment(authRouter)
    }
}

// MARK: - Network Error View

// Shown when Firebase session exists but backend is unreachable.
// "Try Again" re-runs the post-auth check; "Sign Out" returns to login.
struct NetworkErrorView: View {

    @Environment(AuthManager.self) private var authManager
    @Environment(UserProfileStore.self) private var profileStore
    @Environment(OnboardingData.self) private var onboardingData
    @Environment(ChatStore.self) private var chatStore

    @State private var isRetrying = false

    var body: some View {
        ZStack {
            AppTheme.primaryBackground.ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                LogoView(size: 80)

                Image(systemName: "wifi.slash")
                    .font(.system(size: 52))
                    .foregroundStyle(.white.opacity(0.5))

                VStack(spacing: 8) {
                    Text("No Connection")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(.white)
                    Text("Check your internet connection\nand try again.")
                        .font(.system(size: 15))
                        .foregroundStyle(.white.opacity(0.6))
                        .multilineTextAlignment(.center)
                }

                Button {
                    isRetrying = true
                    Task {
                        await authManager.retryConnection()
                        isRetrying = false
                    }
                } label: {
                    Group {
                        if isRetrying {
                            ProgressView().tint(AppTheme.primaryBackground)
                        } else {
                            Text("Try Again")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(AppTheme.primaryBackground)
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .background(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 25))
                }
                .disabled(isRetrying)
                .padding(.horizontal, 40)

                Spacer()

                Button("Sign out") {
                    authManager.logout(profileStore: profileStore, onboardingData: onboardingData, chatStore: chatStore)
                }
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.4))
                .padding(.bottom, 32)
            }
        }
    }
}

// MARK: - Onboarding Flow

// Onboarding flow: welcome screen → survey steps
struct OnboardingFlowView: View {
    @State private var onboardingRouter = OnboardingRouter()
    // OnboardingData is injected from WeVibeApp at app level

    var body: some View {
        NavigationStack(path: $onboardingRouter.path) {
            ThankAndBegin()
                .navigationDestination(for: OnboardingRoute.self) { route in
                    switch route {
                    case .step1: SurveyStep1()
                    case .step2: SurveyStep2()
                    case .step3: SurveyStep3()
                    case .step4: SurveyStep4()
                    case .step5: SurveyStep5()
                    }
                }
        }
        .environment(onboardingRouter)
    }
}
