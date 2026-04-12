import SwiftUI
import FirebaseAuth

// MARK: - Data Models

struct ChatListItem: Identifiable {
    let id = UUID()
    let matchId: String
    let name: String?
    let avatarSystemIcon: String?
    let lastMessage: String
    let isMine: Bool
    let timeAgo: String
    let unreadCount: Int
    let isTyping: Bool
}

// MARK: - Inner Tab

private enum ChatInnerTab: CaseIterable {
    case anonymous, matched

    var label: String {
        switch self {
        case .anonymous: return "Speed Dating"
        case .matched:   return "Matched"
        }
    }
}

// MARK: - Chat List View

struct ChatListView: View {

    @Environment(ChatRouter.self) private var chatRouter

    @State private var innerTab: ChatInnerTab = .anonymous
    @Namespace private var tabAnimation

    // ── API state
    @State private var anonymousChats: [ChatListItem] = []
    @State private var isLoadingSessions  = false
    @State private var sessionsError: String? = nil

    private let apiClient = APIClient()

    // Placeholder until matched chat API is built
    private let matchedChats: [ChatListItem] = [
        ChatListItem(matchId: "match-1", name: "Emelie", avatarSystemIcon: "person.fill",
                     lastMessage: "Sticker 😍", isMine: false, timeAgo: "23 min", unreadCount: 1, isTyping: false),
        ChatListItem(matchId: "match-2", name: "Abigail", avatarSystemIcon: "person.fill",
                     lastMessage: "", isMine: false, timeAgo: "27 min", unreadCount: 2, isTyping: true),
        ChatListItem(matchId: "match-3", name: "Elizabeth", avatarSystemIcon: "person.fill",
                     lastMessage: "Ok, see you then.", isMine: false, timeAgo: "33 min", unreadCount: 0, isTyping: false),
    ]

    private var currentList: [ChatListItem] {
        innerTab == .anonymous ? anonymousChats : matchedChats
    }

    var body: some View {
        ZStack {
            AppTheme.primaryBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {

                header

                innerTabPicker
                    .padding(.horizontal, 24)
                    .padding(.top, 20)
                    .padding(.bottom, 8)

                // ── Content area
                Group {
                    if isLoadingSessions && innerTab == .anonymous {
                        Spacer()
                        ProgressView()
                            .tint(AppTheme.primaryButton)
                        Spacer()

                    } else if let error = sessionsError, innerTab == .anonymous {
                        Spacer()
                        VStack(spacing: 12) {
                            Text(error)
                                .font(.system(size: 14))
                                .foregroundStyle(.white.opacity(0.4))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 40)
                            Button {
                                Task { await fetchSessions() }
                            } label: {
                                Text("Try again")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(AppTheme.primaryButton)
                            }
                        }
                        Spacer()

                    } else if currentList.isEmpty && innerTab == .anonymous {
                        EmptySessionsView()

                    } else if currentList.isEmpty && innerTab == .matched {
                        EmptyMatchedView()

                    } else {
                        ScrollView(showsIndicators: false) {
                            LazyVStack(spacing: 0) {
                                ForEach(currentList) { item in
                                    ChatRowView(item: item, isAnonymous: innerTab == .anonymous)
                                        .onTapGesture {
                                            if innerTab == .anonymous {
                                                chatRouter.navigate(to: .activeChat(matchId: item.matchId))
                                            } else {
                                                chatRouter.navigate(to: .permanentChat(matchId: item.matchId))
                                            }
                                        }
                                    Rectangle()
                                        .fill(Color.white.opacity(0.06))
                                        .frame(height: 1)
                                        .padding(.leading, 84)
                                }
                            }
                            .padding(.top, 8)
                            .padding(.bottom, 100)
                        }
                        .refreshable { await fetchSessions() }
                        .animation(.easeInOut(duration: 0.2), value: innerTab)
                    }
                }
            }
        }
        .task { await fetchSessions() }
        .onChange(of: innerTab) { _, tab in
            if tab == .anonymous { Task { await fetchSessions() } }
        }
    }

    // MARK: - Fetch Sessions

    private func fetchSessions() async {
        isLoadingSessions = true
        sessionsError     = nil

        guard let user  = Auth.auth().currentUser,
              let token = try? await user.getIDToken()
        else {
            isLoadingSessions = false
            sessionsError     = "Not signed in"
            return
        }

        do {
            let result   = try await apiClient.getAllSpeedDatingSessions(token: token)
            let sessions = result.data?.sessions ?? []

            anonymousChats = sessions.compactMap { session -> ChatListItem? in
                guard let sessionId = session?.sessionId else { return nil }
                return ChatListItem(
                    matchId:          sessionId,
                    name:             nil,
                    avatarSystemIcon: nil,
                    lastMessage:      statusLabel(session?.status),
                    isMine:           false,
                    timeAgo:          expiryLabel(session?.sessionExpiresAt),
                    unreadCount:      0,
                    isTyping:         false
                )
            }
        } catch {
            sessionsError = "Couldn't load sessions"
            print("❌ [ChatList] fetchSessions: \(error)")
        }

        isLoadingSessions = false
    }

    // MARK: - Helpers

    private func statusLabel(_ status: String?) -> String {
        switch status {
        case "active":  return "Active session"
        case "ended":   return "Session ended"
        case "matched": return "Matched! 🎉"
        default:        return ""
        }
    }

    private func expiryLabel(_ isoString: String?) -> String {
        guard let isoString,
              let date = ISO8601DateFormatter().date(from: isoString)
        else { return "" }
        let remaining = date.timeIntervalSinceNow
        guard remaining > 0 else { return "Expired" }
        let hours   = Int(remaining) / 3600
        let minutes = (Int(remaining) % 3600) / 60
        if hours   > 0 { return "\(hours)h left" }
        if minutes > 0 { return "\(minutes)m left" }
        return "< 1m left"
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center) {
            HStack(spacing: 10) {
                Text("Chats")
                    .font(.system(size: 32, weight: .black))
                    .foregroundStyle(.white)
                LogoWithoutText(size: 50)
            }
            Spacer()
            Button { Task { await fetchSessions() } } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(AppTheme.smallText)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(Color.white.opacity(0.08)))
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
        .padding(.bottom, 8)
    }

    // MARK: - Inner Tab Picker

    private var innerTabPicker: some View {
        HStack(spacing: 0) {
            ForEach(ChatInnerTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        innerTab = tab
                    }
                } label: {
                    VStack(spacing: 8) {
                        Text(tab.label)
                            .font(.system(size: 14, weight: innerTab == tab ? .bold : .medium))
                            .foregroundStyle(innerTab == tab ? .white : Color.white.opacity(0.4))
                            .frame(maxWidth: .infinity)

                        ZStack {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.white.opacity(0.08))
                                .frame(height: 3)
                            if innerTab == tab {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(AppTheme.primaryButton)
                                    .frame(height: 3)
                                    .matchedGeometryEffect(id: "indicator", in: tabAnimation)
                            }
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Chat Row

private struct ChatRowView: View {
    let item: ChatListItem
    let isAnonymous: Bool

    var body: some View {
        HStack(spacing: 14) {
            avatarView.frame(width: 56, height: 56)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(isAnonymous ? "Anonymous" : (item.name ?? "Unknown"))
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                    Spacer()
                    Text(item.timeAgo)
                        .font(.system(size: 12))
                        .foregroundStyle(Color.white.opacity(0.35))
                }
                HStack {
                    if item.isTyping {
                        TypingIndicator()
                    } else {
                        Text(item.isMine ? "You: \(item.lastMessage)" : item.lastMessage)
                            .font(.system(size: 13))
                            .foregroundStyle(Color.white.opacity(0.5))
                            .lineLimit(1)
                    }
                    Spacer()
                    if item.unreadCount > 0 {
                        Text("\(item.unreadCount)")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.black)
                            .frame(width: 22, height: 22)
                            .background(Circle().fill(AppTheme.primaryButton))
                    }
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var avatarView: some View {
        if isAnonymous {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.07))
                    .overlay(Circle().strokeBorder(Color.white.opacity(0.1), lineWidth: 1))
                Image(systemName: "person.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(Color.white.opacity(0.3))
            }
        } else {
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [Color(hex: "#1A8C4E"), Color(hex: "#0d5c32")],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ))
                Image(systemName: "person.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(.white.opacity(0.8))
            }
            .overlay(Circle().strokeBorder(Color(hex: "#2A4A35"), lineWidth: 1.5))
        }
    }
}

// MARK: - Typing Indicator

private struct TypingIndicator: View {
    @State private var activeIndex = 0
    private let timer = Timer.publish(every: 0.35, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 3) {
            Text("Typing")
                .font(.system(size: 13))
                .foregroundStyle(Color.white.opacity(0.5))
            HStack(spacing: 2) {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(Color.white.opacity(activeIndex == i ? 0.7 : 0.25))
                        .frame(width: 4, height: 4)
                        .scaleEffect(activeIndex == i ? 1.3 : 1.0)
                        .animation(.spring(response: 0.25, dampingFraction: 0.6), value: activeIndex)
                }
            }
        }
        .onReceive(timer) { _ in activeIndex = (activeIndex + 1) % 3 }
    }
}

// MARK: - Empty Sessions View (Speed Dating tab)

private struct EmptySessionsView: View {

    @State private var floatY: CGFloat    = 0
    @State private var eyeScale: CGFloat  = 1
    @State private var blinkOpacity: Double = 0
    @State private var sparkle1: CGFloat  = 0
    @State private var sparkle2: CGFloat  = 0

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            ZStack {
                // Sparkles
                SparkleView(size: 10, delay: 0)
                    .offset(x: -70, y: -30)
                    .opacity(sparkle1)
                SparkleView(size: 8, delay: 0.3)
                    .offset(x: 75, y: -20)
                    .opacity(sparkle2)
                SparkleView(size: 6, delay: 0.6)
                    .offset(x: 50, y: -60)
                    .opacity(sparkle1)

                FrogView(eyeScale: eyeScale, blinkOpacity: blinkOpacity)
                    .offset(y: floatY)
            }
            .padding(.bottom, 28)

            VStack(spacing: 8) {
                Text("No active session yet")
                    .font(.system(size: 20, weight: .black))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 40)

            Spacer()
        }
        .onAppear {
            // Float loop
            withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) {
                floatY = -14
            }
            // Blink every 3s
            blinkLoop()
            // Sparkles
            withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true).delay(0.2)) {
                sparkle1 = 1
            }
            withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true).delay(0.8)) {
                sparkle2 = 1
            }
        }
    }

    private func blinkLoop() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            withAnimation(.easeIn(duration: 0.06)) { blinkOpacity = 1; eyeScale = 0.1 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                withAnimation(.easeOut(duration: 0.08)) { blinkOpacity = 0; eyeScale = 1 }
                blinkLoop()
            }
        }
    }
}

// MARK: - Frog Drawing

private struct FrogView: View {
    let eyeScale: CGFloat
    let blinkOpacity: Double

    var body: some View {
        ZStack {
            // Shadow
            Ellipse()
                .fill(Color.black.opacity(0.18))
                .frame(width: 110, height: 22)
                .offset(y: 68)
                .blur(radius: 6)

            // Body
            RoundedRectangle(cornerRadius: 60)
                .fill(LinearGradient(
                    colors: [Color(hex: "#4ADE80"), Color(hex: "#16A34A")],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ))
                .frame(width: 110, height: 90)
                .offset(y: 20)

            // Belly
            Ellipse()
                .fill(Color(hex: "#BBF7D0").opacity(0.6))
                .frame(width: 64, height: 52)
                .offset(y: 34)

            // Left eye white
            Circle()
                .fill(.white)
                .frame(width: 34, height: 34)
                .offset(x: -22, y: -12)
            // Right eye white
            Circle()
                .fill(.white)
                .frame(width: 34, height: 34)
                .offset(x: 22, y: -12)

            // Left pupil
            Circle()
                .fill(Color(hex: "#1A3A1A"))
                .frame(width: 16, height: 16)
                .scaleEffect(CGSize(width: 1, height: eyeScale))
                .offset(x: -20, y: -10)
            // Right pupil
            Circle()
                .fill(Color(hex: "#1A3A1A"))
                .frame(width: 16, height: 16)
                .scaleEffect(CGSize(width: 1, height: eyeScale))
                .offset(x: 24, y: -10)

            // Shine left eye
            Circle()
                .fill(.white.opacity(0.8))
                .frame(width: 5, height: 5)
                .offset(x: -15, y: -15)
            // Shine right eye
            Circle()
                .fill(.white.opacity(0.8))
                .frame(width: 5, height: 5)
                .offset(x: 29, y: -15)

            // Smile
            Arc(startAngle: .degrees(10), endAngle: .degrees(170))
                .stroke(Color(hex: "#15803D"), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .frame(width: 40, height: 16)
                .offset(y: 22)

            // Left nostril
            Circle()
                .fill(Color(hex: "#15803D"))
                .frame(width: 5, height: 5)
                .offset(x: -8, y: 8)
            // Right nostril
            Circle()
                .fill(Color(hex: "#15803D"))
                .frame(width: 5, height: 5)
                .offset(x: 8, y: 8)

            // Left arm
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(hex: "#4ADE80"))
                .frame(width: 18, height: 36)
                .rotationEffect(.degrees(-20))
                .offset(x: -62, y: 30)
            // Right arm
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(hex: "#4ADE80"))
                .frame(width: 18, height: 36)
                .rotationEffect(.degrees(20))
                .offset(x: 62, y: 30)

            // Left foot
            Ellipse()
                .fill(Color(hex: "#16A34A"))
                .frame(width: 36, height: 18)
                .offset(x: -32, y: 66)
            // Right foot
            Ellipse()
                .fill(Color(hex: "#16A34A"))
                .frame(width: 36, height: 18)
                .offset(x: 32, y: 66)

            // Heart held in hands
            Image(systemName: "heart.fill")
                .font(.system(size: 20))
                .foregroundStyle(Color(hex: "#FB7185"))
                .offset(y: 50)
        }
        .frame(width: 140, height: 160)
    }
}

// MARK: - Arc Shape

private struct Arc: Shape {
    let startAngle: Angle
    let endAngle: Angle

    func path(in rect: CGRect) -> Path {
        Path { p in
            p.addArc(
                center:     CGPoint(x: rect.midX, y: rect.midY),
                radius:     rect.width / 2,
                startAngle: startAngle,
                endAngle:   endAngle,
                clockwise:  false
            )
        }
    }
}

// MARK: - Sparkle

private struct SparkleView: View {
    let size: CGFloat
    let delay: Double
    @State private var rotation: Double = 0

    var body: some View {
        Image(systemName: "sparkle")
            .font(.system(size: size))
            .foregroundStyle(Color(hex: "#B2F542"))
            .rotationEffect(.degrees(rotation))
            .onAppear {
                withAnimation(.linear(duration: 3).repeatForever(autoreverses: false).delay(delay)) {
                    rotation = 360
                }
            }
    }
}

// MARK: - Empty Matched View

private struct EmptyMatchedView: View {
    @State private var floatY: CGFloat = 0

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            Text("🫧")
                .font(.system(size: 80))
                .offset(y: floatY)
                .padding(.bottom, 24)

            VStack(spacing: 8) {
                Text("no matches yet bestie")
                    .font(.system(size: 20, weight: .black))
                    .foregroundStyle(.white)

                Text("finish a speed dating session first.\nyou got this 💪")
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.45))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            .padding(.horizontal, 40)

            Spacer()
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                floatY = -12
            }
        }
    }
}
