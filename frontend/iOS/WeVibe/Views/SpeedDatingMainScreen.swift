import SwiftUI

struct SpeedDatingPlaceholder: View {

    @State private var pillOpacity: Double    = 0
    @State private var logoOpacity: Double    = 0
    @State private var logoScale: CGFloat     = 0.75
    @State private var titleOpacity: Double   = 0
    @State private var titleOffset: CGFloat   = 20
    @State private var taglineOpacity: Double = 0
    @State private var buttonOpacity: Double  = 0
    @State private var buttonOffset: CGFloat  = 16
    
    @Environment(SpeedDatingRouter.self) private var speedDatingRouter
    @Environment(UserProfileStore.self) private var store

    var body: some View {
        ZStack {
            AppTheme.primaryBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                VStack(spacing: 0) {
                // Glass effect
                    HStack(spacing: 7) {
                        Text("✦")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.white)
                        Text("SIT STILL, LOVE COMES")
                            .font(.system(size: 12, weight: .semibold))
                            .tracking(2.5)
                            .foregroundStyle(.white)
                        
                        Text("✦")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.white)
                       }
                       .padding(.horizontal, 22)
                       .padding(.vertical, 11)
                       .background {
                     ZStack {
                       Capsule().fill(.regularMaterial)

                       Capsule().fill(Color.black.opacity(0.28))

                       Capsule()
                         .fill(
                            LinearGradient(
                                 stops: [
                                    .init(color: Color.white.opacity(0.0),  location: 0.0),
                                    .init(color: Color.white.opacity(0.0),  location: 0.52),
                                    .init(color: Color.white.opacity(0.18), location: 0.58),
                                    .init(color: Color.white.opacity(0.22), location: 0.62),
                                    .init(color: Color.white.opacity(0.08), location: 0.68),
                                    .init(color: Color.white.opacity(0.0),  location: 0.75),
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                        )
                       )

                      Capsule()
                         .strokeBorder(
                             LinearGradient(
                                  colors: [
                                    Color.white.opacity(0.55),
                                    Color.white.opacity(0.15),
                                    Color.white.opacity(0.0),
                                    Color.white.opacity(0.08),
                             ],
                             startPoint: .topLeading,
                             endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                      )
                    }
                  }
                   .shadow(color: .black.opacity(0.35), radius: 12, x: 0, y: 5)
                   .opacity(pillOpacity)
                   .padding(.bottom, 40)

                    LogoView(size: 150)

                    Text("Speed Dating")
                        .foregroundStyle(.white)
                        .font(.title)
                        .bold()
                        .offset(y: titleOffset)
                        .opacity(titleOpacity)
                        .padding(.bottom, 60)

                    
                    VStack(spacing: 4) {
                        Text("20 messages. anonymous. 24 hours.")
                        Text("✦ Match only if you both feel it ✦")
                    }
                    .font(.system(size: 14))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 32)
                    .padding(.bottom, 40)

                    PrimaryButton(
                        title: "Let's get it →",
                        background: AppTheme.primaryButton,
                        foreground: .white,
                        height: 52,
                        isLoading: false,
                        isDisabled: false
                    ) {
                        if(store.isPersonalityTestComplete) {
                            speedDatingRouter.navigate(to: .joinQueue)
                        } else {
                            speedDatingRouter.navigate(to: .rules)
                        }
                        
                    }
                    .padding(.horizontal, 24)
                    .opacity(buttonOpacity)
                    .offset(y: buttonOffset)
                }

    }
        }
        .onAppear { animateIn() }
        .task {
            await store.fetchProfile()
        }
    }


    // MARK: - Entrance Animations
    private func animateIn() {
        withAnimation(.easeOut(duration: 0.4).delay(0.05)) {
            pillOpacity = 1
        }
        withAnimation(.spring(response: 0.6, dampingFraction: 0.72).delay(0.1)) {
            logoScale   = 1.0
            logoOpacity = 1
        }
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.35)) {
            titleOffset  = 0
            titleOpacity = 1
        }
        withAnimation(.easeOut(duration: 0.4).delay(0.55)) {
            taglineOpacity = 1
        }
        withAnimation(.spring(response: 0.5, dampingFraction: 0.75).delay(0.7)) {
            buttonOpacity = 1
            buttonOffset  = 0
        }
    }
}

