import SwiftUI

struct SurveyStep4: View {
    
    @Environment(OnboardingRouter.self) private var onboardingRouter
    
    // Education
    @State private var education: String = ""
    let educationOptions = ["High School", "Some College", "Bachelor's", "Master's", "PhD", "Other"]
    
    // Career
    @State private var career: String = ""
    let careerOptions = ["Technology", "Healthcare", "Education", "Finance", "Arts", "Other"]
    
    // Height
    @State private var heightValue: String = ""
    @State private var heightUnit: String = "FT"
    
    // Languages
    @State private var selectedLanguages: Set<String> = ["English"]
    let languages = ["English", "Hindi", "Other+", "Vietnamese", "Mandarin/Chinese", "Spanish", "Japanese"]
    
    var body: some View {
        ZStack {
            AppTheme.primaryBackground
                .ignoresSafeArea()
            
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    
                    ProgressBarView(current: 4, total: 5)
                    
                    // Education
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Education")
                            .foregroundStyle(.white)
                            .font(.system(size: 18, weight: .bold))
                        
                        Menu {
                            ForEach(educationOptions, id: \.self) { option in
                                Button(option) { education = option }
                            }
                        } label: {
                            HStack {
                                Text(education.isEmpty ? "Dropdown" : education)
                                    .foregroundStyle(education.isEmpty ? .white.opacity(0.5) : .white)
                                    .font(.system(size: 16))
                                Spacer()
                                Button {
                                    education = ""
                                } label: {
                                    Text("X")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundStyle(.white)
                                        .frame(width: 50, height: 30)
                                        .background(Color.pink.opacity(0.7))
                                        .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, 16)
                            .frame(height: 52)
                            .background(.white.opacity(0.1))
                            .cornerRadius(14)
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(.white.opacity(0.3), lineWidth: 1)
                            )
                        }
                    }
                    
                    // Career
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Career")
                            .foregroundStyle(.white)
                            .font(.system(size: 18, weight: .bold))
                        
                        Menu {
                            ForEach(careerOptions, id: \.self) { option in
                                Button(option) { career = option }
                            }
                        } label: {
                            HStack {
                                Text(career.isEmpty ? "Select your career field" : career)
                                    .foregroundStyle(career.isEmpty ? .white.opacity(0.5) : .white)
                                    .font(.system(size: 16))
                                Spacer()
                                Button {
                                    career = ""
                                } label: {
                                    Text("X")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundStyle(.white)
                                        .frame(width: 50, height: 30)
                                        .background(Color.pink.opacity(0.7))
                                        .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, 16)
                            .frame(height: 52)
                            .background(.white.opacity(0.1))
                            .cornerRadius(14)
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(.white.opacity(0.3), lineWidth: 1)
                            )
                        }
                    }
                    
                    // Height
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Height")
                            .foregroundStyle(.white)
                            .font(.system(size: 18, weight: .bold))
                        
                        HStack(spacing: 12) {
                           
                            TextField("", text: $heightValue)
                                .foregroundStyle(.white)
                                .keyboardType(.decimalPad)
                                .padding(.horizontal, 16)
                                .frame(height: 48)
                                .background(.white.opacity(0.1))
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(.white.opacity(0.3), lineWidth: 1)
                                )
                                .frame(maxWidth: 180)
                            
                            //toggle
                            HStack(spacing: 8) {
                                ForEach(["FT", "CM"], id: \.self) { unit in
                                    Button {
                                        heightUnit = unit
                                    } label: {
                                        Text(unit)
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundStyle(heightUnit == unit ? .black : .white)
                                            .frame(width: 52, height: 48)
                                            .background(heightUnit == unit ? Color.green : .white.opacity(0.1))
                                            .cornerRadius(12)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .stroke(.white.opacity(0.3), lineWidth: 1)
                                            )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                    
                    // Languages
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Languages")
                            .foregroundStyle(.white)
                            .font(.system(size: 18, weight: .bold))
                        
                        Text("Select as many as you'd like")
                            .foregroundStyle(.white.opacity(0.6))
                            .font(.system(size: 14))
                        
                        FlowLayout(spacing: 10) {
                            ForEach(languages, id: \.self) { language in
                                Button {
                                    if selectedLanguages.contains(language) {
                                        selectedLanguages.remove(language)
                                    } else {
                                        selectedLanguages.insert(language)
                                    }
                                } label: {
                                    Text(language)
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundStyle(selectedLanguages.contains(language) ? .black : .white)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 10)
                                        .background(selectedLanguages.contains(language) ? Color.green : .clear)
                                        .cornerRadius(20)
                                        .overlay(
                                            Capsule()
                                                .stroke(.white.opacity(0.5), lineWidth: 1)
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                            
                            // + button
                            Button {
                                // add custom language
                            } label: {
                                Text("+")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundStyle(.white)
                                    .frame(width: 40, height: 40)
                                    .background(.white.opacity(0.1))
                                    .clipShape(Circle())
                                    .overlay(
                                        Circle()
                                            .stroke(.white.opacity(0.5), lineWidth: 1)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    
                    // Navigation buttons
                    HStack {
                        Button {
                            onboardingRouter.pop()
                        } label: {
                            Text("Last step")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(AppTheme.primaryBackground)
                                .padding(.horizontal, 32)
                                .padding(.vertical, 16)
                                .background(.white)
                                .clipShape(Capsule())
                        }
                        
                        Spacer()
                        
                        Button {
                            onboardingRouter.navigate(to: .step5)
                        } label: {
                            Text("Next step")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(AppTheme.primaryBackground)
                                .padding(.horizontal, 32)
                                .padding(.vertical, 16)
                                .background(.white)
                                .clipShape(Capsule())
                        }
                    }
                    .padding(.top, 16)
                    
                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
            }
        }
        .navigationBarBackButtonHidden(true)
    }
}
