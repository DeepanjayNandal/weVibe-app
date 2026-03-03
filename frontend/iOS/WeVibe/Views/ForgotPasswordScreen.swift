import SwiftUI

struct ForgotPasswordScreen: View {

    @Binding var showForgotPassword: Bool

    @Environment(AuthManager.self) private var authManager

    @State private var email: String = ""
    @State private var emailError: String?
    @State private var isLoading: Bool = false
    @State private var didSend: Bool = false

    var body: some View {
        ZStack {
            AppTheme.primaryBackground
                .ignoresSafeArea()

            VStack(spacing: 10) {
                Button(action: { showForgotPassword = false }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .semibold))
                        Text("Back")
                            .font(.system(size: 17))
                    }
                    .foregroundStyle(.white)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 8)

                Spacer()

                LogoView(size: 170)
                if didSend {
                    sentView
                } else {
                    formView
                }

                Spacer()
                Spacer()
            }
            .padding(.horizontal, 19)
        }
    }

    // MARK: - Form View

    private var formView: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Forgot Password")
                .foregroundStyle(.white)
                .font(.system(size: 24, weight: .bold))
                .padding(.bottom, 2)

            Text("Enter your email and we'll send you a link to reset your password.")
                .foregroundStyle(AppTheme.secondaryText)
                .font(.system(size: 15))
                .padding(.bottom, 8)

            VStack(alignment: .leading, spacing: 6) {
                Text("Email")
                    .foregroundStyle(.white)
                    .font(.system(size: 16, weight: .medium))

                TextField("", text: $email)
                    .padding(.horizontal, 16)
                    .frame(height: 52)
                    .background(.white)
                    .foregroundStyle(.black)
                    .cornerRadius(14)
                    .keyboardType(.emailAddress)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .onChange(of: email) { _, _ in emailError = nil }

                if let emailError {
                    Text(emailError)
                        .foregroundStyle(.red)
                        .font(.system(size: 12))
                }
            }

            PrimaryButton(
                title: "Send Reset Email",
                background: AppTheme.primaryButton,
                foreground: .white,
                height: 50,
                isLoading: isLoading,
                isDisabled: email.isEmpty
            ) {
                if validate() { performReset() }
            }
            .padding(.top, 8)
        }
    }

    // MARK: - Sent Confirmation View

    private var sentView: some View {
        VStack(spacing: 20) {
            Image(systemName: "envelope.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(AppTheme.primaryButton)
                .padding(.top, 20)

            Text("Check your inbox")
                .foregroundStyle(.white)
                .font(.system(size: 24, weight: .bold))

            Text("If that email is registered, you'll receive a reset link shortly. Check your spam folder if it doesn't arrive within a few minutes.")
                .foregroundStyle(AppTheme.secondaryText)
                .font(.system(size: 15))
                .multilineTextAlignment(.center)

            PrimaryButton(
                title: "Back to Login",
                background: AppTheme.primaryButton,
                foreground: .white,
                height: 50,
                isLoading: false,
                isDisabled: false
            ) {
                showForgotPassword = false
            }
            .padding(.top, 8)
        }
    }

    // MARK: - Validation

    private func validate() -> Bool {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        email = trimmed

        let emailRegex = "^[^\\s@]+@[^\\s@]+\\.[^\\s@]+$"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)

        if trimmed.isEmpty {
            emailError = "Email is required"
            return false
        } else if trimmed.count > 254 {
            emailError = "Email is too long"
            return false
        } else if !emailPredicate.evaluate(with: trimmed) {
            emailError = "Invalid email format"
            return false
        }
        return true
    }

    // MARK: - Reset Action

    private func performReset() {
        isLoading = true
        Task {
            defer { isLoading = false }
            do {
                try await authManager.forgotPassword(email: email)
            } catch {
                // Intentionally ignored — always show success to prevent email enumeration.
                // When Firebase SDK is active, distinguish AuthErrorCode.userNotFound
                // (silence it) from network errors (surface them) if desired.
            }
            // Show confirmation regardless of outcome — prevents email enumeration.
            didSend = true
        }
    }
}
