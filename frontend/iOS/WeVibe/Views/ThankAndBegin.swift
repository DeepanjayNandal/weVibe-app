import SwiftUI

struct ThankAndBegin: View {

    @Environment(Router.self) private var router

    var body: some View {
        ZStack {
            AppTheme.primaryBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 16) {
                    Text("Welcome To")
                        .foregroundStyle(.white)
                        .font(.system(size: 28, weight: .bold))

                    LogoView(size: 170)

                    Text("Complete your profile so that you can begin your dating journey.")
                        .foregroundStyle(.white.opacity(0.7))
                        .font(.system(size: 16, weight: .regular))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                Spacer()
                Spacer()

                PrimaryButton(
                    title: "Begin",
                    background: Color.white,
                    foreground: AppTheme.primaryBackground,
                    height: 54,
                    width: 220,
                    cornerRadius: 22
                ) {
                    router.navigateSurveyStep1()
                }
                .padding(.horizontal, 60)
                .padding(.bottom, 136)
            }
        }
    }
}
