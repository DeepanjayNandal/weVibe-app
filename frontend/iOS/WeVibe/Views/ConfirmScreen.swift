import SwiftUI

struct ConfirmScreen: View {

    @Environment(AuthManager.self) private var authManager

    @State private var isResending: Bool = false
    @State private var isChecking: Bool = false
    @State private var resendCooldown: Int = 0
    @State private var errorMessage: String?
    @State private var resentSuccess: Bool = false

    var body: some View {
        ZStack {
            AppTheme.primaryBackground
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Spacer()

                Image(systemName: "envelope.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(AppTheme.buttonGradient)

                Text("Check Your Inbox")
                    .foregroundStyle(.white)
                    .font(.system(size: 28, weight: .bold))

                VStack(spacing: 8) {
                    Text("We sent a verification link to")
                        .foregroundStyle(.white.opacity(0.7))
                        .font(.system(size: 16))

                    if !authManager.pendingVerificationEmail.isEmpty {
                        Text(authManager.pendingVerificationEmail)
                            .foregroundStyle(.white)
                            .font(.system(size: 16, weight: .semibold))
                    }

                    Text("Tap the link in the email to verify your account and continue.")
                        .foregroundStyle(.white.opacity(0.6))
                        .font(.system(size: 14))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                        .padding(.top, 4)
                }

                if resentSuccess {
                    Label("Email resent!", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.system(size: 14, weight: .medium))
                        .transition(.opacity)
                }

                if let errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                        .font(.system(size: 14))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                        .transition(.opacity)
                }

                Spacer()

                VStack(spacing: 12) {
                    // Resend button with 60s cooldown
                    Button {
                        resendEmail()
                    } label: {
                        Group {
                            if isResending {
                                ProgressView().tint(.white)
                            } else if resendCooldown > 0 {
                                Text("Resend in \(resendCooldown)s")
                            } else {
                                Text("Resend Email")
                            }
                        }
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(AppTheme.secondaryButton)
                        .cornerRadius(14)
                    }
                    .disabled(isResending || resendCooldown > 0 || isChecking)

                    // Fallback: if the deep link didn't open the app, let the user manually trigger a check
                    Button {
                        checkVerification()
                    } label: {
                        Group {
                            if isChecking {
                                ProgressView().tint(AppTheme.primaryBackground)
                            } else {
                                Text("I've verified my email")
                            }
                        }
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(AppTheme.primaryBackground)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(.white)
                        .cornerRadius(14)
                    }
                    .disabled(isChecking || isResending)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 48)
            }
        }
    }

    // MARK: - Actions

    private func resendEmail() {
        isResending = true
        resentSuccess = false
        errorMessage = nil
        Task {
            defer { isResending = false }
            do {
                try await authManager.resendVerificationEmail()
                resentSuccess = true
                startCooldown(seconds: 60)
            } catch {
                errorMessage = "Failed to resend. Please try again."
            }
        }
    }

    private func checkVerification() {
        isChecking = true
        errorMessage = nil
        Task {
            defer { isChecking = false }
            do {
                // Reloads Firebase user and checks isEmailVerified.
                // On success, AuthManager advances appState to .onboarding.
                try await authManager.checkEmailVerified()
            } catch {
                errorMessage = "Not verified yet. Please tap the link in your email first."
            }
        }
    }

    private func startCooldown(seconds: Int) {
        resendCooldown = seconds
        Task {
            while resendCooldown > 0 {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                resendCooldown -= 1
            }
        }
    }
}
