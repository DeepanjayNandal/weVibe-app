import SocketIO
import Foundation

// MARK: - Event Models

struct MatchFoundEvent: Sendable {
    let sessionId: String
}

struct IncomingSpeedDatingMessage: Sendable {
    let sessionId: String
    let messageId: String
    let content: String
    let senderId: String

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
    }
}

struct IncomingPermanentMessage: Sendable {
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

    /// Latest speed dating message (for chat views — wired in a future task).
    var lastSpeedDatingMessage: IncomingSpeedDatingMessage?

    /// Latest permanent chat message (for chat views — wired in a future task).
    var lastPermanentMessage: IncomingPermanentMessage?

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
            .auth(["token": token]),
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

        // EC5 — Token refresh on reconnect.
        // socket.io-client-swift v16 config is `public private(set)` — cannot update auth token
        // externally after manager creation. If a 1-hour session lapses during queue wait, the
        // reconnect handshake will be rejected. Mitigation: reconnect with a new manager.
        // TODO (V1.1): recreate SocketManager with a fresh token on reconnect failure.

        socket?.on("matching.queue.matched") { [weak self] data, _ in
            // All events use envelope: { v: 1, data: { ... } }
            guard let envelope = data.first as? [String: Any],
                  let payload  = envelope["data"] as? [String: Any],
                  let sessionId = payload["sessionId"] as? String else { return }
            Task { @MainActor [weak self] in
                self?.lastMatchEvent = MatchFoundEvent(sessionId: sessionId)
            }
        }

        socket?.on("speed_dating.message.created") { [weak self] data, _ in
            guard let envelope = data.first as? [String: Any],
                  let payload  = envelope["data"] as? [String: Any],
                  let msg = IncomingSpeedDatingMessage(payload) else { return }
            Task { @MainActor [weak self] in
                self?.lastSpeedDatingMessage = msg
            }
        }

        socket?.on("permanent.message.created") { [weak self] data, _ in
            guard let envelope = data.first as? [String: Any],
                  let payload  = envelope["data"] as? [String: Any],
                  let msg = IncomingPermanentMessage(payload) else { return }
            Task { @MainActor [weak self] in
                self?.lastPermanentMessage = msg
            }
        }
    }
}
