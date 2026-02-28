import SwiftUI

struct SplashScreen: View {
    @Environment(AuthRouter.self) private var authRouter

    var body: some View {
        ZStack {
            AppTheme.primaryBackground
                .ignoresSafeArea()

            LogoView(size: 170)

            VStack {
                Spacer()

                PrimaryButton(
                    title: "Get Started",
                    background: AppTheme.primaryButton,
                    foreground: Color.white,
                    height: 54
                ) {
                    authRouter.navigate(to: .login)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 56)
            }
        }
        .navigationBarBackButtonHidden(true)
    }
}
