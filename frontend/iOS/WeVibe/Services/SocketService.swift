import SocketIO
import Foundation
import FirebaseAuth

// MARK: - Event Models

struct MatchFoundEvent: Sendable, Equatable {
    let sessionId: String
}

struct IncomingSpeedDatingMessage: Sendable, Equatable {
    let sessionId: String
    let messageId: String
    let content: String
    let senderId: String
    let createdAt: String

    init?(_ dict: [String: Any]) {
        guard let sessionId = dict["sessionId"] as? String,
              let msg       = dict["message"] as? [String: Any],
              let messageId = msg["id"] as? String,
              let content   = msg["content"] as? String,
              let senderId  = msg["senderId"] as? String else { return nil }
        self.sessionId = sessionId
        self.messageId = messageId
        self.content   = content
        self.senderId  = senderId
        self.createdAt = msg["createdAt"] as? String ?? ""
    }
}


struct IncomingSpeedDatingTyping: Sendable, Equatable {
    let sessionId: String
    let userId: String
    let isTyping: Bool

    init?(_ dict: [String: Any]) {
        guard let sessionId = dict["sessionId"] as? String,
              let userId    = dict["userId"]    as? String,
              let isTyping  = dict["isTyping"]  as? Bool else { return nil }
        self.sessionId = sessionId
        self.userId    = userId
        self.isTyping  = isTyping
    }
}

// Partner tapped heart — requesting early match
struct IncomingMoveToPermanentRequested: Sendable, Equatable {
    let sessionId: String

    init?(_ dict: [String: Any]) {
        guard let sessionId = dict["sessionId"] as? String else { return nil }
        self.sessionId = sessionId
    }
}

// One user submitted final yes/no — notifies the other
struct IncomingFinalDecisionUpdated: Sendable, Equatable {
    let sessionId: String
    let userId: String
    let decision: String   // "yes" | "no"

    init?(_ dict: [String: Any]) {
        guard let sessionId = dict["sessionId"] as? String,
              let userId    = dict["userId"]    as? String,
              let decision  = dict["decision"]  as? String else { return nil }
        self.sessionId = sessionId
        self.userId    = userId
        self.decision  = decision
    }
}

// Both said yes — session graduates to permanent chat
struct IncomingMoveToPermanentUpdated: Sendable, Equatable {
    let sessionId: String
    let matchId: String

    init?(_ dict: [String: Any]) {
        guard let sessionId = dict["sessionId"] as? String,
              let matchId   = dict["matchId"]   as? String else { return nil }
        self.sessionId = sessionId
        self.matchId   = matchId
    }
}

// Partner declined early match request — only sent to the requester
struct IncomingMoveToPermanentResponded: Sendable, Equatable {
    let sessionId: String
    let respondedByUserId: String
    let accepted: Bool

    init?(_ dict: [String: Any]) {
        guard let sessionId         = dict["sessionId"]         as? String,
              let respondedByUserId = dict["respondedByUserId"] as? String,
              let accepted          = dict["accepted"]          as? Bool else { return nil }
        self.sessionId         = sessionId
        self.respondedByUserId = respondedByUserId
        self.accepted          = accepted
    }
}

// Session ended with a reason
struct SpeedDatingSessionEndedEvent: Sendable, Equatable {
    let sessionId: String
    let reason: String     // "graduated" | "archived_no_match" | "archived_mismatch" | "ended_early" | "expired"
    let matchId: String?   // only present when reason == "graduated"

    init?(_ dict: [String: Any]) {
        guard let sessionId = dict["sessionId"] as? String,
              let reason    = dict["reason"]    as? String else { return nil }
        self.sessionId = sessionId
        self.reason    = reason
        self.matchId   = dict["matchId"] as? String
    }
}

struct IncomingPermanentMessage: Sendable, Equatable {
    let matchId: String
    let messageId: String
    let content: String
    let senderId: String
    let createdAt: String

    init?(_ dict: [String: Any]) {
        guard let matchId   = dict["matchId"] as? String,
              let msg       = dict["message"] as? [String: Any],
              let messageId = msg["id"] as? String,
              let content   = msg["content"] as? String,
              let senderId  = msg["senderId"] as? String else { return nil }
        self.matchId   = matchId
        self.messageId = messageId
        self.content   = content
        self.senderId  = senderId
        self.createdAt = msg["createdAt"] as? String ?? ""
    }
}

struct IncomingPermanentTyping: Sendable, Equatable {
    let matchId: String
    let userId: String
    let isTyping: Bool

    init?(_ dict: [String: Any]) {
        guard let matchId  = dict["matchId"]  as? String,
              let userId   = dict["userId"]   as? String,
              let isTyping = dict["isTyping"] as? Bool else { return nil }
        self.matchId  = matchId
        self.userId   = userId
        self.isTyping = isTyping
    }
}

struct IncomingPermanentMatchRemoved: Sendable, Equatable {
    let matchId: String
    init?(_ dict: [String: Any]) {
        guard let matchId = dict["matchId"] as? String else { return nil }
        self.matchId = matchId
    }
}

struct IncomingPermanentMatchBlocked: Sendable, Equatable {
    let matchId: String
    let blockedByUserId: String
    init?(_ dict: [String: Any]) {
        guard let matchId         = dict["matchId"]         as? String,
              let blockedByUserId = dict["blockedByUserId"] as? String else { return nil }
        self.matchId         = matchId
        self.blockedByUserId = blockedByUserId
    }
}

// MARK: - SocketService

/// Wraps socket.io-client-swift. Connects after login, disconnects on logout.
/// Injected via @Environment at app root — consumed by MatchmakingService and future chat views.
///
/// IMPORTANT: Requires `socket.io-client-swift` (≥ v16.1.0) added via SPM:
///   File → Add Package Dependencies → https://github.com/socketio/socket.io-client-swift
///   Version: Up To Next Major from 16.1.0 — select the `SocketIO` product.
@Observable
@MainActor
final class SocketService {

    // MARK: - State

    var isConnected = false

    /// Latest match-found event. Reset to nil by MatchmakingService at the start of each search
    /// to avoid acting on a stale event from a previous round.
    var lastMatchEvent: MatchFoundEvent?

    /// Latest speed dating message — consumed by ActiveChatView.
    var lastSpeedDatingMessage: IncomingSpeedDatingMessage?

    /// Latest speed dating typing event — consumed by ActiveChatView.
    var lastSpeedDatingTyping: IncomingSpeedDatingTyping?

    /// Latest permanent chat message — consumed by PermanentChatView.
    var lastPermanentMessage: IncomingPermanentMessage?

    /// Permanent chat typing indicator.
    var lastPermanentTyping: IncomingPermanentTyping?

    /// Match was removed by partner.
    var lastPermanentMatchRemoved: IncomingPermanentMatchRemoved?

    /// User was blocked by partner.
    var lastPermanentMatchBlocked: IncomingPermanentMatchBlocked?

    /// sessionId + reason of a speed dating session that just ended server-side.
    var lastSpeedDatingSessionEnded: SpeedDatingSessionEndedEvent?

    /// Partner requested early match (tapped their heart button).
    var lastMoveToPermanentRequested: IncomingMoveToPermanentRequested?

    /// Partner submitted their final decision (yes/no).
    var lastFinalDecisionUpdated: IncomingFinalDecisionUpdated?

    /// Both users said yes — graduated to permanent chat.
    var lastMoveToPermanentUpdated: IncomingMoveToPermanentUpdated?

    /// Partner declined our early match request.
    var lastMoveToPermanentResponded: IncomingMoveToPermanentResponded?

    // MARK: - Private

    private var manager: SocketManager?
    private var socket: SocketIOClient?

    // MARK: - Connection

    func connect(token: String) {
        guard let url = URL(string: AppConfig.wsBaseURL) else { return }

        if manager != nil { disconnect() }

        manager = SocketManager(socketURL: url, config: [
            .log(false),
            .compress,
            .reconnects(true),
            .reconnectWait(2),
            .reconnectWaitMax(30),
            .connectParams(["token": token]),
        ])
        socket = manager?.defaultSocket
        registerHandlers()
        socket?.connect()
    }

    func disconnect() {
        socket?.disconnect()
        socket?.removeAllHandlers()
        socket = nil
        manager = nil
        isConnected = false
    }

    // MARK: - Emit (Client → Server)

    /// Sends typing indicator to the server. Server relays to the other participant.
    /// chatType: "speed_dating" | "permanent"
    /// chatId:   sessionId or matchId
    func emitTyping(chatType: String, chatId: String, isTyping: Bool) {
        guard isConnected else { return }
        socket?.emit("typing", [
            "chatType": chatType,
            "chatId":   chatId,
            "isTyping": isTyping
        ])
    }

    // MARK: - Private Handlers

    private func registerHandlers() {
        socket?.on(clientEvent: .connect) { [weak self] _, _ in
            Task { @MainActor [weak self] in
                self?.isConnected = true
            }
        }

        socket?.on(clientEvent: .disconnect) { [weak self] _, _ in
            Task { @MainActor [weak self] in
                self?.isConnected = false
            }
        }

        socket?.on(clientEvent: .reconnectAttempt) { [weak self] _, _ in
            Task { @MainActor [weak self] in
                // Refresh token on every reconnect attempt per contract §2
                guard let fresh = try? await Auth.auth().currentUser?.getIDToken() else { return }
                // Recreate manager with fresh token — v16 config is read-only after init
                guard let self, let url = URL(string: AppConfig.wsBaseURL) else { return }
                self.manager = SocketManager(socketURL: url, config: [
                    .log(false),
                    .compress,
                    .reconnects(true),
                    .reconnectWait(2),
                    .reconnectWaitMax(30),
                    .connectParams(["token": fresh]),
                ])
                self.socket = self.manager?.defaultSocket
                self.registerHandlers()
                self.socket?.connect()
            }
        }

        // MARK: Matching

        socket?.on("matching.queue.matched") { [weak self] data, _ in
            guard let envelope  = data.first as? [String: Any],
                  let payload   = envelope["data"] as? [String: Any],
                  let sessionId = payload["sessionId"] as? String else { return }
            Task { @MainActor [weak self] in
                self?.lastMatchEvent = MatchFoundEvent(sessionId: sessionId)
            }
        }

        // MARK: Speed Dating

        socket?.on("speed_dating.message.created") { [weak self] data, _ in
            guard let envelope = data.first as? [String: Any],
                  let payload  = envelope["data"] as? [String: Any],
                  let msg      = IncomingSpeedDatingMessage(payload) else { return }
            Task { @MainActor [weak self] in
                self?.lastSpeedDatingMessage = msg
            }
        }

        socket?.on("speed_dating.typing.updated") { [weak self] data, _ in
            guard let envelope = data.first as? [String: Any],
                  let payload  = envelope["data"] as? [String: Any],
                  let event    = IncomingSpeedDatingTyping(payload) else { return }
            Task { @MainActor [weak self] in
                self?.lastSpeedDatingTyping = event
            }
        }

        socket?.on("speed_dating.session.ended") { [weak self] data, _ in
            guard let envelope = data.first as? [String: Any],
                  let payload  = envelope["data"] as? [String: Any],
                  let event    = SpeedDatingSessionEndedEvent(payload) else { return }
            Task { @MainActor [weak self] in
                self?.lastSpeedDatingSessionEnded = event
            }
        }

        socket?.on("speed_dating.session.move_to_permanent_requested") { [weak self] data, _ in
            guard let envelope = data.first as? [String: Any],
                  let payload  = envelope["data"] as? [String: Any],
                  let event    = IncomingMoveToPermanentRequested(payload) else { return }
            Task { @MainActor [weak self] in
                self?.lastMoveToPermanentRequested = event
            }
        }

        socket?.on("speed_dating.session.final_decision_updated") { [weak self] data, _ in
            guard let envelope = data.first as? [String: Any],
                  let payload  = envelope["data"] as? [String: Any],
                  let event    = IncomingFinalDecisionUpdated(payload) else { return }
            Task { @MainActor [weak self] in
                self?.lastFinalDecisionUpdated = event
            }
        }

        socket?.on("speed_dating.session.move_to_permanent_responded") { [weak self] data, _ in
            guard let envelope = data.first as? [String: Any],
                  let payload  = envelope["data"] as? [String: Any],
                  let event    = IncomingMoveToPermanentResponded(payload) else { return }
            Task { @MainActor [weak self] in
                print("💔 [Socket] move_to_permanent_responded — accepted: \(event.accepted)")
                self?.lastMoveToPermanentResponded = event
            }
        }

        socket?.on("speed_dating.session.move_to_permanent_updated") { [weak self] data, _ in
            guard let envelope = data.first as? [String: Any],
                  let payload  = envelope["data"] as? [String: Any],
                  let event    = IncomingMoveToPermanentUpdated(payload) else { return }
            Task { @MainActor [weak self] in
                self?.lastMoveToPermanentUpdated = event
            }
        }

        // MARK: Permanent Chat

        socket?.on("permanent.message.created") { [weak self] data, _ in
            guard let envelope = data.first as? [String: Any],
                  let payload  = envelope["data"] as? [String: Any],
                  let msg      = IncomingPermanentMessage(payload) else { return }
            Task { @MainActor [weak self] in
                self?.lastPermanentMessage = msg
            }
        }

        socket?.on("permanent.typing.updated") { [weak self] data, _ in
            guard let envelope = data.first as? [String: Any],
                  let payload  = envelope["data"] as? [String: Any],
                  let event    = IncomingPermanentTyping(payload) else { return }
            Task { @MainActor [weak self] in
                self?.lastPermanentTyping = event
            }
        }

        socket?.on("permanent.match.removed") { [weak self] data, _ in
            guard let envelope = data.first as? [String: Any],
                  let payload  = envelope["data"] as? [String: Any],
                  let event    = IncomingPermanentMatchRemoved(payload) else { return }
            Task { @MainActor [weak self] in
                self?.lastPermanentMatchRemoved = event
            }
        }

        socket?.on("permanent.match.blocked") { [weak self] data, _ in
            guard let envelope = data.first as? [String: Any],
                  let payload  = envelope["data"] as? [String: Any],
                  let event    = IncomingPermanentMatchBlocked(payload) else { return }
            Task { @MainActor [weak self] in
                self?.lastPermanentMatchBlocked = event
            }
        }
    }
}
