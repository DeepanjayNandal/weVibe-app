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
                            Image(systemName: "chevron.left")
                                        .font(.system(size: 18, weight: .semibold))
                                        .foregroundStyle(AppTheme.primaryBackground)
                                        .frame(width: 48, height: 48)
                                        .background(.white)
                                        .clipShape(Circle())
                        }
                        
                        Spacer()
                        
                        Button {
                            onboardingRouter.navigate(to: .step4)
                        } label: {
                            Image(systemName: "chevron.right")
                                        .font(.system(size: 18, weight: .semibold))
                                        .foregroundStyle(AppTheme.primaryBackground)
                                        .frame(width: 48, height: 48)
                                        .background(.white)
                                        .clipShape(Circle())
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

