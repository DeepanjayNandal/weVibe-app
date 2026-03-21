import SwiftUI

struct SurveyStep3: View {

    @Environment(OnboardingRouter.self) private var onboardingRouter
    @Environment(OnboardingData.self) private var onboardingData

    var body: some View {
        ZStack {
            AppTheme.primaryBackground.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {

                    ProgressBarView(current: 3, total: 5)

                    HabitSection(title: "Drinks", selection: Bindable(onboardingData).drinks, options: [
                        HabitOption(label: "Never"),
                        HabitOption(label: "Sometimes"),
                        HabitOption(label: "Often"),
                    ])

                    HabitSection(title: "Smoking", selection: Bindable(onboardingData).smoking, options: [
                        HabitOption(label: "Never"),
                        HabitOption(label: "Sometimes"),
                        HabitOption(label: "Often"),
                    ])

                    HabitSection(title: "Pets", selection: Bindable(onboardingData).pets, options: [
                        HabitOption(label: "Don't want"),
                        HabitOption(label: "Unsure"),
                        HabitOption(label: "Want"),
                        HabitOption(label: "Have"),
                    ])

                    HabitSection(title: "Children", selection: Bindable(onboardingData).children, options: [
                        HabitOption(label: "Don't want"),
                        HabitOption(label: "Unsure"),
                        HabitOption(label: "Want"),
                        HabitOption(label: "Have"),
                    ])

                    HabitSection(title: "Workout", selection: Bindable(onboardingData).workout, options: [
                        HabitOption(label: "Never"),
                        HabitOption(label: "Sometimes"),
                        HabitOption(label: "Often"),
                    ])

                    HabitSection(title: "Sleep Schedule", selection: Bindable(onboardingData).sleepSchedule, options: [
                        HabitOption(label: "Night Owl"),
                        HabitOption(label: "Early Bird"),
                        HabitOption(label: "Flexible"),
                    ])

                    HStack {
                        Button {
                            onboardingData.save()
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
                            onboardingData.save()
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
        .onTapGesture {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
        .scrollDismissesKeyboard(.interactively)
    }
}
