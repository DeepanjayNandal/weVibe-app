import SwiftUI

// MARK: - Tab Identity

/// Add a new case here when a new tab is introduced.
enum AppTab: Hashable {
    case speedDating
    case chat
    case listMatches
    case profile
}

// MARK: - HomeScreen

// Hosts each tab in its own NavigationStack.
// To add a tab: new AppTab case + new Tab view + new item in CustomTabBar.
struct HomeScreen: View {

    @State private var selectedTab: AppTab = .speedDating

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                SpeedDatingTab()
                    .tag(AppTab.speedDating)
                    .toolbar(.hidden, for: .tabBar)
                
                ListMatchesTab()
                    .tag(AppTab.listMatches)
                    .toolbar(.hidden, for: .tabBar)

                ChatTab()
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
// Each tab owns a NavigationStack driven by its router.
// Add .navigationDestination cases here as screens are built for each tab.

private struct SpeedDatingTab: View {
    var body: some View {
        NavigationStack { SpeedDatingPlaceholder() }
    }
}

private struct ListMatchesTab: View {
    var body: some View {
        NavigationStack { ListMatchesPlaceholder() }
    }
}

private struct ChatTab: View {
    var body: some View {
        NavigationStack { ChatPlaceholder() }
    }
}

private struct ProfileTab: View {
    var body: some View {
        NavigationStack { ProfilePlaceholder() }
    }
}

// MARK: - Placeholders
// Replace each of these with the real root screen for that tab when ready.

private struct ListMatchesPlaceholder: View {
    var body: some View {
        ZStack {
            AppTheme.primaryBackground.ignoresSafeArea()
            Text("Matches")
                .foregroundStyle(.white.opacity(0.4))
                .font(.system(size: 18, weight: .semibold))
        }
        .navigationBarBackButtonHidden(true)
    }
}

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


private struct ProfilePlaceholder: View {
    var body: some View {
        ZStack {
            AppTheme.primaryBackground.ignoresSafeArea()
            Text("Profile")
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

    // Add a new TabItem here when a new tab is introduced.
    private let items: [TabItem] = [
        TabItem(tab: .speedDating, systemImage: "stopwatch.fill"),
        TabItem(tab: .listMatches, systemImage: "heart.fill"),
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
