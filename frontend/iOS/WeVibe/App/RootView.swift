import SwiftUI

// MARK: - RootView

// Driven entirely by AuthManager.appState — swapping state swaps the whole view tree.
struct RootView: View {

    @Environment(AuthManager.self) private var authManager
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
            if let error = authManager.globalError {
                ErrorToast(message: error) {
                    authManager.globalError = nil
                }
                .transition(.move(edge: .top).combined(with: .opacity))
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: authManager.globalError != nil)
            }
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
