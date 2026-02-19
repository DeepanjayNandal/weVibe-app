import SwiftUI

struct RegisterScreen: View {
    @State private var firstName: String = ""
    @State private var lastName: String = ""
    @State private var email: String = ""
    @State private var confirmEmail: String = ""
    @State private var password: String = ""
    @State private var confirmPassword: String = ""

    
    @Environment(Router.self) private var router
    
    var body: some View {
        ZStack {
            AppTheme.primaryBackground
                .ignoresSafeArea()
            
            VStack(spacing: 10) {
                LogoView(size: 80)
                
                VStack(alignment: .leading, spacing: 10) {
                    Text("Sign Up")
                        .foregroundStyle(.white)
                        .font(.system(size: 32, weight: .bold))
                        .padding(.bottom, 10)
                    
                    // name row
                    HStack(spacing: 10){
                        VStack(alignment: .leading, spacing: 6) {
                            Text("First Name")
                                .foregroundStyle(.white)
                                .font(.system(size: 16, weight: .medium))
                            
                            TextField("", text: $firstName)
                                .padding(.horizontal, 16)
                                .frame(height: 52)
                                .background(.white)
                                .cornerRadius(14)
                                .keyboardType(.emailAddress)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                        }
                        
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Last Name")
                                .foregroundStyle(.white)
                                .font(.system(size: 16, weight: .medium))
                            
                            TextField("", text: $lastName)
                                .padding(.horizontal, 16)
                                .frame(height: 52)
                                .background(.white)
                                .cornerRadius(14)
                                .keyboardType(.emailAddress)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                        }
                    }
                    //email row
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
                    .padding(.top, 10)
                    //confirm email row
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Confirm Email")
                            .foregroundStyle(.white)
                            .font(.system(size: 16, weight: .medium))
                        
                        TextField("", text: $confirmEmail)
                            .padding(.horizontal, 16)
                            .frame(height: 52)
                            .background(.white)
                            .cornerRadius(14)
                            .keyboardType(.emailAddress)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                    }
                    .padding(.top, 10)
                    //password row
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Password")
                            .foregroundStyle(.white)
                            .font(.system(size: 16, weight: .medium))
                        
                        TextField("", text: $password)
                            .padding(.horizontal, 16)
                            .frame(height: 52)
                            .background(.white)
                            .cornerRadius(14)
                            .keyboardType(.emailAddress)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                    }
                    .padding(.top, 10)
                    //confirm password row
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Confirm Password")
                            .foregroundStyle(.white)
                            .font(.system(size: 16, weight: .medium))
                        
                        TextField("", text: $confirmPassword)
                            .padding(.horizontal, 16)
                            .frame(height: 52)
                            .background(.white)
                            .cornerRadius(14)
                            .keyboardType(.emailAddress)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                    }
                    .padding(.top, 10)
                    
                    Button("Sign Up") {
                        router.navigateToConfirmScreen()
                    }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color(hex: "1a4a3a"))
                        .foregroundStyle(.white)
                        .bold()
                        .cornerRadius(14)
                        .padding(.top, 12)
                        .padding(.bottom, 16)
                    

                }
            }
            .padding(.horizontal, 24)
        }
    }
}
