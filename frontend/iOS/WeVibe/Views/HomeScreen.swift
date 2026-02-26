import SwiftUI

struct HomeScreen: View {
    @State private var selectedTab: Int = 0

    var body: some View {
        Group {
            switch selectedTab {
            case 0:
                ZStack { AppTheme.primaryBackground.ignoresSafeArea() }
            case 1:
                ZStack { AppTheme.primaryBackground.ignoresSafeArea() }
            default:
                ZStack { AppTheme.primaryBackground.ignoresSafeArea() }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            CustomTabBar(selectedTab: $selectedTab)
        }
    }
}

private struct CustomTabBar: View {
    @Binding var selectedTab: Int

    private let items: [(systemImage: String, label: String)] = [
        ("stopwatch.fill", "Speed Dating"),
        ("message.fill",   "Chat"),
        ("person.fill",    "Profile"),
    ]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(items.indices, id: \.self) { index in
                Button {
                    selectedTab = index
                } label: {
                    VStack(spacing: 8) {
                        Rectangle()
                            .fill(selectedTab == index ? AppTheme.iconColor : Color.clear)
                            .frame(width: 36, height: 2)
                            .cornerRadius(1)

                        Image(systemName: items[index].systemImage)
                            .font(.system(size: 22))
                            .foregroundStyle(
                                selectedTab == index
                                    ? AppTheme.iconColor
                                    : AppTheme.iconColor.opacity(0.35)
                            )
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                }
            }
        }
        .background(
            AppTheme.secondaryBackground
                .ignoresSafeArea(edges: .bottom)
        )
    }
}
