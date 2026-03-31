import Foundation
import FirebaseAuth
import UserNotifications

// MARK: - MatchmakingService

/// Manages the speed dating queue search lifecycle.
/// Injected via @Environment at app root — consumed by FindingMatchView and HomeScreen.
@Observable
@MainActor
final class MatchmakingService {

    // MARK: - State

    /// True while the user is actively searching for a match.
    /// HomeScreen uses this to lock non-speed-dating tabs.
    private(set) var isSearching = false

    // MARK: - Private

    private var searchTask: Task<Void, Never>?
    private let apiClient = APIClient()

    // MARK: - Search

    /// Joins the queue and waits for a match.
    /// Calls `onFound` with the sessionId on success, `onError` with a display message on failure.
    func startSearch(
        socketService: SocketService,
        onFound: @escaping (String) -> Void,
        onError: @escaping (String) -> Void
    ) {
        searchTask?.cancel()
        isSearching = true
        socketService.lastMatchEvent = nil  // clear stale event from any previous round

        searchTask = Task {
            // Request notification permission on first queue join (needed for EC2 background alert)
            await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound])

            guard let token = try? await Auth.auth().currentUser?.getIDToken() else {
                isSearching = false
                onError("Not signed in.")
                return
            }

            do {
                let result = try await apiClient.joinQueue(token: token)

                // Immediate match — no need to wait for socket event
                if result.state == "matched", let sessionId = result.sessionId {
                    guard !Task.isCancelled else { return }
                    isSearching = false
                    onFound(sessionId)
                    return
                }

                // Waiting — poll for the matching.queue.matched socket event (100ms interval)
                while !Task.isCancelled {
                    if let event = socketService.lastMatchEvent {
                        socketService.lastMatchEvent = nil
                        isSearching = false
                        onFound(event.sessionId)
                        return
                    }
                    try await Task.sleep(nanoseconds: 100_000_000)
                }

            } catch is CancellationError {
                // Cancelled by cancelSearch() — leaveQueue is handled there
            } catch {
                guard !Task.isCancelled else { return }
                isSearching = false
                onError(error.localizedDescription)
            }
        }
    }

    /// Cancels the active search and leaves the queue.
    func cancelSearch() {
        searchTask?.cancel()
        searchTask = nil
        isSearching = false

        // Fire-and-forget — best effort, non-blocking
        Task {
            guard let token = try? await Auth.auth().currentUser?.getIDToken() else { return }
            try? await apiClient.leaveQueue(token: token)
        }
    }
}
