import SwiftUI

struct HomeScreen: View {
    var body: some View {
        TabView {
            // Tab 1: Speed Dating
            ZStack {
                AppTheme.primaryBackground
                    .ignoresSafeArea()
                Text("Speed Dating")
                    .font(.largeTitle)
                    .foregroundStyle(.white)
            }
            .tabItem {
                Label("Speed Dating", systemImage: "heart.text.square.fill")
            }

            // Tab 2: Chat
            ZStack {
                AppTheme.primaryBackground
                    .ignoresSafeArea()
                Text("Chat")
                    .font(.largeTitle)
                    .foregroundStyle(.white)
            }
            .tabItem {
                Label("Chat", systemImage: "message.fill")
            }

            // Tab 3: Profile
            ZStack {
                AppTheme.primaryBackground
                    .ignoresSafeArea()
                Text("Profile")
                    .font(.largeTitle)
                    .foregroundStyle(.white)
            }
            .tabItem {
                Label("Profile", systemImage: "person.fill")
            }
        }
        .tint(AppTheme.primaryBackground)
        .onAppear {
            let appearance = UITabBarAppearance()
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = .white
            UITabBar.appearance().standardAppearance = appearance
            UITabBar.appearance().scrollEdgeAppearance = appearance
        }
    }
}
