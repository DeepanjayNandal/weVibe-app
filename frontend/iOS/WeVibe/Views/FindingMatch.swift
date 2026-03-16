import SwiftUI

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

// MARK: - Main View

struct FindingMatchView: View {

    @Environment(SpeedDatingRouter.self) private var speedDatingRouter

    @State private var logoScale: CGFloat    = 0.7
    @State private var logoOpacity: Double   = 0
    @State private var titleOpacity: Double  = 0
    @State private var titleOffset: CGFloat  = 16
    @State private var gridOpacity: Double   = 0
    @State private var gridOffset: CGFloat   = 30

    @State private var glowScale: CGFloat    = 1.0
    @State private var glowOpacity: Double   = 0.15

    var body: some View {
        ZStack {
            AppTheme.primaryBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {

                HStack {
                    Spacer()
                    Button {
                        speedDatingRouter.pop()
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
                .padding(.bottom, 48)

            
                LogoView(size: 100)
                    .scaleEffect(logoScale)
                    .opacity(logoOpacity)
                    .padding(.bottom, 24)

                VStack(spacing: 10) {
                    HStack(spacing: 8) {
                        Text("Finding A Match")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(.white)
                    }

                    Text("We're finding someone for you to chat to you!")
                        .font(.system(size: 14))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .padding(.horizontal, 48)
                }
                .opacity(titleOpacity)
                .offset(y: titleOffset)
                .padding(.bottom, 44)
                

                BubbleGrid()
                    .opacity(gridOpacity)
                    .offset(y: gridOffset)

                Spacer()
            }
        }
        .navigationBarHidden(true)
        .onAppear { animateIn() }
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
        // Background glow breathe
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
