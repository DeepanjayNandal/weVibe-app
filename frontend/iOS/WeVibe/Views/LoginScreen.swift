import SwiftUI

struct LoginScreen: View {
    @State private var email: String = ""
    @State private var password: String = ""

    @Environment(AuthRouter.self) private var authRouter
    @Environment(AuthManager.self) private var authManager
    
    @Binding var showLogin: Bool
    @Binding var showRegister: Bool
    @Binding var showForgotPassword: Bool

    @State private var emailError: String?
    @State private var passwordError: String?
    @State private var authError: String?
    @State private var isPasswordVisible: Bool = false
    @State private var isLoading: Bool = false
    @State private var isSSOLoading: Bool = false
    @FocusState private var isPasswordFocused: Bool

    var body: some View {
        ZStack {
            AppTheme.primaryBackground
                .ignoresSafeArea()

            VStack(spacing: 10) {
                LogoView(size: 170)

                Text("Log In")
                    .foregroundStyle(.white)
                    .font(.title)
                    .bold()
                    .padding(.bottom, 10)

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
                        .onChange(of: email) { _, _ in emailError = nil; authError = nil }

                    if let emailError {
                        Text(emailError)
                            .foregroundStyle(.red)
                            .font(.system(size: 12))
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Password")
                        .foregroundStyle(.white)
                        .font(.system(size: 16, weight: .medium))

                    ZStack(alignment: .trailing) {
                        if isPasswordVisible {
                            TextField("", text: $password)
                                .padding(.horizontal, 16)
                                .padding(.trailing, 40)
                                .frame(height: 52)
                                .background(.white)
                                .foregroundStyle(.black)
                                .cornerRadius(14)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .focused($isPasswordFocused)
                                .onChange(of: password) { _, _ in passwordError = nil; authError = nil }
                        } else {
                            SecureField("", text: $password)
                                .padding(.horizontal, 16)
                                .padding(.trailing, 40)
                                .frame(height: 52)
                                .background(.white)
                                .foregroundStyle(.black)
                                .cornerRadius(14)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .focused($isPasswordFocused)
                                .onChange(of: password) { _, _ in passwordError = nil; authError = nil }
                        }

                        Button(action: {
                            let wasFocused = isPasswordFocused
                            isPasswordVisible.toggle()
                            if wasFocused { isPasswordFocused = true }
                        }) {
                            Image(systemName: isPasswordVisible ? "eye" : "eye.slash")
                                .foregroundStyle(.gray)
                                .padding(.trailing, 16)
                        }
                    }

                    if let passwordError {
                        Text(passwordError)
                            .foregroundStyle(.red)
                            .font(.system(size: 12))
                    }
                }

                HStack {
                    Button(action: { showForgotPassword = true }) {
                        Text("Forgot Password?")
                            .foregroundStyle(Color.white)
                            .underline()
                            .font(.system(size: 16))
                    }

                    Spacer()

                    Button(action: { showRegister = true }) {
                        Text("Sign up")
                            .foregroundStyle(AppTheme.smallText)
                            .underline()
                            .font(.system(size: 16))
                    }
                }
                .padding(.top, 4)

                if let authError {
                    Text(authError)
                        .foregroundStyle(.red)
                        .font(.system(size: 13))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 2)
                }

                PrimaryButton(
                    title: "Sign in",
                    background: AppTheme.primaryButton,
                    foreground:  Color.white,
                    height: 50,
                    isLoading: isLoading,
                    isDisabled: email.isEmpty || password.isEmpty || isSSOLoading
                ) {
                    if validate() { performLogin() }
                }
                .padding(.top, 8)
                .padding(.bottom, 16)

                Button {
                    performSSOLogin(provider: .google)
                } label: {
                    HStack {
                        Text("Continue with Google")
                            .bold()
                        Image(systemName: "g.circle.fill")
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.white)
                    .foregroundStyle(Color.black)
                    .cornerRadius(14)
                    .opacity(isSSOLoading || isLoading ? 0.6 : 1)
                }
                .disabled(isLoading || isSSOLoading)

                Button {
                    performSSOLogin(provider: .apple)
                } label: {
                    HStack {
                        Text("Continue with Apple")
                            .bold()
                        Image(systemName: "apple.logo")
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Color.black)
                    .foregroundStyle(Color.white)
                    .cornerRadius(14)
                    .opacity(isSSOLoading || isLoading ? 0.6 : 1)
                }
                .disabled(isLoading || isSSOLoading)
            }
            .padding(.horizontal, 24)
        }
        .navigationBarBackButtonHidden(false)
    }

    // MARK: - Validation

    private func validate() -> Bool {
        var isValid = true
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let emailRegex = "^[^\\s@]+@[^\\s@]+\\.[^\\s@]+$"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        email = trimmedEmail

        if trimmedEmail.isEmpty {
            emailError = "Email is required"
            isValid = false
        } else if trimmedEmail.count > 254 {
            emailError = "Email is too long"
            isValid = false
        } else if !emailPredicate.evaluate(with: trimmedEmail) {
            emailError = "Invalid email format"
            isValid = false
        }

        if password.isEmpty {
            passwordError = "Password is required"
            isValid = false
        }

        return isValid
    }

    // MARK: - Auth Actions

    private func performLogin() {
        isLoading = true
        authError = nil
        Task {
            defer { isLoading = false }
            do {
                try await authManager.login(email: email, password: password)
                // AppState change in AuthManager automatically advances RootView.
            } catch {
                authError = error.localizedDescription
            }
        }
    }

    private enum SSOProvider { case google, apple }

    private func performSSOLogin(provider: SSOProvider) {
        isSSOLoading = true
        authError = nil
        Task {
            defer { isSSOLoading = false }
            do {
                switch provider {
                case .google: try await authManager.loginWithGoogle()
                case .apple:  try await authManager.loginWithApple()
                }
            } catch {
                authError = error.localizedDescription
            }
        }
    }
}
