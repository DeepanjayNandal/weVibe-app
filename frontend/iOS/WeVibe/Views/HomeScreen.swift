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

    var body: some View {
        TabView(selection: $selectedTab) {
            SpeedDatingTab(onMatchFound: { matchId in
                DispatchQueue.main.async {
                    pendingMatchId = matchId
                    selectedTab    = .chat
                }
            })
            .tag(AppTab.speedDating)
            .toolbar(.hidden, for: .tabBar)

            ChatTab(pendingMatchId: $pendingMatchId)
                .tag(AppTab.chat)
                .toolbar(.hidden, for: .tabBar)

            ProfileTab()
                .tag(AppTab.profile)
                .toolbar(.hidden, for: .tabBar)
        }
        .ignoresSafeArea(edges: .bottom)
    }
}

// MARK: - Speed Dating Tab

private struct SpeedDatingTab: View {
    @State private var speedDatingRouter = SpeedDatingRouter()
    var onMatchFound: (String) -> Void

    var body: some View {
        NavigationStack(path: $speedDatingRouter.path) {
            SpeedDatingRootScreen(selectedTab: .speedDating)
                .navigationDestination(for: SpeedDatingRoute.self) { route in
                    switch route {
                    case .rules:        SpeedDatingRules()
                    case .tests:        PersonalityTestView()
                    case .joinQueue:    JoinQueueView()
                    case .findingMatch:
                        FindingMatchView { matchId in
                            speedDatingRouter.popToRoot()
                            onMatchFound(matchId)
                        }
                    }
                }
        }
        .environment(speedDatingRouter)
        .environment(PersonalityTestData())
    }
}

// MARK: - Chat Tab

private struct ChatTab: View {
    @Binding var pendingMatchId: String?
    @State private var chatRouter = ChatRouter()

    var body: some View {
        NavigationStack(path: $chatRouter.path) {
            ChatRootScreen()
                .navigationDestination(for: ChatRoute.self) { route in
                    switch route {
                    case .activeChat(let matchId):
                        ActiveChatView(matchId: matchId) {
                            chatRouter.popToRoot()
                        }
                    }
                }
        }
        .onChange(of: pendingMatchId) { _, newMatchId in
            guard let matchId = newMatchId else { return }
            chatRouter.navigate(to: .activeChat(matchId: matchId))
            pendingMatchId = nil
        }
        .environment(chatRouter)
    }
}

// MARK: - Profile Tab

private struct ProfileTab: View {
    var body: some View {
        NavigationStack {
            ProfileRootScreen()
        }
    }
}

// MARK: - Root Screens (each owns the tab bar)

struct SpeedDatingRootScreen: View {
    let selectedTab: AppTab
    @State private var tab: AppTab = .speedDating

    var body: some View {
        ZStack(alignment: .bottom) {
            SpeedDatingPlaceholder()
            CustomTabBar(selectedTab: $tab)
        }
        .ignoresSafeArea(edges: .bottom)
        .navigationBarBackButtonHidden(true)
    }
}

struct ChatRootScreen: View {
    @State private var tab: AppTab = .chat

    var body: some View {
        ZStack(alignment: .bottom) {
            ZStack {
                AppTheme.primaryBackground.ignoresSafeArea()
                Text("Chat")
                    .foregroundStyle(.white.opacity(0.4))
                    .font(.system(size: 18, weight: .semibold))
            }
            CustomTabBar(selectedTab: $tab)
        }
        .ignoresSafeArea(edges: .bottom)
        .navigationBarBackButtonHidden(true)
    }
}

struct ProfileRootScreen: View {
    @State private var tab: AppTab = .profile

    var body: some View {
        ZStack(alignment: .bottom) {
            ProfileView()
            CustomTabBar(selectedTab: $tab)
        }
        .ignoresSafeArea(edges: .bottom)
        .navigationBarBackButtonHidden(true)
    }
}

// MARK: - Custom Tab Bar

struct CustomTabBar: View {
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
