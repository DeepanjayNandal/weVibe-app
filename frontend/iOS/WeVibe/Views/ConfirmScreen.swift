import SwiftUI

struct ConfirmScreen: View {

    @Environment(Router.self) private var router

    var body: some View {
        ZStack {
            AppTheme.primaryBackground
                .ignoresSafeArea()

            VStack(spacing: 16) {
                Text("Thanks For Signing Up!")
                    .foregroundStyle(.white)
                    .font(.system(size: 28, weight: .bold))
                    .padding(.bottom, 10)

                Text("Please confirm your email by clicking on the registration link provided in the email.")
                    .foregroundStyle(.white.opacity(0.8))
                    .font(.system(size: 16, weight: .regular))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)

                Button {
                        router.navigateToBeginScreen()
                } label: {
                        Text("Email Confirmed")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 32)
                            .padding(.vertical, 16)
                            .background(Color(hex: "#05664F"))
                            .clipShape(Capsule())
                }
                .padding(.top, 18)
            }

            .padding(.horizontal, 24)
        }
    }
}
