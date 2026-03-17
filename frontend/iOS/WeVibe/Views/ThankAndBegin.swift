import SwiftUI

struct ThankAndBegin: View {

    @Environment(OnboardingRouter.self) private var onboardingRouter
    @Environment(AuthManager.self) private var authManager
    @Environment(UserProfileStore.self) private var profileStore
    @Environment(OnboardingData.self) private var onboardingData

    var body: some View {
        ZStack {
            AppTheme.primaryBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    Button("Log Out") {
                        authManager.logout(profileStore: profileStore, onboardingData: onboardingData)
                    }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white.opacity(0.6))
                    .padding(.top, 16)
                    .padding(.trailing, 24)
                }

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
                    background: AppTheme.primaryButton,
                    foreground: Color.white,
                    height: 54,
                    width: 220,
                    cornerRadius: 22
                ) {
                    onboardingRouter.navigate(to: .step1)
                }
                .padding(.horizontal, 60)
                .padding(.bottom, 136)
            }
        }
        .navigationBarBackButtonHidden(true)
    }
}
