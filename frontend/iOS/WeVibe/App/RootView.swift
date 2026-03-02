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

// Unauthenticated flow: Splash → Login/Register/ForgotPassword
struct AuthFlowView: View {
    @State private var authRouter = AuthRouter()
    @State private var showLogin = false
    @State private var showRegister = false
    @State private var showForgotPassword = false

    var body: some View {
        ZStack {
            SplashScreen(showLogin: $showLogin)

            if showLogin {
                LoginScreen(showLogin: $showLogin, showRegister: $showRegister, showForgotPassword: $showForgotPassword)
                    .transition(.move(edge: .bottom))
                    .zIndex(1)
            }

            if showRegister {
                RegisterScreen(showRegister: $showRegister)
                    .transition(.move(edge: .trailing))
                    .zIndex(2)
            }

            if showForgotPassword {
                ForgotPasswordScreen(showForgotPassword: $showForgotPassword)
                    .transition(.move(edge: .trailing))
                    .zIndex(3)
            }
        }
        .animation(.easeInOut(duration: 0.5), value: showLogin)
        .animation(.easeInOut(duration: 0.5), value: showRegister)
        .animation(.easeInOut(duration: 0.5), value: showForgotPassword)
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
