import SwiftUI

struct SpeedDatingRules: View {

    @State private var headerOpacity: Double  = 0
    @State private var headerOffset: CGFloat  = 16
    @State private var rulesOpacity: Double   = 0
    @State private var rulesOffset: CGFloat   = 20
    @State private var buttonOpacity: Double  = 0
    @State private var buttonOffset: CGFloat  = 16
    
    @Environment(SpeedDatingRouter.self) private var speedDatingRouter

    private let rules: [RuleItem] = [
        RuleItem(
            number: "1",
            headline: "Keep it respectful fr.",
            body: "No weird energy allowed — just good convos only."
        ),
        RuleItem(
            number: "2",
            headline: "Protect the vibe.",
            body: "No sharing personal info — get to know their personality, not their number."
        ),
        RuleItem(
            number: "3",
            headline: "6 questions survey = your cosmic match.",
            body: "The personality test is mandatory. Trust the process, it hits different."
        ),
        RuleItem(
            number: "4",
            headline: "20 messages. that's your window.",
            body: "Both gotta say yes to keep the convo alive — or it disappears in 24hrs. No cap."
        ),
        RuleItem(
            number: "5",
            headline: "Instant exit, no questions asked.",
            body: "If the vibe's off, report & bounce. Your safety comes first, always."
        ),
    ]

    var body: some View {
        ZStack {
            AppTheme.primaryBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {

                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Button("Back", systemImage: "arrow.left") {
                                    speedDatingRouter.popToRoot()
                                }
                                .labelStyle(.iconOnly)
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(.white)
                                
                                LogoView(size: 48)
                                    .padding(.bottom, 4)
                            }

                            Text("The Vibe Code")
                                .foregroundStyle(.white)
                                .font(.title)
                                .bold()

                            Text("A few house rules before you dive in —\nso everyone keeps it 💯")
                                .font(.system(size: 14))
                                .foregroundStyle(AppTheme.smallText)
                                .lineSpacing(4)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .opacity(headerOpacity)
                        .offset(y: headerOffset)
                        .padding(.bottom, 28)

                        
                        VStack(spacing: 14) {
                            ForEach(Array(rules.enumerated()), id: \.offset) { index, rule in
                                RuleCardView(rule: rule)
                                    .opacity(rulesOpacity)
                                    .offset(y: rulesOffset)
                                    .animation(
                                        .spring(response: 0.5, dampingFraction: 0.78)
                                            .delay(0.4 + Double(index) * 0.07),
                                        value: rulesOpacity
                                    )
                            }
                        }
                        .padding(.bottom, 32)
                    }
                    .padding(.horizontal, 24)
                }

                VStack(spacing: 0) {

                    LinearGradient(
                        colors: [AppTheme.primaryBackground.opacity(0), AppTheme.primaryBackground],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 32)

                    PrimaryButton(
                        title: "Take the vibe check →",
                        background: AppTheme.primaryButton,
                        foreground: .white,
                        height: 52,
                        isLoading: false,
                        isDisabled: false
                    ) {
                        speedDatingRouter.navigate(to: .tests)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 32)
                    .background(AppTheme.primaryBackground)
                }
                .opacity(buttonOpacity)
                .offset(y: buttonOffset)
                .padding(.bottom, 32)
            }
        }
        .onAppear { animateIn() }
    }

    // MARK: - Entrance Animations
    private func animateIn() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.1)) {
            headerOpacity = 1
            headerOffset  = 0
        }
        withAnimation(.spring(response: 0.5, dampingFraction: 0.78).delay(0.25)) {
            rulesOpacity = 1
            rulesOffset  = 0
        }
        withAnimation(.spring(response: 0.5, dampingFraction: 0.75).delay(0.6)) {
            buttonOpacity = 1
            buttonOffset  = 0
        }
    }
}

// MARK: - Rule Data Model
struct RuleItem {
    let number: String
    let headline: String
    let body: String
}

// MARK: - Rule Card
struct RuleCardView: View {
    let rule: RuleItem

    var body: some View {
        HStack(alignment: .top, spacing: 14) {

            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [AppTheme.primaryButton, AppTheme.primaryButton.opacity(0.6)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 32, height: 32)

                Text(rule.number)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
            }
            .padding(.top, 2)

       
            VStack(alignment: .leading, spacing: 4) {
                Text(rule.headline)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)

                Text(rule.body)
                    .font(.system(size: 13))
                    .foregroundStyle(AppTheme.smallText)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
    }
}
