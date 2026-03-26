import SwiftUI

/// Generic container that renders the correct UI for each ViewState phase.
///
/// Designed for screens that load a single typed payload (chat list, match queue, etc.)
/// and have no cached data to fall back on.
///
/// - `.idle` / `.loading` → full-screen spinner
/// - `.loaded(T)`         → your content view, receives the typed data
/// - `.empty`             → placeholder (swap in EmptyStateView when it exists)
/// - `.failed`            → ErrorStateView with a retry button
///
/// Example:
///   ContentStateView(state: chatStore.state, onRetry: { Task { await chatStore.fetch() } }) { chats in
///       ChatListView(chats: chats)
///   }
struct ContentStateView<T, Content: View>: View {
    let state: ViewState<T>
    var errorTitle: String = "Something went wrong"
    var errorMessage: String = "Check your connection and try again."
    let onRetry: () -> Void
    @ViewBuilder let content: (T) -> Content

    var body: some View {
        switch state {
        case .idle, .loading:
            ZStack {
                AppTheme.primaryBackground.ignoresSafeArea()
                ProgressView().tint(.white).scaleEffect(1.4)
            }

        case .loaded(let data):
            content(data)

        case .empty:
            // Replace with EmptyStateView when that component is built.
            ZStack {
                AppTheme.primaryBackground.ignoresSafeArea()
                Text("Nothing here yet")
                    .font(.system(size: 16))
                    .foregroundStyle(.white.opacity(0.5))
            }

        case .failed:
            ErrorStateView(
                title: errorTitle,
                message: errorMessage,
                onRetry: onRetry
            )
        }
    }
}
