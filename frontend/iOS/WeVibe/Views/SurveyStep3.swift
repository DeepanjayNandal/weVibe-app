import SwiftUI

struct SurveyStep3: View {
    
    @Environment(OnboardingRouter.self) private var onboardingRouter
    
    @State private var drinks: String = ""
    @State private var smoking: String = ""
    @State private var pets: String = ""
    @State private var children: String = ""
    @State private var workout: String = ""
    @State private var sleepSchedule: String = ""
    
    var body: some View {
        ZStack {
            AppTheme.primaryBackground
                .ignoresSafeArea()
            
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    
                    ProgressBarView(current: 3, total: 5)
                    
                    // Drinks
                    HabitSection(title: "Drinks", selection: $drinks, options: [
                        HabitOption(label: "Never", color: nil),
                        HabitOption(label: "Sometimes", color: .yellow),
                        HabitOption(label: "Often", color: .green),
                    ])
                    
                    // Smoking
                    HabitSection(title: "Smoking", selection: $smoking, options: [
                        HabitOption(label: "Never", color: nil),
                        HabitOption(label: "Sometimes", color: .yellow),
                        HabitOption(label: "Often", color: .green),
                    ])
                    
                    // Pets
                    HabitSection(title: "Pets", selection: $pets, options: [
                        HabitOption(label: "Don't want", color: .red),
                        HabitOption(label: "Unsure", color: .yellow),
                        HabitOption(label: "Want", color: .pink),
                        HabitOption(label: "Have", color: .purple),
                    ])
                    
                    // Children
                    HabitSection(title: "Children", selection: $children, options: [
                        HabitOption(label: "Don't want", color: .red),
                        HabitOption(label: "Unsure", color: .yellow),
                        HabitOption(label: "Want", color: .pink),
                        HabitOption(label: "Have", color: .purple),
                    ])
                    
                    // Workout
                    HabitSection(title: "Workout", selection: $workout, options: [
                        HabitOption(label: "Never", color: nil),
                        HabitOption(label: "Sometimes", color: .yellow),
                        HabitOption(label: "Often", color: .green),
                    ])
                    
                    // Sleep Schedule
                    HabitSection(title: "Sleep Schedule", selection: $sleepSchedule, options: [
                        HabitOption(label: "Night Owl", color: nil),
                        HabitOption(label: "Early Bird", color: nil),
                        HabitOption(label: "Flexible", color: nil),
                    ])
                    
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
                            onboardingRouter.navigate(to: .step4)
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

