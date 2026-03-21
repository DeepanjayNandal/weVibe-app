import SwiftUI

struct SurveyStep5: View {

    @Environment(OnboardingRouter.self) private var onboardingRouter
    @Environment(OnboardingData.self) private var onboardingData
    @Environment(AuthManager.self) private var authManager

    @State private var showPromptError = false


    // Prompts selected in the other slots — passed to each PromptField to grey them out.
    private var usedByOthers1: Set<String> {
        Set([onboardingData.prompt2Question, onboardingData.prompt3Question].filter { !$0.isEmpty })
    }
    private var usedByOthers2: Set<String> {
        Set([onboardingData.prompt1Question, onboardingData.prompt3Question].filter { !$0.isEmpty })
    }
    private var usedByOthers3: Set<String> {
        Set([onboardingData.prompt1Question, onboardingData.prompt2Question].filter { !$0.isEmpty })
    }

    var body: some View {
        ZStack {
            AppTheme.primaryBackground.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {

                    ProgressBarView(current: 5, total: 5)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("What makes you, you?")
                            .foregroundStyle(.white)
                            .font(.system(size: 22, weight: .bold))

                        Text("Pick a prompt and write your answer — this is what others see on your profile.")
                            .foregroundStyle(AppTheme.secondaryText)
                            .font(.system(size: 14))
                    }

                    PromptField(
                        label: "Prompt 1",
                        question: Bindable(onboardingData).prompt1Question,
                        answer: Bindable(onboardingData).prompt1Answer,
                        usedByOthers: usedByOthers1
                    )

                    PromptField(
                        label: "Prompt 2",
                        question: Bindable(onboardingData).prompt2Question,
                        answer: Bindable(onboardingData).prompt2Answer,
                        usedByOthers: usedByOthers2
                    )

                    PromptField(
                        label: "Prompt 3",
                        question: Bindable(onboardingData).prompt3Question,
                        answer: Bindable(onboardingData).prompt3Answer,
                        usedByOthers: usedByOthers3
                    )

                    // Or write your own
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Or write your own")
                            .foregroundStyle(AppTheme.secondaryText)
                            .font(.system(size: 14))

                        TextField("Your prompt or question...", text: Bindable(onboardingData).ownPrompt)
                            .foregroundStyle(.white)
                            .font(.system(size: 15))
                            .padding(.horizontal, 16)
                            .frame(height: 52)
                            .background(.white.opacity(0.1))
                            .cornerRadius(14)
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(.white.opacity(0.3), lineWidth: 1))

                        if !onboardingData.ownPrompt.isEmpty {
                            TextField("Your answer...", text: Bindable(onboardingData).ownPromptAnswer, axis: .vertical)
                                .foregroundStyle(.white)
                                .font(.system(size: 15))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(.white.opacity(0.08))
                                .cornerRadius(12)
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(
                                    showPromptError && onboardingData.ownPromptAnswer.isEmpty ? Color.red.opacity(0.7) : .white.opacity(0.2),
                                    lineWidth: 1
                                ))
                                .lineLimit(3...6)
                                .onChange(of: onboardingData.ownPromptAnswer) { _, _ in showPromptError = false }
                        }

                        if showPromptError {
                            HStack(spacing: 4) {
                                Image(systemName: "exclamationmark.circle.fill").font(.system(size: 12))
                                Text("Please add an answer for your custom prompt").font(.system(size: 12))
                            }
                            .foregroundStyle(.red)
                        }
                    }
                    .padding(.top, 8)

                    // Navigation
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
                            if !onboardingData.ownPrompt.isEmpty && onboardingData.ownPromptAnswer.isEmpty {
                                showPromptError = true
                                return
                            }
                            onboardingData.save()
                            authManager.completeOnboarding(onboardingData)
                        } label: {
                            Group {
                                if authManager.isSubmittingOnboarding {
                                    ProgressView().tint(.white)
                                } else {
                                    Text("Finish").font(.system(size: 16, weight: .bold))
                                }
                            }
                            .foregroundStyle(.white)
                            .frame(width: 100)
                            .padding(.horizontal, 32)
                            .padding(.vertical, 16)
                            .background(AppTheme.primaryButton)
                            .clipShape(Capsule())
                        }
                        .disabled(authManager.isSubmittingOnboarding)
                    }
                    .padding(.top, 8)

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
