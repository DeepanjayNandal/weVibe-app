// MARK: - ViewState

/// Represents the lifecycle of an async data load.
/// Use this as a single source of truth in stores instead of separate
/// `isLoading` / `fetchFailed` booleans, which allow impossible states.
///
/// Usage in a store:
///   var state: ViewState<[Conversation]> = .idle
///
/// Usage with ContentStateView:
///   ContentStateView(state: chatStore.state, onRetry: { ... }) { chats in
///       ChatListView(chats: chats)
///   }
enum ViewState<T> {
    case idle
    case loading
    case loaded(T)
    case empty
    case failed(String)

    // MARK: Helpers

    var isLoading: Bool {
        if case .loading = self { return true }
        return false
    }

    var isFailed: Bool {
        if case .failed = self { return true }
        return false
    }

    var isLoaded: Bool {
        if case .loaded = self { return true }
        return false
    }

    var failureMessage: String? {
        if case .failed(let msg) = self { return msg }
        return nil
    }
}
