import SwiftUI

struct RegisterScreen: View {

    // MARK: - Form State
    @State private var firstName: String = ""
    @State private var lastName: String = ""
    @State private var email: String = ""
    @State private var confirmEmail: String = ""
    @State private var password: String = ""
    @State private var confirmPassword: String = ""

    // MARK: - Validation Errors
    @State private var firstNameError: String?
    @State private var lastNameError: String?
    @State private var emailError: String?
    @State private var confirmEmailError: String?
    @State private var passwordError: String?
    @State private var confirmPasswordError: String?
    @State private var authError: String?

    // MARK: - UI State
    @State private var isPasswordVisible: Bool = false
    @State private var isConfirmPasswordVisible: Bool = false
    @State private var isLoading: Bool = false
    @State private var showPasswordRules: Bool = false
    @FocusState private var isPasswordFocused: Bool
    @FocusState private var isConfirmPasswordFocused: Bool

    // Excludes injection-risk chars: < > ' " ; & | \ / ` ( ) { } [ ]
    private let specialCharacters = CharacterSet(charactersIn: "!@#$%^*_+=~?-")

    @Environment(AuthManager.self) private var authManager
    @Environment(AuthRouter.self) private var authRouter
    @Binding var showRegister: Bool


    private var isFormEmpty: Bool {
        firstName.isEmpty || lastName.isEmpty || email.isEmpty ||
        confirmEmail.isEmpty || password.isEmpty || confirmPassword.isEmpty
    }

    // MARK: - Body
    var body: some View {
        ZStack {
            AppTheme.primaryBackground
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 10) {
                    Button(action: { showRegister = false }) {
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
                    
                    
                    LogoView(size: 130)

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Sign Up")
                            .foregroundStyle(Color.white)
                            .font(.system(size: 24, weight: .bold))
                            .padding(.bottom, 10)

                        // MARK: Name Row
                        HStack(alignment: .top, spacing: 10) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("First Name")
                                    .foregroundStyle(.white)
                                    .font(.system(size: 16, weight: .medium))

                                TextField("", text: $firstName)
                                    .padding(.horizontal, 16)
                                    .frame(height: 52)
                                    .background(.white)
                                    .foregroundStyle(.black)
                                    .cornerRadius(14)
                                    .autocorrectionDisabled()
                                    .textInputAutocapitalization(.words)
                                    .onChange(of: firstName) { _, _ in firstNameError = nil }

                                if let firstNameError {
                                    Text(firstNameError)
                                        .foregroundStyle(.red)
                                        .font(.system(size: 12))
                                }
                            }

                            VStack(alignment: .leading, spacing: 6) {
                                Text("Last Name")
                                    .foregroundStyle(.white)
                                    .font(.system(size: 16, weight: .medium))

                                TextField("", text: $lastName)
                                    .padding(.horizontal, 16)
                                    .frame(height: 52)
                                    .background(.white)
                                    .foregroundStyle(.black)
                                    .cornerRadius(14)
                                    .autocorrectionDisabled()
                                    .textInputAutocapitalization(.words)
                                    .onChange(of: lastName) { _, _ in lastNameError = nil }

                                if let lastNameError {
                                    Text(lastNameError)
                                        .foregroundStyle(.red)
                                        .font(.system(size: 12))
                                }
                            }
                        }

                        // MARK: Email
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
                        .padding(.top, 4)

                        // MARK: Confirm Email
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Confirm Email")
                                .foregroundStyle(.white)
                                .font(.system(size: 16, weight: .medium))

                            TextField("", text: $confirmEmail)
                                .padding(.horizontal, 16)
                                .frame(height: 52)
                                .background(.white)
                                .foregroundStyle(.black)
                                .cornerRadius(14)
                                .keyboardType(.emailAddress)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                                .onChange(of: confirmEmail) { _, _ in confirmEmailError = nil }

                            if let confirmEmailError {
                                Text(confirmEmailError)
                                    .foregroundStyle(.red)
                                    .font(.system(size: 12))
                            }
                        }
                        .padding(.top, 4)

                        // MARK: Password
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 6) {
                                Text("Password")
                                    .foregroundStyle(.white)
                                    .font(.system(size: 16, weight: .medium))

                                Button {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        showPasswordRules.toggle()
                                    }
                                } label: {
                                    Image(systemName: showPasswordRules ? "info.circle.fill" : "info.circle")
                                        .foregroundStyle(.white.opacity(0.6))
                                        .font(.system(size: 14))
                                }
                            }

                            if showPasswordRules {
                                VStack(alignment: .leading, spacing: 5) {
                                    passwordRuleRow("At least 8 characters",
                                        satisfied: password.count >= 8)
                                    passwordRuleRow("One lowercase letter",
                                        satisfied: password.contains(where: { $0.isLowercase }))
                                    passwordRuleRow("One uppercase letter",
                                        satisfied: password.contains(where: { $0.isUppercase }))
                                    passwordRuleRow("One number",
                                        satisfied: password.contains(where: { $0.isNumber }))
                                    passwordRuleRow("One special character  ! @ # $ % ^ * _ + = ~ ? -",
                                        satisfied: password.unicodeScalars.contains(where: { specialCharacters.contains($0) }))
                                }
                                .padding(12)
                                .background(AppTheme.secondaryBackground)
                                .cornerRadius(10)
                                .transition(.opacity.combined(with: .move(edge: .top)))
                            }

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
                        .padding(.top, 4)

                        // MARK: Confirm Password
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Confirm Password")
                                .foregroundStyle(.white)
                                .font(.system(size: 16, weight: .medium))

                            ZStack(alignment: .trailing) {
                                if isConfirmPasswordVisible {
                                    TextField("", text: $confirmPassword)
                                        .padding(.horizontal, 16)
                                        .padding(.trailing, 40)
                                        .frame(height: 52)
                                        .background(.white)
                                        .foregroundStyle(.black)
                                        .cornerRadius(14)
                                        .textInputAutocapitalization(.never)
                                        .autocorrectionDisabled()
                                        .focused($isConfirmPasswordFocused)
                                        .onChange(of: confirmPassword) { _, _ in confirmPasswordError = nil }
                                } else {
                                    SecureField("", text: $confirmPassword)
                                        .padding(.horizontal, 16)
                                        .padding(.trailing, 40)
                                        .frame(height: 52)
                                        .background(.white)
                                        .foregroundStyle(.black)
                                        .cornerRadius(14)
                                        .focused($isConfirmPasswordFocused)
                                        .onChange(of: confirmPassword) { _, _ in confirmPasswordError = nil }
                                }

                                Button(action: {
                                    let wasFocused = isConfirmPasswordFocused
                                    isConfirmPasswordVisible.toggle()
                                    if wasFocused { isConfirmPasswordFocused = true }
                                }) {
                                    Image(systemName: isConfirmPasswordVisible ? "eye" : "eye.slash")
                                        .foregroundStyle(.gray)
                                        .padding(.trailing, 16)
                                }
                            }

                            if let confirmPasswordError {
                                Text(confirmPasswordError)
                                    .foregroundStyle(.red)
                                    .font(.system(size: 12))
                            }
                        }
                        .padding(.top, 4)

                        if let authError {
                            Text(authError)
                                .foregroundStyle(.red)
                                .font(.system(size: 13))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.top, 4)
                        }

                        PrimaryButton(
                            title: "Sign Up",
                            background: AppTheme.secondaryButton,
                            foreground: .white,
                            height: 50,
                            isLoading: isLoading,
                            isDisabled: isFormEmpty
                        ) {
                            if validate() { performSignUp() }
                        }
                        .padding(.top, 12)
                        .padding(.bottom, 16)
                    }
                }
                .padding(.horizontal, 24)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .onTapGesture {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
    }

    // MARK: - Password Rule Row
    @ViewBuilder
    private func passwordRuleRow(_ text: String, satisfied: Bool) -> some View {
        Label(text, systemImage: satisfied ? "checkmark.circle.fill" : "circle")
            .font(.system(size: 12))
            .foregroundStyle(satisfied ? AppTheme.primaryButton : .white.opacity(0.5))
    }

    // MARK: - Validation
    private func validate() -> Bool {
        var isValid = true

        let trimmedFirstName = firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        firstName = trimmedFirstName
        if trimmedFirstName.isEmpty {
            firstNameError = "First name is required"
            isValid = false
        } else if trimmedFirstName.count > 50 {
            firstNameError = "First name is too long"
            isValid = false
        }

        let trimmedLastName = lastName.trimmingCharacters(in: .whitespacesAndNewlines)
        lastName = trimmedLastName
        if trimmedLastName.isEmpty {
            lastNameError = "Last name is required"
            isValid = false
        } else if trimmedLastName.count > 50 {
            lastNameError = "Last name is too long"
            isValid = false
        }

        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        email = trimmedEmail
        let emailRegex = "^[^\\s@]+@[^\\s@]+\\.[^\\s@]+$"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
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

        let trimmedConfirmEmail = confirmEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        confirmEmail = trimmedConfirmEmail
        if trimmedConfirmEmail.isEmpty {
            confirmEmailError = "Please confirm your email"
            isValid = false
        } else if trimmedConfirmEmail != trimmedEmail {
            confirmEmailError = "Emails do not match"
            isValid = false
        }

        if password.isEmpty {
            passwordError = "Password is required"
            isValid = false
        } else if password.contains("--") {
            passwordError = "Password contains an invalid character combination"
            isValid = false
        } else if password.count < 8 {
            passwordError = "Must be at least 8 characters"
            isValid = false
        } else if !password.contains(where: { $0.isLowercase }) {
            passwordError = "Must contain a lowercase letter"
            isValid = false
        } else if !password.contains(where: { $0.isUppercase }) {
            passwordError = "Must contain an uppercase letter"
            isValid = false
        } else if !password.contains(where: { $0.isNumber }) {
            passwordError = "Must contain a number"
            isValid = false
        } else if password.unicodeScalars.allSatisfy({ !specialCharacters.contains($0) }) {
            passwordError = "Must contain a special character (! @ # $ % ^ * _ + = ~ ? -)"
            isValid = false
        }

        if confirmPassword.isEmpty {
            confirmPasswordError = "Please confirm your password"
            isValid = false
        } else if confirmPassword != password {
            confirmPasswordError = "Passwords do not match"
            isValid = false
        }

        return isValid
    }

    // MARK: - Submit
    private func performSignUp() {
        isLoading = true
        authError = nil
        Task {
            defer { isLoading = false }
            do {
                try await authManager.register(
                    email: email,
                    password: password,
                    firstName: firstName,
                    lastName: lastName
                )
            } catch {
                authError = error.localizedDescription
            }
        }
    }
}

// MARK: - API Response Models
struct RegisterResponse: Decodable {
    let success: Bool
    let data: RegisterData?
    let error: RegisterErrorDetails?
}

struct RegisterData: Decodable {
    let user: RegisterUser
}

struct RegisterUser: Decodable {
    let id: String
    let email: String
}

struct RegisterErrorDetails: Decodable {
    let code: String
    let message: String
}
