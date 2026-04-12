import SocketIO
import Foundation
import FirebaseAuth

// MARK: - Event Models

struct MatchFoundEvent: Sendable {
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

struct IncomingPermanentMessage: Sendable, Equatable {
    let matchId: String
    let messageId: String
    let content: String
    let senderId: String

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

    /// sessionId of a speed dating session that just ended server-side.
    var lastSpeedDatingSessionEnded: String?

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
                guard let fresh = try? await Auth.auth().currentUser?.getIDToken() else { return }
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
            guard let envelope  = data.first as? [String: Any],
                  let payload   = envelope["data"] as? [String: Any],
                  let sessionId = payload["sessionId"] as? String else { return }
            Task { @MainActor [weak self] in
                self?.lastSpeedDatingSessionEnded = sessionId
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
    }
}
