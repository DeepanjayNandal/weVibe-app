import SwiftUI
import FirebaseAuth

// MARK: - Data Models

struct ChatListItem: Identifiable {
    var id: String { matchId }
    let matchId: String
    let name: String?
    let initials: String?
    let counterpartUserId: String      // used by PermanentChatView for isMine logic
    let avatarSystemIcon: String?
    let lastMessage: String
    let isMine: Bool
    let timeAgo: String
    let unreadCount: Int
    let isTyping: Bool
}

// ChatListItem identity for diffing (UUID id changes on every rebuild; matchId is stable)
extension ChatListItem: Equatable {
    static func == (lhs: ChatListItem, rhs: ChatListItem) -> Bool {
        lhs.matchId == rhs.matchId
    }
}

// MARK: - Inner Tab
enum ChatInnerTab: CaseIterable {
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
    @Environment(ChatStore.self)  private var chatStore

    @Binding var innerTab: ChatInnerTab
    @Namespace private var tabAnimation

    var body: some View {
        ZStack {
            AppTheme.primaryBackground.ignoresSafeArea()
            VStack(spacing: 0) {
                header
                innerTabPicker
                    .padding(.horizontal, 24)
                    .padding(.top, 20)
                    .padding(.bottom, 8)
                contentArea
            }
        }
    }

    @ViewBuilder private var contentArea: some View {
        if innerTab == .anonymous {
            anonymousContent
        } else {
            matchedContent
        }
    }

    @ViewBuilder private var anonymousContent: some View {
        if chatStore.isLoadingSessions {
            Spacer()
            ProgressView().tint(AppTheme.primaryButton)
            Spacer()
        } else if let error = chatStore.sessionsError {
            Spacer()
            errorView(message: error) {
                Task {
                    guard let token = try? await Auth.auth().currentUser?.getIDToken() else { return }
                    await chatStore.fetchSessions(token: token)
                }
            }
            Spacer()
        } else if chatStore.sessions.isEmpty {
            GeometryReader { geo in
                ScrollView {
                    EmptySessionsView()
                        .frame(width: geo.size.width, height: geo.size.height)
                }
                .refreshable {
                    guard let token = try? await Auth.auth().currentUser?.getIDToken() else { return }
                    await chatStore.fetchSessions(token: token)
                }
            }
        } else {
            chatList(items: chatStore.sessions, isAnonymous: true)
        }
    }

    @ViewBuilder private var matchedContent: some View {
        if chatStore.isLoadingMatches {
            Spacer()
            ProgressView().tint(AppTheme.primaryButton)
            Spacer()
        } else if let error = chatStore.matchesError {
            Spacer()
            errorView(message: error) {
                Task {
                    guard let token = try? await Auth.auth().currentUser?.getIDToken() else { return }
                    await chatStore.fetchMatches(token: token)
                }
            }
            Spacer()
        } else if chatStore.matches.isEmpty {
            GeometryReader { geo in
                ScrollView {
                    EmptyMatchedView()
                        .frame(width: geo.size.width, height: geo.size.height)
                }
                .refreshable {
                    guard let token = try? await Auth.auth().currentUser?.getIDToken() else { return }
                    await chatStore.fetchMatches(token: token)
                }
            }
        } else {
            chatList(items: chatStore.matches, isAnonymous: false)
        }
    }

    @ViewBuilder private func errorView(message: String, retry: @escaping () -> Void) -> some View {
        VStack(spacing: 12) {
            Text(message)
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.4))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Button(action: retry) {
                Text("Try again")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppTheme.primaryButton)
            }
        }
    }

    @ViewBuilder private func chatList(items: [ChatListItem], isAnonymous: Bool) -> some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 0) {
                ForEach(items) { item in
                    ChatRowView(item: item, isAnonymous: isAnonymous)
                        .onTapGesture { handleTap(item: item, isAnonymous: isAnonymous) }
                    Rectangle()
                        .fill(Color.white.opacity(0.06))
                        .frame(height: 1)
                        .padding(.leading, 84)
                }
            }
            .padding(.top, 8)
            .padding(.bottom, 100)
        }
        .refreshable {
            guard let token = try? await Auth.auth().currentUser?.getIDToken() else { return }
            if isAnonymous { await chatStore.fetchSessions(token: token) }
            else           { await chatStore.fetchMatches(token: token) }
        }
        .animation(.easeInOut(duration: 0.2), value: innerTab)
    }

    private func handleTap(item: ChatListItem, isAnonymous: Bool) {
        if isAnonymous {
            chatRouter.navigate(to: .activeChat(matchId: item.matchId))
        } else {
            chatRouter.navigate(to: .permanentChat(
                matchId:           item.matchId,
                name:              item.name ?? "Match",
                counterpartUserId: item.counterpartUserId
            ))
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 10) {
            Text("Chats")
                .font(.system(size: 32, weight: .black))
                .foregroundStyle(.white)
            LogoWithoutText(size: 50)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
                    // Title: show initials for anonymous, name for matched
                    Text(isAnonymous
                         ? (item.initials ?? "??")
                         : (item.name ?? item.initials ?? "Unknown"))
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                    Spacer()
                    Text(item.timeAgo)
                        .font(.system(size: 12))
                        .foregroundStyle(
                            item.unreadCount > 0
                                ? AppTheme.primaryButton
                                : Color.white.opacity(0.35)
                        )
                }
                HStack {
                    if item.isTyping {
                        TypingIndicator()
                    } else {
                        Text(item.isMine ? "You: \(item.lastMessage)" : item.lastMessage)
                            .font(.system(size: 13, weight: item.unreadCount > 0 ? .semibold : .regular))
                            .foregroundStyle(
                                item.unreadCount > 0
                                    ? Color.white.opacity(0.9)
                                    : Color.white.opacity(0.5)
                            )
                            .lineLimit(1)
                    }
                    Spacer()
                    // Badge: "1+" for multiple unreads, exact count for single
                    if item.unreadCount > 0 {
                        Text(item.unreadCount > 1 ? "1+" : "1")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.black)
                            .frame(minWidth: 22, minHeight: 22)
                            .padding(.horizontal, item.unreadCount > 1 ? 6 : 0)
                            .background(Capsule().fill(AppTheme.primaryButton))
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
                if let initials = item.initials, !initials.isEmpty {
                    Text(initials)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color.white.opacity(0.6))
                } else {
                    Image(systemName: "person.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(Color.white.opacity(0.3))
                }
            }
        } else {
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [Color(hex: "#1A8C4E"), Color(hex: "#0d5c32")],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ))
                if let initials = item.initials ?? item.name?.prefix(2).uppercased(), !initials.isEmpty {
                    Text(initials)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white.opacity(0.9))
                } else {
                    Image(systemName: "person.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(.white.opacity(0.8))
                }
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

            // ── Frog SVG-style character in pure SwiftUI
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

            // Copy
            VStack(spacing: 8) {
                Text("no one here but us frogs 🐸")
                    .font(.system(size: 20, weight: .black))
                    .foregroundStyle(.white)

                Text("you haven't matched with anyone yet.\ngo join the speed dating queue!")
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.45))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)

                Text("it literally takes 20 messages 💀")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AppTheme.primaryButton.opacity(0.7))
                    .padding(.top, 4)
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
