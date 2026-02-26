import SwiftUI
struct SplashScreen: View {
    @Environment(Router.self) private var router

    var body: some View {
        ZStack {
            AppTheme.primaryBackground
                .ignoresSafeArea()

            VStack {
                Spacer()

                LogoView(size: 170)

                Spacer()

                PrimaryButton(
                    title: "Get Started",
                    background: AppTheme.buttonGradient,
                    foreground: .white,
                    height: 54
                ) {
                    router.navigateToLogin()
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 56)
            }
        }
    }
}

#Preview {
    SplashScreen()
}
