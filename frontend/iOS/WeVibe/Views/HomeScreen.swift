import SwiftUI
import FirebaseAuth

// MARK: - Tab Identity

enum AppTab: Hashable {
    case speedDating
    case chat
    case listMatches
    case profile
}

// MARK: - HomeScreen

struct HomeScreen: View {

    @State private var selectedTab: AppTab             = .speedDating
    @State private var pendingMatchId: String?         = nil
    @State private var pendingPermanentMatchId: String? = nil

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                SpeedDatingTab(
                    selectedTab: $selectedTab,
                    onMatchFound: { matchId in
                        DispatchQueue.main.async {
                            pendingMatchId = matchId
                            selectedTab    = .chat
                        }
                    }
                )
                .tag(AppTab.speedDating)
                .toolbar(.hidden, for: .tabBar)

                ChatTab(
                    selectedTab: $selectedTab,
                    pendingMatchId: $pendingMatchId,
                    pendingPermanentMatchId: $pendingPermanentMatchId
                )
                .tag(AppTab.chat)
                .toolbar(.hidden, for: .tabBar)

                ProfileTab(selectedTab: $selectedTab)
                    .tag(AppTab.profile)
                    .toolbar(.hidden, for: .tabBar)
            }
        }
        .ignoresSafeArea(edges: .bottom)
        .onReceive(NotificationCenter.default.publisher(for: .pushNotificationTapped)) { notification in
            guard let userInfo = notification.userInfo,
                  let type = userInfo["type"] as? String else { return }
            selectedTab = .chat
            switch type {
            case "speed_dating_message":
                if let sessionId = userInfo["sessionId"] as? String {
                    pendingMatchId = sessionId
                }
            case "permanent_message":
                if let matchId = userInfo["matchId"] as? String {
                    pendingPermanentMatchId = matchId
                }
            default:
                break
            }
        }
    }
}

// MARK: - Speed Dating Tab

private struct SpeedDatingTab: View {
    @Binding var selectedTab: AppTab
    var onMatchFound: (String) -> Void

    @State private var speedDatingRouter = SpeedDatingRouter()

    var body: some View {
        NavigationStack(path: $speedDatingRouter.path) {
            ZStack(alignment: .bottom) {
                SpeedDatingPlaceholder()
                CustomTabBar(selectedTab: $selectedTab)
            }
            .ignoresSafeArea(edges: .bottom)
            .navigationBarBackButtonHidden(true)
            .navigationDestination(for: SpeedDatingRoute.self) { route in
                switch route {
                case .main:         SpeedDatingPlaceholder()
                case .rules:        SpeedDatingRules().navigationBarBackButtonHidden(true)
                case .tests:        PersonalityTestView()
                case .joinQueue:
                    JoinQueueView(onGoToProfile: {
                        speedDatingRouter.popToRoot()
                        selectedTab = .profile
                    })
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
    @Binding var selectedTab: AppTab
    @Binding var pendingMatchId: String?
    @Binding var pendingPermanentMatchId: String?

    @Environment(ChatStore.self) private var chatStore
    @State private var chatRouter = ChatRouter()
    @State private var chatInnerTab: ChatInnerTab = .anonymous

    var body: some View {
        NavigationStack(path: $chatRouter.path) {
            ZStack(alignment: .bottom) {
                ChatListView(innerTab: $chatInnerTab)
                CustomTabBar(selectedTab: $selectedTab)
            }
            .ignoresSafeArea(edges: .bottom)
            .navigationBarBackButtonHidden(true)
            .navigationDestination(for: ChatRoute.self) { route in
                switch route {
                case .activeChat(let matchId):
                    ActiveChatView(
                            matchId: matchId,
                            onClose: {
                                chatInnerTab = .anonymous
                                chatRouter.popToRoot()
                            },
                            onLeaveSession: {
                                chatRouter.popToRoot()
                                selectedTab = .speedDating
                            },
                            onMatchedToPermanent: { permanentMatchId in
                                chatRouter.popToRoot()
                                chatInnerTab = .matched
                                Task {
                                    guard let token = try? await Auth.auth().currentUser?.getIDToken() else {
                                        pendingPermanentMatchId = permanentMatchId
                                        return
                                    }
                                    await chatStore.fetchMatches(token: token)
                                    pendingPermanentMatchId = permanentMatchId
                                }
                            }
                        )
                case .permanentChat(let matchId, let name, let counterpartUserId, let photoUrl):
                    PermanentChatView(
                        matchId: matchId,
                        matchName: name,
                        counterpartUserId: counterpartUserId,
                        photoUrl: photoUrl,
                        onBack: {
                            chatInnerTab = .matched
                            chatRouter.popToRoot()
                        }
                    )
                }
            }
        }
        .onChange(of: pendingMatchId) { _, newMatchId in
            guard let matchId = newMatchId else { return }
            chatRouter.navigate(to: .activeChat(matchId: matchId))
            pendingMatchId = nil
        }
        .onChange(of: pendingPermanentMatchId) { _, matchId in
            guard let matchId else { return }
            chatInnerTab = .matched
            if !tryNavigateToPermanentChat(matchId: matchId), !chatStore.isLoadingMatches {
                // Matches already finished loading and the match isn't there —
                // clear the intent so we don't retry forever; user lands on matched tab.
                pendingPermanentMatchId = nil
            }
        }
        .onChange(of: chatStore.isLoadingMatches) { _, isLoading in
            // When a fetch completes, make one final navigation attempt.
            // If still not found the match doesn't exist — clear and stay on matched tab.
            guard !isLoading, let matchId = pendingPermanentMatchId else { return }
            if !tryNavigateToPermanentChat(matchId: matchId) {
                pendingPermanentMatchId = nil
            }
        }
        .environment(chatRouter)
    }

    /// Attempts to navigate to the permanent chat for `matchId`.
    /// Returns `true` and clears `pendingPermanentMatchId` on success.
    /// Returns `false` without side-effects when the match isn't in the local cache yet.
    @discardableResult
    private func tryNavigateToPermanentChat(matchId: String) -> Bool {
        guard let match = chatStore.matches.first(where: { $0.matchId == matchId }),
              let name = match.name else { return false }
        pendingPermanentMatchId = nil
        chatRouter.navigate(to: .permanentChat(
            matchId: matchId,
            name: name,
            counterpartUserId: match.counterpartUserId,
            photoUrl: match.photoUrl
        ))
        return true
    }
}

// MARK: - Profile Tab

private struct ProfileTab: View {
    @Binding var selectedTab: AppTab

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                ProfileView()
                CustomTabBar(selectedTab: $selectedTab)
            }
            .ignoresSafeArea(edges: .bottom)
            .navigationBarBackButtonHidden(true)
        }
    }
}

// MARK: - Custom Tab Bar

struct CustomTabBar: View {
    @Binding var selectedTab: AppTab
    @Environment(MatchmakingService.self) private var matchmakingService

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
                let isLocked = matchmakingService.isSearching && item.tab != .speedDating
                Button {
                    guard !isLocked else { return }
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
                                isLocked
                                    ? AppTheme.iconColor.opacity(0.2)
                                    : selectedTab == item.tab
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
