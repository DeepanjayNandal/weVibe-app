import SwiftUI

struct ConfirmScreen: View {

    @Environment(Router.self) private var router
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?

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
                    Task {
                        isLoading = true
                        defer { isLoading = false }
                        do {
                            try await verifyEmail()
                            router.navigateToBeginScreen()
                        } catch {
                            errorMessage = "Verification failed. Please try again."
                        }
                    }
                } label: {
                    Group {
                        if isLoading {
                            ProgressView().tint(.white)
                        } else {
                            Text("Email Confirmed")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(.white)
                        }
                    }
                    .frame(minWidth: 180)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 16)
                    .background(Color(hex: "#05664F"))
                    .clipShape(Capsule())
                }
                .disabled(isLoading)
                .padding(.top, 18)

                if let errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                        .font(.system(size: 14))
                }
            }
            .padding(.horizontal, 24)
        }
    }

    /// TODO: Replace with real API call.
    private func verifyEmail() async throws {
        try await Task.sleep(nanoseconds: 1_500_000_000)
    }
}
