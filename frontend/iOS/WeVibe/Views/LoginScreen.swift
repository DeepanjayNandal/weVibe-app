import SwiftUI

struct LoginScreen: View {
    @State private var email: String = ""
    @State private var password: String = ""

    @Environment(Router.self) private var router
    @State private var emailError: String?
    @State private var passwordError: String?
    @State private var isPasswordVisible: Bool = false
    @State private var isLoading: Bool = false
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
                        .onChange(of: email) { _, _ in emailError = nil }

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
                                .onChange(of: password) { _, _ in passwordError = nil }
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
                                .onChange(of: password) { _, _ in passwordError = nil }
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
                    Button(action: {}) {
                        Text("Forgot Password?")
                            .foregroundStyle(.white)
                            .underline()
                            .font(.system(size: 14))
                    }

                    Spacer()

                    Button(action: { router.navigateToRegister() }) {
                        Text("Sign up")
                            .foregroundStyle(AppTheme.smallText)
                            .underline()
                            .font(.system(size: 14))
                    }
                }
                .padding(.top, 4)

                PrimaryButton(
                    title: "Sign in",
                    background: Color.white,
                    foreground: AppTheme.primaryBackground,
                    height: 50,
                    isLoading: isLoading,
                    isDisabled: email.isEmpty || password.isEmpty
                ) {
                    if validate() { performLogin() }
                }
                .padding(.top, 8)
                .padding(.bottom, 16)

                Button {
                } label: {
                    HStack {
                        Text("Continue with Google")
                            .bold()
                        Image(systemName: "g.circle.fill")
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(AppTheme.secondaryButton)
                    .foregroundStyle(.white)
                    .cornerRadius(14)
                }

                Button {
                } label: {
                    HStack {
                        Text("Continue with Apple")
                            .bold()
                        Image(systemName: "apple.logo")
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Color(hex: "145c3e"))
                    .foregroundStyle(.white)
                    .cornerRadius(14)
                }
            }
            .padding(.horizontal, 24)
        }
    }

    private func validate() -> Bool {
        var isValid = true
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)

        // Simple regex: ^[^\s@]+@[^\s@]+\.[^\s@]+$
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

    private func performLogin() {
        isLoading = true
        
        // Simulate API call
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            isLoading = false
            router.navigateToHome()
        }
    }
}
