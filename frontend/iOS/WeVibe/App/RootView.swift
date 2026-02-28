import SwiftUI

// MARK: - RootView

// Driven entirely by AuthManager.appState — swapping state swaps the whole view tree.
struct RootView: View {

    @Environment(AuthManager.self) private var authManager

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

// Unauthenticated flow: Splash → Login/Register
struct AuthFlowView: View {
    @State private var authRouter = AuthRouter()

    var body: some View {
        NavigationStack(path: $authRouter.path) {
            SplashScreen()
                .navigationDestination(for: AuthRoute.self) { route in
                    switch route {
                    case .login:    LoginScreen()
                    case .register: RegisterScreen()
                    }
                }
        }
        .environment(authRouter)
    }
}

// MARK: - Onboarding Flow

// Onboarding flow: welcome screen → survey steps
struct OnboardingFlowView: View {
    @State private var onboardingRouter = OnboardingRouter()

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
