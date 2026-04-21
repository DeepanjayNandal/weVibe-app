import Foundation
import Observation
import FirebaseAuth

/// Source-of-truth for the chat list UI.
///
/// - Owned fetch timing: views just read; they never hold their own arrays.
/// - Pull-to-refresh delegates back to these methods.
/// - `applyIncomingMessage` updates the list preview in-place without a round-trip.
/// - `clear()` is called on logout — same pattern as UserProfileStore and OnboardingData.
@Observable
@MainActor
final class ChatStore {

    // MARK: - State

    var matches:  [ChatListItem] = []
    var sessions: [ChatListItem] = []

    var isLoadingMatches  = false
    var isLoadingSessions = false
    var matchesError:  String? = nil
    var sessionsError: String? = nil

    // MARK: - Private

    private let apiClient = APIClient()

    // MARK: - Fetch

    func fetchMatches(token: String) async {
        isLoadingMatches = true
        matchesError     = nil
        defer { isLoadingMatches = false }

        do {
            let result = try await apiClient.getAllMatches(token: token)
            matches = result.matches.map { match in
                let lastMsg = match.lastMessageContent?.isEmpty == false
                    ? match.lastMessageContent!
                    : "Say hello! 👋"
                return ChatListItem(
                    matchId:           match.matchId,
                    name:              match.counterpartDisplayName,
                    initials:          nil,
                    counterpartUserId: match.counterpartUserId ?? "",
                    avatarSystemIcon:  nil,
                    lastMessage:       lastMsg,
                    isMine:            false,
                    timeAgo:           timeAgoLabel(match.lastMessageAt),
                    unreadCount:       match.unreadCount,
                    isTyping:          false
                )
            }
        } catch {
            matchesError = "Couldn't load matches"
            AppLogger.recordError(error, context: "fetchMatches", logger: AppLogger.chatStore)
        }
    }

    func fetchSessions(token: String) async {
        isLoadingSessions = true
        sessionsError     = nil
        defer { isLoadingSessions = false }

        do {
            let result   = try await apiClient.getAllSpeedDatingSessions(token: token)
            let list     = result.data?.sessions ?? []
            sessions = list.compactMap { session -> ChatListItem? in
                guard let sessionId = session.sessionId else { return nil }

                let lastMsg: String
                let isMine: Bool
                if let content = session.lastMessageContent, !content.isEmpty {
                    lastMsg = content
                    isMine  = session.unreadCount == 0 && session.isLastMessageMine
                } else {
                    lastMsg = statusLabel(session.status)
                    isMine  = false
                }

                return ChatListItem(
                    matchId:           sessionId,
                    name:              nil,
                    initials:          session.counterpart?.initials,
                    counterpartUserId: session.counterpart?.userId ?? "",
                    avatarSystemIcon:  nil,
                    lastMessage:       lastMsg,
                    isMine:            isMine,
                    timeAgo:           timeAgoLabel(session.lastMessageAt ?? session.sessionExpiresAt),
                    unreadCount:       session.unreadCount,
                    isTyping:          false
                )
            }
        } catch {
            sessionsError = "Couldn't load sessions"
            AppLogger.recordError(error, context: "fetchSessions", logger: AppLogger.chatStore)
        }
    }

    // MARK: - Live Updates

    /// Updates the matched-chat list preview without a re-fetch.
    /// Called from WeVibeApp on every `socket.lastPermanentMessage` event,
    /// and optionally from PermanentChattingScreen when the user sends a message.
    func applyIncomingMessage(_ event: IncomingPermanentMessage, currentUserId: String?) {
        let isMine = event.senderId == currentUserId
        matches = matches.map { item in
            guard item.matchId == event.matchId else { return item }
            return ChatListItem(
                matchId:           item.matchId,
                name:              item.name,
                initials:          item.initials,
                counterpartUserId: item.counterpartUserId,
                avatarSystemIcon:  item.avatarSystemIcon,
                lastMessage:       event.content,
                isMine:            isMine,
                timeAgo:           "just now",
                unreadCount:       isMine ? item.unreadCount : item.unreadCount + 1,
                isTyping:          false
            )
        }
    }

    /// Updates the speed-dating session list preview without a re-fetch.
    /// Called from WeVibeApp on every `socket.lastSpeedDatingMessage` event,
    /// and optionally from ActiveChattingScreen when the user sends a message.
    func applyIncomingSpeedDatingMessage(_ event: IncomingSpeedDatingMessage, currentUserId: String?) {
        let isMine = event.senderId == currentUserId
        sessions = sessions.map { item in
            guard item.matchId == event.sessionId else { return item }
            return ChatListItem(
                matchId:           item.matchId,
                name:              item.name,
                initials:          item.initials,
                counterpartUserId: item.counterpartUserId,
                avatarSystemIcon:  item.avatarSystemIcon,
                lastMessage:       event.content,
                isMine:            isMine,
                timeAgo:           "just now",
                unreadCount:       isMine ? item.unreadCount : item.unreadCount + 1,
                isTyping:          false
            )
        }
    }

    // MARK: - Typing Indicators

    /// Toggles the typing indicator for a permanent-chat row.
    /// Only shown when the event is from the counterpart (server filters, but we guard anyway).
    func applyPermanentTyping(_ event: IncomingPermanentTyping, currentUserId: String?) {
        guard event.userId != currentUserId else { return }
        matches = matches.map { item in
            guard item.matchId == event.matchId else { return item }
            return ChatListItem(
                matchId:           item.matchId,
                name:              item.name,
                initials:          item.initials,
                counterpartUserId: item.counterpartUserId,
                avatarSystemIcon:  item.avatarSystemIcon,
                lastMessage:       item.lastMessage,
                isMine:            item.isMine,
                timeAgo:           item.timeAgo,
                unreadCount:       item.unreadCount,
                isTyping:          event.isTyping
            )
        }
    }

    /// Toggles the typing indicator for a speed-dating session row.
    func applySpeedDatingTyping(_ event: IncomingSpeedDatingTyping, currentUserId: String?) {
        guard event.userId != currentUserId else { return }
        sessions = sessions.map { item in
            guard item.matchId == event.sessionId else { return item }
            return ChatListItem(
                matchId:           item.matchId,
                name:              item.name,
                initials:          item.initials,
                counterpartUserId: item.counterpartUserId,
                avatarSystemIcon:  item.avatarSystemIcon,
                lastMessage:       item.lastMessage,
                isMine:            item.isMine,
                timeAgo:           item.timeAgo,
                unreadCount:       item.unreadCount,
                isTyping:          event.isTyping
            )
        }
    }

    // MARK: - Match Removed / Blocked

    /// Removes a permanent-chat row when the counterpart removes or blocks the match.
    func removeMatch(matchId: String) {
        matches = matches.filter { $0.matchId != matchId }
    }

    // MARK: - Session Ended

    /// Updates a speed-dating session row's preview when the session ends server-side.
    func applySessionEnded(_ event: SpeedDatingSessionEndedEvent) {
        let label: String
        switch event.reason {
        case "graduated":           label = "Matched! 🎉"
        case "ended_early":         label = "Session ended early"
        case "expired":             label = "Session expired"
        default:                    label = "Session ended"
        }
        sessions = sessions.map { item in
            guard item.matchId == event.sessionId else { return item }
            return ChatListItem(
                matchId:           item.matchId,
                name:              item.name,
                initials:          item.initials,
                counterpartUserId: item.counterpartUserId,
                avatarSystemIcon:  item.avatarSystemIcon,
                lastMessage:       label,
                isMine:            false,
                timeAgo:           "just now",
                unreadCount:       item.unreadCount,
                isTyping:          false
            )
        }
    }

    /// Resets the unread badge for a speed-dating session to zero.
    /// Call this when ActiveChattingScreen marks messages as read.
    func clearSessionUnread(sessionId: String) {
        sessions = sessions.map { item in
            guard item.matchId == sessionId, item.unreadCount > 0 else { return item }
            return ChatListItem(
                matchId:           item.matchId,
                name:              item.name,
                initials:          item.initials,
                counterpartUserId: item.counterpartUserId,
                avatarSystemIcon:  item.avatarSystemIcon,
                lastMessage:       item.lastMessage,
                isMine:            item.isMine,
                timeAgo:           item.timeAgo,
                unreadCount:       0,
                isTyping:          false
            )
        }
    }

    /// Resets the unread badge for a match to zero.
    /// Call this when PermanentChattingScreen marks messages as read.
    func clearUnread(matchId: String) {
        matches = matches.map { item in
            guard item.matchId == matchId, item.unreadCount > 0 else { return item }
            return ChatListItem(
                matchId:           item.matchId,
                name:              item.name,
                initials:          item.initials,
                counterpartUserId: item.counterpartUserId,
                avatarSystemIcon:  item.avatarSystemIcon,
                lastMessage:       item.lastMessage,
                isMine:            item.isMine,
                timeAgo:           item.timeAgo,
                unreadCount:       0,
                isTyping:          false
            )
        }
    }

    // MARK: - Logout

    func clear() {
        matches           = []
        sessions          = []
        isLoadingMatches  = false
        isLoadingSessions = false
        matchesError      = nil
        sessionsError     = nil
    }

    // MARK: - Private Helpers

    private func statusLabel(_ status: String?) -> String {
        switch status {
        case "active":  return "Say hello! 👋"
        case "ended":   return "Session ended"
        case "matched": return "Matched! 🎉"
        default:        return ""
        }
    }

    private func timeAgoLabel(_ isoString: String?) -> String {
        guard let isoString else { return "" }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = formatter.date(from: isoString)
                      ?? ISO8601DateFormatter().date(from: isoString)
        else { return "" }

        let diff = Int(Date().timeIntervalSince(date))
        if diff < 60        { return "just now" }
        if diff < 3600      { return "\(diff / 60)m ago" }
        if diff < 86400     { return "\(diff / 3600)h ago" }
        if diff < 86400 * 7 { return "\(diff / 86400)d ago" }
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f.string(from: date)
    }
}