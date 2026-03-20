import SwiftUI

// MARK: - Tab Identity

enum AppTab: Hashable {
    case speedDating
    case chat
    case listMatches
    case profile
}

// MARK: - HomeScreen

struct HomeScreen: View {

    @State private var selectedTab: AppTab     = .speedDating
    @State private var pendingMatchId: String? = nil
    @State private var isInActiveChat: Bool    = false

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                SpeedDatingTab(selectedTab: $selectedTab, onMatchFound: { matchId in
                    DispatchQueue.main.async {
                        pendingMatchId = matchId
                        selectedTab    = .chat
                    }
                })
                .tag(AppTab.speedDating)
                .toolbar(.hidden, for: .tabBar)

                ChatTab(
                    pendingMatchId: $pendingMatchId,
                    isInActiveChat: $isInActiveChat,
                    onChatClosed: {
                        isInActiveChat = false
                        selectedTab    = .chat
                    }
                )
                .tag(AppTab.chat)
                .toolbar(.hidden, for: .tabBar)

                ProfileTab()
                    .tag(AppTab.profile)
                    .toolbar(.hidden, for: .tabBar)
            }

            CustomTabBar(selectedTab: $selectedTab)
        }
        .ignoresSafeArea(edges: .bottom)
    }
}

// MARK: - Tab Views

private struct SpeedDatingTab: View {
    @State private var speedDatingRouter = SpeedDatingRouter()
    @Binding var selectedTab: AppTab
    var onMatchFound: (String) -> Void

    var body: some View {
        NavigationStack(path: $speedDatingRouter.path) {
            SpeedDatingPlaceholder()
                .navigationDestination(for: SpeedDatingRoute.self) { route in
                    switch route {
                    case .rules:     SpeedDatingRules()
                    case .tests:     PersonalityTestView()
                    case .joinQueue: JoinQueueView()
                    case .findingMatch:
                        FindingMatchView { matchId in
                            onMatchFound(matchId)   // HomeScreen handles tab switch
                        }
                    }
                }
        }
        .environment(speedDatingRouter)
        .environment(PersonalityTestData())
    }
}

private struct ChatTab: View {
    @Binding var pendingMatchId: String?
    @Binding var isInActiveChat: Bool
    
    var onChatClosed: () -> Void
    @State private var chatRouter = ChatRouter()

    var body: some View {
        NavigationStack(path: $chatRouter.path) {
            ChatPlaceholder()
                .navigationDestination(for: ChatRoute.self) { route in
                    switch route {
                    case .activeChat(let matchId):
                        ActiveChatView(matchId: matchId) {
                            chatRouter.popToRoot()
                            onChatClosed()
                        }
                    }
                }
        }
        // When HomeScreen sets pendingMatchId, auto-push the chat screen
        .onChange(of: pendingMatchId) { _, newMatchId in
            guard let matchId = newMatchId else { return }
            chatRouter.navigate(to: .activeChat(matchId: matchId))
            pendingMatchId = nil   // clear so re-navigating doesn't re-trigger
        }
        .environment(chatRouter)
    }
}

private struct ProfileTab: View {
    var body: some View {
        NavigationStack { ProfileView() }
    }
}

// MARK: - Placeholders

private struct ChatPlaceholder: View {
    var body: some View {
        ZStack {
            AppTheme.primaryBackground.ignoresSafeArea()
            Text("Chat")
                .foregroundStyle(.white.opacity(0.4))
                .font(.system(size: 18, weight: .semibold))
        }
        .navigationBarBackButtonHidden(true)
    }
}

// MARK: - Custom Tab Bar

private struct CustomTabBar: View {
    @Binding var selectedTab: AppTab

    private struct TabItem {
        let tab: AppTab
        let systemImage: String
    }

    private let items: [TabItem] = [
        TabItem(tab: .speedDating, systemImage: "stopwatch.fill"),
        TabItem(tab: .chat,        systemImage: "message.fill"),
        TabItem(tab: .profile,     systemImage: "person.fill"),
    ]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(items, id: \.tab) { item in
                Button {
                    selectedTab = item.tab
                } label: {
                    VStack(spacing: 12) {
                        Rectangle()
                            .fill(selectedTab == item.tab ? AppTheme.iconColor : Color.clear)
                            .frame(maxWidth: 60)
                            .frame(height: 2)
                            .cornerRadius(1)

                        Image(systemName: item.systemImage)
                            .font(.system(size: 26))
                            .foregroundStyle(
                                selectedTab == item.tab
                                    ? AppTheme.iconColor
                                    : AppTheme.iconColor.opacity(0.45)
                            )
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 0)
                    .padding(.bottom, 24)
                }
            }
        }
        .background(
            AppTheme.secondaryBackground
                .ignoresSafeArea(edges: .bottom)
        )
    }
}
