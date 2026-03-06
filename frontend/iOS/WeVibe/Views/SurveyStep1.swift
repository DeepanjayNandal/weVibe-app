import SwiftUI

struct SurveyStep1: View {
    
    @Environment(OnboardingRouter.self) private var onboardingRouter
    
    // Date of Birth
    @State private var day: String = ""
    @State private var month: String = ""
    @State private var year: String = ""
    @State private var isSexVisible: Bool = false
    
    // Sex
    @State private var selectedSex: String = ""
    let sexOptions = ["Male", "Female", "Non-binary", "Prefer not to say"]
    
    // Ethnicity
    @State private var selectedEthnicities: Set<String> = []
    let ethnicities = ["White", "Asian", "Other+", "Hispanic/Latino", "Black/African American", "Native Hawaiin", "Pacific Islander"]
    
    // Location
    @State private var state: String = ""
    @State private var zip: String = ""
    
    var body: some View {
        ZStack {
            AppTheme.primaryBackground
                .ignoresSafeArea()
            
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 28) {
                    
                    Button("Back", systemImage: "arrow.left") {
                        onboardingRouter.pop()
                    }.labelStyle(.iconOnly)
                    
                    // Progress Bar
                    ProgressBarView(current: 1, total: 5)
                    
                    // Date of Birth
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 2) {
                            Text("Date of Birth")
                                .foregroundStyle(.white)
                                .font(.system(size: 18, weight: .bold))
                            Text("*")
                                .foregroundStyle(.red)
                                .font(.system(size: 18, weight: .bold))
                        }
                        
                        HStack(alignment: .center,spacing: 12) {
                            DatePartField(placeholder: "DD", text: $day, width: 80, maxLength: 2)
                                .keyboardType(.numberPad)
                            DatePartField(placeholder: "MM", text: $month, width: 80, maxLength: 2)
                                .keyboardType(.numberPad)
                            DatePartField(placeholder: "YYYY", text: $year, width: 110, maxLength: 4)
                                .keyboardType(.numberPad)
                        }
                    }
                    
                    // Sex
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 2) {
                            Text("What is your sex?")
                                .foregroundStyle(.white)
                                .font(.system(size: 18, weight: .bold))
                            Text("*")
                                .foregroundStyle(.red)
                                .font(.system(size: 18, weight: .bold))
                        }
                        
                        Menu {
                            ForEach(sexOptions, id: \.self) { option in
                                Button(option) {
                                    selectedSex = option
                                }
                            }
                        } label: {
                            HStack {
                                Text(selectedSex.isEmpty ? "Dropdown" : selectedSex)
                                    .foregroundStyle(selectedSex.isEmpty ? .white.opacity(0.5) : .white)
                                    .font(.system(size: 16))
                                Spacer()
                                // Eye toggle button
                                Button {
                                    isSexVisible.toggle()
                                } label: {
                                    Image(systemName: isSexVisible ? "eye" : "eye.slash")
                                        .foregroundStyle(.white)
                                        .frame(width: 50, height: 30)
                                        .background(Color.green)
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
                    
                    // Ethnicity
                    VStack(alignment: .leading, spacing: 12) {
                        Text("What's your ethnicity?")
                            .foregroundStyle(.white)
                            .font(.system(size: 18, weight: .bold))
                        
                        Text("Select as many as you'd like")
                            .foregroundStyle(.white.opacity(0.6))
                            .font(.system(size: 14))
                        
                        FlowLayout(spacing: 10) {
                            ForEach(ethnicities, id: \.self) { ethnicity in
                                EthnicityChip(
                                    label: ethnicity,
                                    isSelected: selectedEthnicities.contains(ethnicity)
                                ) {
                                    if selectedEthnicities.contains(ethnicity) {
                                        selectedEthnicities.remove(ethnicity)
                                    } else {
                                        selectedEthnicities.insert(ethnicity)
                                    }
                                }
                            }
                        }
                    }
                    
                    // Location
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 2) {
                            Text("Where are you located?")
                                .foregroundStyle(.white)
                                .font(.system(size: 18, weight: .bold))
                            Text("*")
                                .foregroundStyle(.red)
                                .font(.system(size: 18, weight: .bold))
                        }
                        
                        HStack(spacing: 12) {
                            DatePartField(placeholder: "State", text: $state, width: 140, maxLength: 20)
                            DatePartField(placeholder: "Zip", text: $zip, width: 120, maxLength: 10)
                                .keyboardType(.numberPad)
                        }
                    }
                    
                    HStack() {
                        Spacer()
                        Button {
                            onboardingRouter.navigate(to: .step2)
                        } label: {
                            Image(systemName: "chevron.right")
                                        .font(.system(size: 18, weight: .semibold))
                                        .foregroundStyle(AppTheme.primaryBackground)
                                        .frame(width: 48, height: 48)
                                        .background(.white)
                                        .clipShape(Circle())
                        }
                    }
                    .padding(.top, 40)
                    
                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
            }
        }
        .navigationBarBackButtonHidden(true)
    }
}



// MARK: - Placeholder helper
extension View {
    func placeholder<Content: View>(when shouldShow: Bool, @ViewBuilder placeholder: () -> Content) -> some View {
        ZStack(alignment: .leading) {
            if shouldShow { placeholder() }
            self
        }
    }
}
