import SwiftUI

// MARK: - Single Bubble

private struct BubbleView: View {
    let baseSize: CGFloat
    let color: Color
    let delay: Double

    @State private var scale: CGFloat  = 0.55
    @State private var opacity: Double = 0.3
    @State private var offsetY: CGFloat = 0

    var body: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [color.opacity(0.95), color.opacity(0.55)],
                    center: .topLeading,
                    startRadius: 0,
                    endRadius: baseSize
                )
            )
            .frame(width: baseSize, height: baseSize)
            .scaleEffect(scale)
            .opacity(opacity)
            .offset(y: offsetY)
            .onAppear {
                withAnimation(
                    .easeInOut(duration: Double.random(in: 1.1...1.7))
                    .repeatForever(autoreverses: true)
                    .delay(delay)
                ) {
                    scale   = CGFloat.random(in: 0.88...1.12)
                    opacity = Double.random(in: 0.65...1.0)
                }
                withAnimation(
                    .easeInOut(duration: Double.random(in: 1.8...2.8))
                    .repeatForever(autoreverses: true)
                    .delay(delay * 0.6)
                ) {
                    offsetY = CGFloat.random(in: -6...6)
                }
            }
    }
}

// MARK: - Bubble Grid

private struct BubbleGrid: View {

    // Each row: (count, size, colors)
    private struct Row {
        let count: Int
        let size: CGFloat
        let colors: [Color]
    }

    private let rows: [Row] = [
        Row(count: 4, size: 28, colors: [
            Color(hex: "#3DFF9A"), Color(hex: "#22A855"),
            Color(hex: "#1A8C4E"), Color(hex: "#3DFF9A"),
        ]),
        Row(count: 5, size: 34, colors: [
            Color(hex: "#22A855"), Color(hex: "#3DFF9A"),
            Color(hex: "#B2F542"), Color(hex: "#22A855"),
            Color(hex: "#1A8C4E"),
        ]),
        Row(count: 4, size: 40, colors: [
            Color(hex: "#B2F542"), Color(hex: "#3DFF9A"),
            Color(hex: "#22A855"), Color(hex: "#B2F542"),
        ]),
        Row(count: 5, size: 34, colors: [
            Color(hex: "#1A8C4E"), Color(hex: "#22A855"),
            Color(hex: "#3DFF9A"), Color(hex: "#1A8C4E"),
            Color(hex: "#B2F542"),
        ]),
        Row(count: 4, size: 28, colors: [
            Color(hex: "#3DFF9A"), Color(hex: "#1A8C4E"),
            Color(hex: "#22A855"), Color(hex: "#3DFF9A"),
        ]),
    ]

    var body: some View {
        VStack(spacing: 14) {
            ForEach(Array(rows.enumerated()), id: \.offset) { rowIndex, row in
                HStack(spacing: 14) {
                    ForEach(0..<row.count, id: \.self) { colIndex in
                        BubbleView(
                            baseSize: row.size,
                            color: row.colors[colIndex % row.colors.count],
                            delay: Double(rowIndex * row.count + colIndex) * 0.09
                        )
                    }
                }
            }
        }
    }
}

// MARK: - Animated Dots (loading indicator under title)

private struct LoadingDots: View {
    @State private var activeIndex = 0
    private let timer = Timer.publish(every: 0.38, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(Color(hex: "#B2F542"))
                    .frame(width: 5, height: 5)
                    .scaleEffect(activeIndex == i ? 1.5 : 0.8)
                    .opacity(activeIndex == i ? 1.0 : 0.35)
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: activeIndex)
            }
        }
        .onReceive(timer) { _ in
            activeIndex = (activeIndex + 1) % 3
        }
    }
}

// MARK: - Main View

struct FindingMatchView: View {

    var onMatchFound: (String) -> Void

    @Environment(SpeedDatingRouter.self) private var speedDatingRouter
    @Environment(SocketService.self) private var socketService
    @Environment(MatchmakingService.self) private var matchmakingService

    @State private var logoScale: CGFloat    = 0.7
    @State private var logoOpacity: Double   = 0
    @State private var titleOpacity: Double  = 0
    @State private var titleOffset: CGFloat  = 16
    @State private var gridOpacity: Double   = 0
    @State private var gridOffset: CGFloat   = 30

    @State private var glowScale: CGFloat    = 1.0
    @State private var glowOpacity: Double   = 0.15

    @State private var errorMessage: String? = nil

    var body: some View {
        ZStack {
            AppTheme.primaryBackground
                .ignoresSafeArea()

            RadialGradient(
                colors: [
                    Color(hex: "#1A8C4E").opacity(glowOpacity),
                    Color.clear,
                ],
                center: .center,
                startRadius: 10,
                endRadius: 320
            )
            .scaleEffect(glowScale)
            .ignoresSafeArea()

            VStack(spacing: 0) {

                HStack {
                    Spacer()
                    Button {
                        matchmakingService.cancelSearch()
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

                Spacer()

                Image("LogoApp")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 72, height: 72)
                    .scaleEffect(logoScale)
                    .opacity(logoOpacity)
                    .padding(.bottom, 24)

                VStack(spacing: 10) {
                    HStack(spacing: 8) {
                        Text("Finding a Match")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(.white)
                        if matchmakingService.isSearching { LoadingDots() }
                    }

                    if let error = errorMessage {
                        VStack(spacing: 12) {
                            Text(error)
                                .font(.system(size: 14))
                                .foregroundStyle(.white.opacity(0.55))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 48)

                            Button {
                                errorMessage = nil
                                startMatchmaking()
                            } label: {
                                Text("Try Again")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(AppTheme.primaryButton)
                            }
                        }
                    } else {
                        Text("We're finding someone for you to chat with!")
                            .font(.system(size: 14))
                            .foregroundStyle(.white.opacity(0.5))
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                            .padding(.horizontal, 48)
                    }
                }
                .opacity(titleOpacity)
                .offset(y: titleOffset)
                .padding(.bottom, 44)

                BubbleGrid()
                    .opacity(gridOpacity)
                    .offset(y: gridOffset)

                Spacer()

                Text("Leaving this app will remove you from the queue")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.4))
                    .padding(.bottom, 24)
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            animateIn()
            startMatchmaking()
        }
        .onDisappear {
            // Guard: only cancel if still searching (navigating forward to a match should not cancel)
            if matchmakingService.isSearching {
                matchmakingService.cancelSearch()
            }
        }
        .onChange(of: matchmakingService.isSearching) { _, isSearching in
            // When search is cancelled externally (e.g. app backgrounded), pop back to main screen.
            // Match path sets isSearching=false then immediately calls onMatchFound which pops the
            // stack — so by the time this fires for a match, popToRoot() is a safe no-op.
            if !isSearching && errorMessage == nil {
                speedDatingRouter.popToRoot()
            }
        }
        .onChange(of: socketService.isConnected) { _, isConnected in
            // Socket just reconnected — check if a match event was missed while disconnected.
            if isConnected {
                matchmakingService.recoverIfMatched()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            // App returning to foreground — poll once in case a match arrived while backgrounded.
            matchmakingService.recoverIfMatched()
        }
    }

    // MARK: - Matchmaking

    private func startMatchmaking() {
        matchmakingService.startSearch(socketService: socketService) { sessionId in
            onMatchFound(sessionId)
        } onError: { message in
            errorMessage = message
        }
    }

    // MARK: - Entrance Animations

    private func animateIn() {
        withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.1)) {
            logoScale   = 1
            logoOpacity = 1
        }
        withAnimation(.spring(response: 0.5, dampingFraction: 0.78).delay(0.3)) {
            titleOpacity = 1
            titleOffset  = 0
        }
        withAnimation(.spring(response: 0.6, dampingFraction: 0.75).delay(0.45)) {
            gridOpacity = 1
            gridOffset  = 0
        }
       
        withAnimation(
            .easeInOut(duration: 2.4)
            .repeatForever(autoreverses: true)
            .delay(0.5)
        ) {
            glowScale   = 1.3
            glowOpacity = 0.28
        }
    }
}
