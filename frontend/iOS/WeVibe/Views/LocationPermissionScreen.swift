import SwiftUI

struct LocationPermissionScreen: View {

    var body: some View {
        ZStack {
            AppTheme.primaryBackground.ignoresSafeArea()

            VStack(spacing: 10) {
                Spacer()

                LogoView(size: 170)

                VStack(spacing: 20) {
                    Text("Location Required")
                        .foregroundStyle(.white)
                        .font(.system(size: 24, weight: .bold))
                        .padding(.top, 24)

                    Text("WeVibe uses your location to show you matches nearby. Please enable location access in Settings to continue.")
                        .foregroundStyle(AppTheme.secondaryText)
                        .font(.system(size: 15))
                        .multilineTextAlignment(.center)

                    PrimaryButton(
                        title: "Open Settings",
                        background: AppTheme.primaryButton,
                        foreground: .white,
                        height: 50,
                        isLoading: false,
                        isDisabled: false
                    ) {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                    .padding(.top, 8)
                }

                Spacer()
                Spacer()
            }
            .padding(.horizontal, 24)
        }
    }
}
