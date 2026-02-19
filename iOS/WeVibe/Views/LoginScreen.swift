import SwiftUI

struct LoginScreen: View {
    @State private var email: String = ""
    @State private var password: String = ""
    
    @Environment(Router.self) private var router
    
    var body: some View {
        ZStack {
            AppTheme.primaryBackground
                .ignoresSafeArea()
            
            VStack(spacing: 10) {
                LogoView(size: 130)
                
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
                        .cornerRadius(14)
                        .keyboardType(.emailAddress)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    Text("Password")
                        .foregroundStyle(.white)
                        .font(.system(size: 16, weight: .medium))
                    
                    SecureField("", text: $password)
                        .padding(.horizontal, 16)
                        .frame(height: 52)
                        .background(.white)
                        .cornerRadius(14)
                }
                
                HStack {
                    Button(action: {}) {
                        Text("Forgot Password?")
                            .foregroundStyle(.white)
                            .underline()
                            .font(.system(size: 14))
                    }
                        
                    
                    Spacer()
                    
                    Button(action: { router.navigateToRegister()}) {
                        Text("Sign up")
                            .foregroundStyle(AppTheme.smallText)
                            .underline()
                            .font(.system(size: 14))
                    }
                        
                }
                .padding(.top, 4)
                
                Button("Sign in") { }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(.white)
                    .foregroundStyle(AppTheme.primaryBackground)
                    .bold()
                    .cornerRadius(14)
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
                    .background(Color(hex: "1a4a3a"))
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
    
}
