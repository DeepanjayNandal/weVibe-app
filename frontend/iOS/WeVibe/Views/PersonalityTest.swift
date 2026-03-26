import SwiftUI

struct PersonalityTestView: View {

    var onComplete: (([Int]) -> Void)?

    @State private var currentIndex: Int = 0
    @State private var selectedAnswers: [Int?] = Array(repeating: nil, count: StaticConfig.personalityQuestions.count)

    @State private var contentOpacity: Double = 1
    @State private var contentOffset: CGFloat = 0

    @Environment(SpeedDatingRouter.self) private var speedDatingRouter
    @Environment(PersonalityTestData.self) private var testData
    @Environment(UserProfileStore.self) private var profileStore

    private var current: PersonalityQuestion {
        StaticConfig.personalityQuestions[currentIndex]
    }

    private var selectedForCurrent: Int? {
        selectedAnswers[currentIndex]
    }

    private var isLastQuestion: Bool {
        currentIndex == StaticConfig.personalityQuestions.count - 1
    }

    var body: some View {
        ZStack {
            AppTheme.primaryBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {

                
                HStack(spacing: 14) {
                    Button("Back", systemImage: "arrow.left") {
                        if currentIndex > 0 {
                            transition {
                                currentIndex -= 1
                            }
                        } else {
                            speedDatingRouter.navigate(to: .rules)
                        }
                    }
                    .labelStyle(.iconOnly)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)

                    ProgressBarView(current: currentIndex + 1, total: StaticConfig.personalityQuestions.count)
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .padding(.bottom, 28)

                VStack(alignment: .leading, spacing: 0) {

                    Text("Question \(currentIndex + 1) of \(StaticConfig.personalityQuestions.count)")
                        .font(.system(size: 12, weight: .semibold))
                        .tracking(1.5)
                        .textCase(.uppercase)
                        .foregroundStyle(AppTheme.smallText)
                        .padding(.bottom, 12)

                    Text(current.question)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.white)
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.bottom, 28)

                    
                    VStack(spacing: 12) {
                        ForEach(Array(current.options.enumerated()), id: \.offset) { index, option in
                            OptionRowView(
                                option: option,
                                isSelected: selectedForCurrent == index
                            ) {
                                selectedAnswers[currentIndex] = index
                            }
                        }
                    }
                }
                .padding(.horizontal, 24)
                .opacity(contentOpacity)
                .offset(y: contentOffset)

                Spacer()

                
                VStack(spacing: 0) {
                    LinearGradient(
                        colors: [AppTheme.primaryBackground.opacity(0), AppTheme.primaryBackground],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 32)

                    PrimaryButton(
                        title: isLastQuestion ? "See my matches ✦" : "That's my vibe →",
                        background: AppTheme.primaryButton,
                        foreground: .white,
                        height: 52,
                        isLoading: false,
                        isDisabled: selectedForCurrent == nil
                    ) {
                        handleNext()
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 32)
                    .background(AppTheme.primaryBackground)
                }
                .padding(.bottom, 32)
            }
        }
        .navigationBarHidden(true)
    }

    private func handleNext() {
        guard selectedForCurrent != nil else { return }

        if isLastQuestion {
            let results = selectedAnswers.compactMap { $0 }
            if results.count == StaticConfig.personalityQuestions.count {
                testData.answers = selectedAnswers
                testData.commitResult(testData.result)
                speedDatingRouter.navigate(to: .joinQueue)
            }
            Task {
                await profileStore.postPersonalityTest(answers: results)
                onComplete?(results)
            }

        } else {
            transition {
                currentIndex += 1
            }
        }
    }

    
    private func transition(change: @escaping () -> Void) {
        withAnimation(.easeIn(duration: 0.18)) {
            contentOpacity = 0
            contentOffset  = -20
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            change()
            contentOffset = 24
            withAnimation(.spring(response: 0.4, dampingFraction: 0.82)) {
                contentOpacity = 1
                contentOffset  = 0
            }
        }
    }
}

// MARK: - Option Row

struct OptionRowView: View {
    let option: PersonalityOption
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 14) {

                ZStack {
                    Circle()
                        .strokeBorder(
                            isSelected ? AppTheme.primaryButton : Color.white.opacity(0.2),
                            lineWidth: 2
                        )
                        .frame(width: 22, height: 22)

                    if isSelected {
                        Circle()
                            .fill(AppTheme.primaryButton)
                            .frame(width: 12, height: 12)
                    }
                }
                .padding(.top, 2)
                .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isSelected)

                VStack(alignment: .leading, spacing: 3) {
                    Text(option.letter + ".")
                        .font(.system(size: 11, weight: .bold))
                        .tracking(1)
                        .foregroundStyle(isSelected ? .white : Color.white.opacity(0.35))

                    Text(option.text)
                        .font(.system(size: 14))
                        .foregroundStyle(isSelected ? .white : Color.white.opacity(0.65))
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? Color.white.opacity(0.08) : Color.white.opacity(0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(
                                isSelected ? AppTheme.primaryButton.opacity(0.6) : Color.white.opacity(0.07),
                                lineWidth: isSelected ? 4 : 2
                            )
                    )
            )
            .animation(.easeOut(duration: 0.15), value: isSelected)
        }
        .buttonStyle(.plain)
    }
}
