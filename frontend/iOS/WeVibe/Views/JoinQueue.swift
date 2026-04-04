import SwiftUI

// MARK: - Confetti

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
            let angle = Double.random(in: 0...(2 * .pi))
            let speed = CGFloat.random(in: 80...240)
            return ResultParticle(
                color:    colors.randomElement()!,
                size:     CGFloat.random(in: 5...12),
                shape:    Int.random(in: 0...2),
                x: cx, y: cy,
                finalX:   cx + cos(angle) * speed,
                finalY:   cy + sin(angle) * speed * CGFloat.random(in: 0.5...1.2),
                rotation: Double.random(in: -360...360)
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

    @Environment(SpeedDatingRouter.self) private var speedDatingRouter
    @Environment(UserProfileStore.self) private var store

    // Entrance animations
    @State private var emojiScale: CGFloat   = 0.5
    @State private var emojiOpacity: Double  = 0
    @State private var titleOpacity: Double  = 0
    @State private var titleOffset: CGFloat  = 20
    @State private var toggleOpacity: Double = 0
    @State private var buttonOpacity: Double = 0
    @State private var buttonOffset: CGFloat = 16

    // Looping emoji bob
    @State private var emojiOffsetY: CGFloat = 0

    private var resultEmoji: String {
        guard !store.personalityPrimary.isEmpty else { return "🎭" }
        if !store.personalitySecondary.isEmpty { return "🎭" }
        return StaticConfig.personalityMeta[store.personalityPrimary]?.emoji ?? "🎭"
    }

    var body: some View {
        @Bindable var bindableStore = store
        ZStack {
            AppTheme.primaryBackground
                .ignoresSafeArea()

            ResultConfetti()
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {

                    HStack {
                        Spacer()
                        Button {
                            speedDatingRouter.popToRoot()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.8))
                                .frame(width: 36, height: 36)
                                .background(
                                    Circle()
                                        .fill(Color.white.opacity(0.08))
                                        .overlay(
                                            Circle()
                                                .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
                                        )
                                )
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 16)

                    Text(resultEmoji)
                        .font(.system(size: 80))
                        .scaleEffect(emojiScale)
                        .opacity(emojiOpacity)
                        .offset(y: emojiOffsetY)
                        .padding(.top, 52)
                        .padding(.bottom, 28)

                    // ── Result text
                    PersonalityFullDisplay(
                        primaryKey: store.personalityPrimary,
                        secondaryKey: store.personalitySecondary
                    )
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
                        Toggle("", isOn: $bindableStore.showPersonalityTrait)
                            .tint(AppTheme.primaryButton)
                            .labelsHidden()
                            .onChange(of: store.showPersonalityTrait) { _, newValue in
                                var payload = ProfileUpdatePayload()
                                payload.showPersonalityTrait = newValue
                                Task { await store.patchProfile(payload) }
                            }
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
                            speedDatingRouter.navigate(to: .findingMatch)
                        }

                        Button {
                            speedDatingRouter.navigate(to: .tests)
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
        .task {
            await store.fetchProfile()
        }
    }

    // MARK: - Animations

    private func animateIn() {
        withAnimation(.spring(response: 0.6, dampingFraction: 0.65).delay(0.1)) {
            emojiScale   = 1
            emojiOpacity = 1
        }
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
