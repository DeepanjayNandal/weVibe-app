import SwiftUI

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

// MARK: - Smaller Inner Tab

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

    private let anonymousChats: [ChatListItem] = [
        ChatListItem(matchId: "anon-1", name: nil, avatarSystemIcon: nil,
                     lastMessage: "Sticker 😍", isMine: false, timeAgo: "23 min", unreadCount: 1, isTyping: false),
        ChatListItem(matchId: "anon-2", name: nil, avatarSystemIcon: nil,
                     lastMessage: "", isMine: false, timeAgo: "27 min", unreadCount: 2, isTyping: true),
        ChatListItem(matchId: "anon-3", name: nil, avatarSystemIcon: nil,
                     lastMessage: "Ok, see you then.", isMine: false, timeAgo: "33 min", unreadCount: 0, isTyping: false),
        ChatListItem(matchId: "anon-4", name: nil, avatarSystemIcon: nil,
                     lastMessage: "Hey! What's up, long time..", isMine: true, timeAgo: "50 min", unreadCount: 0, isTyping: false),
    ]

    private let matchedChats: [ChatListItem] = [
        ChatListItem(matchId: "match-1", name: "Emelie", avatarSystemIcon: "person.fill",
                     lastMessage: "Sticker 😍", isMine: false, timeAgo: "23 min", unreadCount: 1, isTyping: false),
        ChatListItem(matchId: "match-2", name: "Abigail", avatarSystemIcon: "person.fill",
                     lastMessage: "", isMine: false, timeAgo: "27 min", unreadCount: 2, isTyping: true),
        ChatListItem(matchId: "match-3", name: "Elizabeth", avatarSystemIcon: "person.fill",
                     lastMessage: "Ok, see you then.", isMine: false, timeAgo: "33 min", unreadCount: 0, isTyping: false),
        ChatListItem(matchId: "match-4", name: "Penelope", avatarSystemIcon: "person.fill",
                     lastMessage: "Hey! What's up, long time..", isMine: true, timeAgo: "50 min", unreadCount: 0, isTyping: false),
        ChatListItem(matchId: "match-5", name: "Chloe", avatarSystemIcon: "person.fill",
                     lastMessage: "Hello how are you?", isMine: true, timeAgo: "55 min", unreadCount: 0, isTyping: false),
        ChatListItem(matchId: "match-6", name: "Grace", avatarSystemIcon: "person.fill",
                     lastMessage: "Great I will write later..", isMine: true, timeAgo: "1 hour", unreadCount: 0, isTyping: false),
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
                .animation(.easeInOut(duration: 0.2), value: innerTab)
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 10) {
                    Text("Chats")
                        .font(.system(size: 32, weight: .black))
                        .foregroundStyle(.white)
                    LogoWithoutText(size: 50)
                }
            }
            Spacer()
            Button {} label: {
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

            avatarView
                .frame(width: 56, height: 56)

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

    // MARK: Avatar

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
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "#1A8C4E"), Color(hex: "#0d5c32")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

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
        .onReceive(timer) { _ in
            activeIndex = (activeIndex + 1) % 3
        }
    }
}
