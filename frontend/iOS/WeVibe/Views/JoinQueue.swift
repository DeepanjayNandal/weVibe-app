import SwiftUI

// MARK: - Result Logic

struct PersonalityResult {
    let primary: PersonalityMeta
    let secondary: PersonalityMeta?

    var isHybrid: Bool { secondary != nil }
}

func calculatePersonalityResult(from answers: [Int]) -> PersonalityResult {
    // Count how many times each answer index (0=A,1=B,2=C,3=D) was chosen
    var counts = [0, 0, 0, 0]
    for answer in answers {
        if answer < 4 { counts[answer] += 1 }
    }

    let max1 = counts.max() ?? 0
    // Find all types tied at the top
    let topIndices = counts.enumerated().filter { $0.element == max1 }.map { $0.offset + 1 }

    let primary   = StaticConfig.personalityMeta[topIndices[0]]!

    if topIndices.count >= 2 {
        // Hybrid — two types share the highest count
        let secondary = StaticConfig.personalityMeta[topIndices[1]]!
        return PersonalityResult(primary: primary, secondary: secondary)
    } else {
        // Check if second-highest is close (within 1 answer) → still hybrid
        var sortedCounts = counts.enumerated().sorted { $0.element > $1.element }
        let max2 = sortedCounts[1].element
        if max1 - max2 <= 1 && max2 > 0 {
            let secondaryIndex = sortedCounts[1].offset + 1
            let secondary = StaticConfig.personalityMeta[secondaryIndex]!
            return PersonalityResult(primary: primary, secondary: secondary)
        }
        return PersonalityResult(primary: primary, secondary: nil)
    }
}

// MARK: - Info Tooltip

private struct InfoTooltip: View {
    let text: String
    @Binding var isShowing: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Spacer()
                Button { isShowing = false } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
            .padding(.bottom, 8)

            Text(text)
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.85))
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .background {
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(.regularMaterial)
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(hex: "#1A3025").opacity(0.85))
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(Color(hex: "#2A4A35"), lineWidth: 1)
            }
        }
        .frame(maxWidth: 260)
        .transition(.asymmetric(
            insertion: .scale(scale: 0.85).combined(with: .opacity),
            removal:   .scale(scale: 0.9).combined(with: .opacity)
        ))
    }
}

// MARK: - Type Label with Info Button

private struct TypeLabelView: View {
    let meta: PersonalityMeta
    @State private var showTooltip = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            HStack(alignment: .center, spacing: 8) {
                Text(meta.type)
                    .font(.system(size: 34, weight: .black))
                    .foregroundStyle(meta.color)
                    .multilineTextAlignment(.center)

                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        showTooltip.toggle()
                    }
                } label: {
                    Image(systemName: "info.circle")
                        .font(.system(size: 16))
                        .foregroundStyle(meta.color.opacity(0.7))
                }
            }

            if showTooltip {
                InfoTooltip(text: meta.description, isShowing: $showTooltip)
                    .offset(x: 20, y: 44)
                    .zIndex(10)
            }
        }
    }
}

// MARK: - Confetti (reused from JoinQueueView)

private struct ResultParticle: Identifiable {
    let id = UUID()
    let color: Color
    let size: CGFloat
    let shape: Int   // 0=circle 1=square 2=line
    var x: CGFloat
    var y: CGFloat
    var finalX: CGFloat
    var finalY: CGFloat
    var rotation: Double
    var opacity: Double = 0
}

private struct ResultConfetti: View {
    @State private var particles: [ResultParticle] = []

    private let colors: [Color] = [
        Color(hex: "#B2F542"), Color(hex: "#00E5A0"),
        Color(hex: "#3DFF9A"), Color(hex: "#FFE066"),
        Color(hex: "#FF6BBA"), Color(hex: "#FFFFFF"),
    ]

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(particles) { p in
                    Group {
                        if p.shape == 0 {
                            Circle().fill(p.color).frame(width: p.size, height: p.size)
                        } else if p.shape == 1 {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(p.color)
                                .frame(width: p.size, height: p.size)
                                .rotationEffect(.degrees(p.rotation))
                        } else {
                            Capsule()
                                .fill(p.color)
                                .frame(width: p.size * 0.4, height: p.size * 1.8)
                                .rotationEffect(.degrees(p.rotation))
                        }
                    }
                    .position(x: p.finalX, y: p.finalY)
                    .opacity(p.opacity)
                }
            }
            .onAppear { burst(in: geo.size) }
        }
        .allowsHitTesting(false)
    }

    private func burst(in size: CGSize) {
        let cx = size.width / 2
        let cy = size.height * 0.25

        let newP: [ResultParticle] = (0..<40).map { _ in
            let angle  = Double.random(in: 0...(2 * .pi))
            let speed  = CGFloat.random(in: 80...240)
            return ResultParticle(
                color:     colors.randomElement()!,
                size:      CGFloat.random(in: 5...12),
                shape:     Int.random(in: 0...2),
                x: cx, y: cy,
                finalX:    cx + cos(angle) * speed,
                finalY:    cy + sin(angle) * speed * CGFloat.random(in: 0.5...1.2),
                rotation:  Double.random(in: -360...360)
            )
        }
        particles = newP

        withAnimation(.spring(response: 0.6, dampingFraction: 0.65)) {
            for i in particles.indices { particles[i].opacity = 1 }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            withAnimation(.easeOut(duration: 1.0)) {
                for i in particles.indices { particles[i].opacity = 0 }
            }
        }
    }
}

// MARK: - Main View

struct JoinQueueView: View {

    let answers: [Int]
//    var onJoinQueue: () -> Void
//    var onRetakeTest: () -> Void

    @State private var showTraitOnProfile = true

    // Entrance
    @State private var emojiScale: CGFloat   = 0.5
    @State private var emojiOpacity: Double  = 0
    @State private var titleOpacity: Double  = 0
    @State private var titleOffset: CGFloat  = 20
    @State private var toggleOpacity: Double = 0
    @State private var buttonOpacity: Double = 0
    @State private var buttonOffset: CGFloat = 16

    // Looping emoji bob
    @State private var emojiOffsetY: CGFloat = 0

    private var result: PersonalityResult {
        calculatePersonalityResult(from: answers)
    }

    var body: some View {
        ZStack {
            AppTheme.primaryBackground
                .ignoresSafeArea()

            // Confetti on appear
            ResultConfetti()
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {

                    // ── Emoji / celebration icon
                    Text(result.isHybrid ? "🎭" : result.primary.emoji)
                        .font(.system(size: 80))
                        .scaleEffect(emojiScale)
                        .opacity(emojiOpacity)
                        .offset(y: emojiOffsetY)
                        .padding(.top, 52)
                        .padding(.bottom, 28)

                    // ── Result text
                    VStack(spacing: 12) {
                        if result.isHybrid, let secondary = result.secondary {
                            // ── HYBRID
                            Text("you are a hybrid of")
                                .font(.system(size: 17, weight: .medium))
                                .foregroundStyle(.white.opacity(0.55))

                            TypeLabelView(meta: result.primary)

                            Text("and")
                                .font(.system(size: 17, weight: .medium))
                                .foregroundStyle(.white.opacity(0.55))
                                .padding(.vertical, 2)

                            TypeLabelView(meta: secondary)

                        } else {
                            // ── SINGLE
                            Text("you are a")
                                .font(.system(size: 17, weight: .medium))
                                .foregroundStyle(.white.opacity(0.55))

                            TypeLabelView(meta: result.primary)
                        }
                    }
                    .multilineTextAlignment(.center)
                    .opacity(titleOpacity)
                    .offset(y: titleOffset)
                    .padding(.horizontal, 32)
                    .padding(.bottom, 36)

                    // ── Show on profile toggle
                    HStack {
                        Text("show my trait on my profile")
                            .font(.system(size: 15))
                            .foregroundStyle(.white.opacity(0.7))
                        Spacer()
                        Toggle("", isOn: $showTraitOnProfile)
                            .tint(AppTheme.primaryButton)
                            .labelsHidden()
                    }
                    .padding(.horizontal, 32)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.white.opacity(0.05))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                            )
                    )
                    .padding(.horizontal, 24)
                    .opacity(toggleOpacity)
                    .padding(.bottom, 32)

                    // ── Buttons
                    VStack(spacing: 12) {
                        PrimaryButton(
                            title: "let's join the queue →",
                            background: AppTheme.primaryButton,
                            foreground: .white,
                            height: 52,
                            isLoading: false,
                            isDisabled: false
                        ) {
//                            onJoinQueue()
                        }

                        Button {
//                            onRetakeTest()
                        } label: {
                            Text("retake the test")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.45))
                                .frame(maxWidth: .infinity)
                                .frame(height: 48)
                                .background(
                                    RoundedRectangle(cornerRadius: 14)
                                        .fill(Color.white.opacity(0.05))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 14)
                                                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                                        )
                                )
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 24)
                    .opacity(buttonOpacity)
                    .offset(y: buttonOffset)
                    .padding(.bottom, 48)
                }
            }
        }
        .navigationBarHidden(true)
        .onAppear { animateIn() }
    }

    // MARK: - Animations

    private func animateIn() {
        withAnimation(.spring(response: 0.6, dampingFraction: 0.65).delay(0.1)) {
            emojiScale   = 1
            emojiOpacity = 1
        }
        // Emoji bob loop
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
                emojiOffsetY = -12
            }
        }
        withAnimation(.spring(response: 0.5, dampingFraction: 0.78).delay(0.35)) {
            titleOpacity = 1
            titleOffset  = 0
        }
        withAnimation(.easeOut(duration: 0.4).delay(0.55)) {
            toggleOpacity = 1
        }
        withAnimation(.spring(response: 0.5, dampingFraction: 0.75).delay(0.7)) {
            buttonOpacity = 1
            buttonOffset  = 0
        }
    }
}
