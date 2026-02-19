import SwiftUI

struct ThankAndBegin: View {

    @Environment(Router.self) private var router

    var body: some View {
        ZStack {
            AppTheme.primaryBackground
                .ignoresSafeArea()

            VStack(spacing: 16) {
                Text("Welcome To")
                    .foregroundStyle(.white)
                    .font(.system(size: 28, weight: .bold))
                    .padding(.bottom, 10)

                LogoView(size: 130)

                Text("Complete your profile so that you can begin your dating journey.")
                    .foregroundStyle(.white.opacity(0.8))
                    .font(.system(size: 16, weight: .regular))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)

                Button {
                        router.navigateToLogin()
                } label: {
                        Text("Begin")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(AppTheme.primaryBackground)
                            .padding(.horizontal, 32)
                            .padding(.vertical, 16)
                            .background(.white)
                            .clipShape(Capsule())
                }
                .padding(.top, 40)
            }

            .padding(.horizontal, 24)
        }
    }
}
