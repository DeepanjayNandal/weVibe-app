import SwiftUI
import FirebaseAuth

// MARK: - Message Model

struct ChatMessage: Identifiable {
    let id: String
    let text: String
    let isMine: Bool
    let time: String
    let messagesLeft: Int?

    static func optimistic(text: String, time: String, messagesLeft: Int) -> ChatMessage {
        ChatMessage(id: UUID().uuidString, text: text, isMine: true,
                    time: time, messagesLeft: messagesLeft)
    }
}

// MARK: - Countdown Timer View

private struct CountdownTimerView: View {
    let secondsRemaining: Int
    private var isWarning: Bool { secondsRemaining <= 600 }
    private var timeString: String {
        let h = secondsRemaining / 3600
        let m = (secondsRemaining % 3600) / 60
        let s = secondsRemaining % 60
        return String(format: "%02d:%02d:%02d", h, m, s)
    }
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: isWarning ? "exclamationmark.circle.fill" : "clock")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(isWarning ? Color.red : Color(hex: "#1A8C4E"))
            Text(timeString)
                .font(.system(size: 13, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(isWarning ? Color.red : Color(hex: "#1A8C4E"))
        }
        .padding(.horizontal, 14).padding(.vertical, 6)
        .background(
            Capsule()
                .fill(isWarning ? Color.red.opacity(0.1) : Color(hex: "#1A8C4E").opacity(0.08))
                .overlay(Capsule().strokeBorder(
                    isWarning ? Color.red.opacity(0.3) : Color(hex: "#1A8C4E").opacity(0.2), lineWidth: 1))
        )
        .animation(.easeInOut(duration: 0.3), value: isWarning)
    }
}

// MARK: - Messages Left Banner

private struct MessagesLeftBanner: View {
    let count: Int
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 13)).foregroundStyle(.red)
            Text("Only \(count) message\(count == 1 ? "" : "s") left — make them count!")
                .font(.system(size: 13, weight: .semibold)).foregroundStyle(.red)
        }
        .padding(.horizontal, 16).padding(.vertical, 10).frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.red.opacity(0.08))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.red.opacity(0.25), lineWidth: 1)))
        .padding(.horizontal, 16)
        .transition(.move(edge: .top).combined(with: .opacity))
    }
}

// MARK: - Messages Remaining Pill

private struct MessagesRemainingPill: View {
    let messagesLeft: Int
    let messageLimit: Int

    private var fraction: CGFloat {
        guard messageLimit > 0 else { return 1 }
        return CGFloat(messagesLeft) / CGFloat(messageLimit)
    }
    private var pillColor: Color {
        if messagesLeft <= 3 { return .red }
        if messagesLeft <= 5 { return Color(hex: "#FF6B35") }
        return Color(hex: "#1A8C4E")
    }

    var body: some View {
        HStack(spacing: 8) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3).fill(Color(hex: "#C8E6C9")).frame(height: 4)
                    RoundedRectangle(cornerRadius: 3).fill(pillColor)
                        .frame(width: geo.size.width * fraction, height: 4)
                        .animation(.easeInOut(duration: 0.3), value: messagesLeft)
                }
            }
            .frame(width: 48, height: 4)
            Text("\(messagesLeft) / \(messageLimit) messages")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(pillColor)
        }
        .padding(.horizontal, 14).padding(.vertical, 6)
        .background(Capsule().fill(pillColor.opacity(0.08))
            .overlay(Capsule().strokeBorder(pillColor.opacity(0.2), lineWidth: 1)))
        .animation(.easeInOut(duration: 0.3), value: messagesLeft)
    }
}

// MARK: - Active Chat View

struct ActiveChatView: View {

    let matchId: String
    var onClose: () -> Void
    var onLeaveSession: () -> Void

    @Environment(ChatRouter.self) private var chatRouter
    @Environment(MatchmakingService.self) private var matchmakingService
    @Environment(SocketService.self) private var socketService
    @Environment(\.scenePhase) private var scenePhase

    @State private var messageText: String = ""
    @FocusState private var inputFocused: Bool

    // Session state
    @State private var sessionDetail: SessionDetail? = nil
    @State private var secondsRemaining: Int     = 0
    @State private var messagesLeft: Int         = 20
    @State private var counterpartLabel: String  = "Anonymous"
    @State private var counterpartUserId: String = ""
    @State private var expiresAt: String         = ""

    // Chat state
    @State private var messages: [ChatMessage]   = []
    @State private var isSending: Bool           = false

    // Session end state
    // isSessionEnded = chat is disabled (timer expired OR server ended)
    // hasSubmittedDecision = user already tapped yes/no, now waiting for partner
    @State private var isSessionEnded: Bool      = false
    @State private var hasSubmittedDecision: Bool = false
    @State private var myDecision: String        = ""   // "yes" or "no"

    // Early match request from partner (heart button on their side)
    @State private var showPartnerRequestPopup: Bool = false

    // Confirmation before sending early match request
    @State private var showEarlyMatchConfirm: Bool = false

    // Both said yes — matched!
    @State private var matchedPermanentMatchId: String? = nil
    @State private var showMatchedCelebration: Bool     = false

    // UI state
    @State private var timerTask: Task<Void, Never>? = nil
    @State private var showMatchPopup: Bool   = false
    @State private var showLeaveConfirm: Bool = false

    private let apiClient = APIClient()

    private var showLowMessagesBanner: Bool { messagesLeft > 0 && messagesLeft <= 5 }
    // Text input disabled when messages gone OR session ended
    private var isTextDisabled: Bool { isSessionEnded || messagesLeft == 0 }
    // Full chat disabled (including heart) only when session truly ended server-side
    private var isChatDisabled: Bool { isSessionEnded }

    var body: some View {
        ZStack(alignment: .bottom) {
            LinearGradient(
                colors: [Color(hex: "#E8F5E9"), Color(hex: "#F0FAF0"), Color(hex: "#FFFFFF")],
                startPoint: .top, endPoint: .bottom
            ).ignoresSafeArea()

            VStack(spacing: 0) {
                headerBar
                Divider().background(Color(hex: "#C8E6C9"))

                // ── Sticky session info
                VStack(spacing: 6) {
                    CountdownTimerView(secondsRemaining: secondsRemaining)
                    MessagesRemainingPill(
                        messagesLeft: messagesLeft,
                        messageLimit: sessionDetail?.messageLimit ?? 20
                    )
                    if showLowMessagesBanner {
                        MessagesLeftBanner(count: messagesLeft)
                    }
                }
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity)
                .background(Color(hex: "#F0FAF0"))

                Divider().background(Color(hex: "#C8E6C9"))

                ScrollViewReader { proxy in
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 0) {
                            LogoWithoutText(size: 60).padding(.top, 20).padding(.bottom, 20)
                            ForEach(messages) { msg in
                                MessageBubble(message: msg).id(msg.id)
                            }
                            Color.clear.frame(height: 90)
                        }
                    }
                    .onChange(of: messages.count) { _, _ in
                        if let last = messages.last {
                            withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                        }
                    }
                    .scrollDismissesKeyboard(.interactively)
                    .onTapGesture { inputFocused = false }
                }

                inputBar
            }
        }
        // Dim when session ended
        .overlay {
            if isSessionEnded {
                Color.black.opacity(0.2).ignoresSafeArea().transition(.opacity)
            }
        }
        // ── Decision sheet OR waiting sheet
        .overlay(alignment: .bottom) {
            if showMatchPopup {
                if hasSubmittedDecision {
                    WaitingForPartnerSheet(
                        myDecision: myDecision,
                        onBackToList: { onClose() }
                    )
                    .transition(.move(edge: .bottom))
                    .ignoresSafeArea(edges: .bottom)
                } else {
                    // User hasn't decided yet — show match/skip buttons
                    MatchDecisionSheet(
                        onMatch: {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                hasSubmittedDecision = true
                                myDecision = "yes"
                            }
                            submitDecision("yes")
                        },
                        onSkip: {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                hasSubmittedDecision = true
                                myDecision = "no"
                            }
                            submitDecision("no")
                        },
                        onDismiss: {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                showMatchPopup = false
                                if !isSessionEnded { isSessionEnded = false }
                            }
                        },
                        canDismiss: true   // always dismissible — user can go back to list
                    )
                    .transition(.move(edge: .bottom))
                    .ignoresSafeArea(edges: .bottom)
                }
            }
        }
        // Leave confirmation
        .overlay(alignment: .bottom) {
            if showLeaveConfirm {
                LeaveSessionSheet(
                    onLeave: {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { showLeaveConfirm = false }
                        matchmakingService.cancelSearch()
                        onLeaveSession()
                    },
                    onStay: {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { showLeaveConfirm = false }
                    }
                )
                .transition(.move(edge: .bottom)).ignoresSafeArea(edges: .bottom)
            }
        }
        .overlay {
            if showLeaveConfirm {
                Color.black.opacity(0.15).ignoresSafeArea().transition(.opacity)
                    .onTapGesture {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { showLeaveConfirm = false }
                    }
            }
        }
        // Tap outside match popup — only dismissible when triggered by heart button (not messages-out)
        .overlay {
            if showMatchPopup && !hasSubmittedDecision && !isChatDisabled {
                Color.black.opacity(0.15).ignoresSafeArea().transition(.opacity)
                    .onTapGesture {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                            showMatchPopup = false
                            isSessionEnded = false
                        }
                    }
            }
        }
        // ── Early match confirmation (before sending request)
        .overlay(alignment: .bottom) {
            if showEarlyMatchConfirm {
                EarlyMatchConfirmSheet(
                    onConfirm: {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                            showEarlyMatchConfirm = false
                        }
                        requestEarlyMatch()
                    },
                    onCancel: {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                            showEarlyMatchConfirm = false
                        }
                    }
                )
                .transition(.move(edge: .bottom))
                .ignoresSafeArea(edges: .bottom)
            }
        }
        .overlay {
            if showEarlyMatchConfirm {
                Color.black.opacity(0.2).ignoresSafeArea().transition(.opacity)
                    .onTapGesture {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                            showEarlyMatchConfirm = false
                        }
                    }
            }
        }
        // ── Partner requested early match
        .overlay(alignment: .bottom) {
            if showPartnerRequestPopup {
                PartnerRequestSheet(
                    onAccept: {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                            showPartnerRequestPopup = false
                        }
                        respondToPartnerRequest(accept: true)
                    },
                    onDeclineAndContinue: {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                            showPartnerRequestPopup = false
                        }
                        respondToPartnerRequest(accept: false)
                    },
                    onDeclineAndEnd: {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                            showPartnerRequestPopup = false
                        }
                        respondToPartnerRequest(accept: false)
                        triggerServerSessionEnd()
                    }
                )
                .transition(.move(edge: .bottom))
                .ignoresSafeArea(edges: .bottom)
            }
        }
        .overlay {
            if showPartnerRequestPopup {
                Color.black.opacity(0.2).ignoresSafeArea().transition(.opacity)
            }
        }
        // ── Both matched — celebration
        .overlay {
            if showMatchedCelebration {
                MatchedCelebrationOverlay(onContinue: { onClose() })
                    .transition(.opacity)
                    .ignoresSafeArea()
            }
        }
        .navigationBarHidden(true)
        .onDisappear { timerTask?.cancel() }
        .task { await loadSession() }
        .onChange(of: scenePhase) { phase in
            guard phase == .active, !expiresAt.isEmpty else { return }
            let f = ISO8601DateFormatter()
            f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let expiry = f.date(from: expiresAt) {
                let remaining = max(0, Int(expiry.timeIntervalSinceNow))
                secondsRemaining = remaining
                if remaining == 0 { triggerSessionEnd() }
            }
            if hasSubmittedDecision && !showMatchPopup {
                showMatchPopup = true
            }
        }
        .onChange(of: socketService.lastSpeedDatingMessage) { event in
            guard let event, event.sessionId == matchId else { return }
            guard !messages.contains(where: { $0.id == event.messageId }) else {
                socketService.lastSpeedDatingMessage = nil
                return
            }
            let incoming = ChatMessage(
                id:           event.messageId,
                text:         event.content,
                isMine:       false,
                time:         formatTime(event.createdAt),
                messagesLeft: nil
            )
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                messages.append(incoming)
            }
            socketService.lastSpeedDatingMessage = nil
        }
        .onChange(of: socketService.lastSpeedDatingSessionEnded) { sessionId in
            guard let sessionId, sessionId == matchId else { return }
            triggerServerSessionEnd()
            socketService.lastSpeedDatingSessionEnded = nil
        }
        // Partner tapped heart — wants to match early
        .onChange(of: socketService.lastMoveToPermanentRequested) { event in
            guard let event, event.sessionId == matchId else { return }
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                showPartnerRequestPopup = true
            }
            socketService.lastMoveToPermanentRequested = nil
        }
        // Partner submitted final decision (yes/no) after session ends
        .onChange(of: socketService.lastFinalDecisionUpdated) { event in
            guard let event, event.sessionId == matchId else { return }
            print("🗳️ [Chat] Partner decided: \(event.decision)")
            socketService.lastFinalDecisionUpdated = nil
            // No UI change needed — we wait for move_to_permanent_updated if both yes
        }
        // Both said yes — matched!
        .onChange(of: socketService.lastMoveToPermanentUpdated) { event in
            guard let event, event.sessionId == matchId else { return }
            matchedPermanentMatchId = event.matchId
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                showMatchPopup        = false
                showMatchedCelebration = true
            }
            socketService.lastMoveToPermanentUpdated = nil
        }
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack(spacing: 12) {
            Button { showLeaveConfirm = true } label: {
                Image(systemName: "xmark").font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color(hex: "#1A8C4E")).frame(width: 36, height: 36)
            }
            Circle().fill(Color(hex: "#C8E6C9")).frame(width: 44, height: 44)
                .overlay(Image(systemName: "person.fill").font(.system(size: 20)).foregroundStyle(Color(hex: "#1A8C4E").opacity(0.5)))
                .overlay(Circle().strokeBorder(Color(hex: "#A5D6A7"), lineWidth: 1.5))
            Text(counterpartLabel).font(.system(size: 18, weight: .bold)).foregroundStyle(Color(hex: "#1A3A1A"))
            Spacer()
            Button {} label: {
                Image(systemName: "ellipsis").font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color(hex: "#1A8C4E")).rotationEffect(.degrees(90))
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 12).background(Color(hex: "#F0FAF0"))
    }

    private var inputBar: some View {
        HStack(spacing: 10) {
            // ❤️ Heart — shows confirmation first, then sends request
            Button {
                if isSessionEnded {
                    triggerSessionEnd()
                } else {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        showEarlyMatchConfirm = true
                    }
                }
            } label: {
                Image(systemName: "heart.fill").font(.system(size: 17, weight: .bold)).foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(LinearGradient(
                        colors: [Color(hex: "#22A855"), Color(hex: "#1A8C4E")],
                        startPoint: .topLeading, endPoint: .bottomTrailing))
                        .shadow(color: Color(hex: "#1A8C4E").opacity(0.4), radius: 8, x: 0, y: 3))
            }
            .disabled(isChatDisabled).opacity(isChatDisabled ? 0.4 : 1)

            // Text field — disabled when out of messages OR session ended
            TextField(messagesLeft > 0 ? "Your message" : "No messages left",
                      text: $messageText, axis: .vertical)
                .font(.system(size: 15)).foregroundStyle(Color(hex: "#1A3A1A"))
                .lineLimit(1...4).focused($inputFocused).disabled(isTextDisabled)
                .padding(.horizontal, 16).padding(.vertical, 12)
                .background(RoundedRectangle(cornerRadius: 24).fill(.white)
                    .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 2))

            if !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isTextDisabled {
                Button { sendMessage() } label: {
                    if isSending {
                        ProgressView().tint(.white).frame(width: 40, height: 40)
                            .background(Circle().fill(Color(hex: "#1A8C4E")))
                    } else {
                        Image(systemName: "arrow.up").font(.system(size: 15, weight: .bold)).foregroundStyle(.white)
                            .frame(width: 40, height: 40).background(Circle().fill(Color(hex: "#1A8C4E")))
                    }
                }
                .disabled(isSending).transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 10).background(Color(hex: "#E8F5E9"))
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: messageText.isEmpty)
    }

    // MARK: - Load Session + History

    private func loadSession() async {
        guard let user  = Auth.auth().currentUser,
              let token = try? await user.getIDToken() else { return }

        do {
            let result = try await apiClient.getSpeedDatingSession(token: token, sessionId: matchId)
            if let s = result.session {
                sessionDetail     = s
                expiresAt         = s.expiresAt
                counterpartLabel  = s.counterpart.initials
                counterpartUserId = s.counterpart.userId
                messagesLeft      = s.messageLimit - s.myMessageCount

                // Restore decision state if user left and came back
                let decision = s.moveToPermanent.myDecision
                if decision == "yes" || decision == "no" {
                    hasSubmittedDecision = true
                    myDecision           = decision
                }

                let formatter = ISO8601DateFormatter()
                formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                if let expiry = formatter.date(from: s.expiresAt) {
                    secondsRemaining = max(0, Int(expiry.timeIntervalSinceNow))
                } else {
                    secondsRemaining = s.remainingSeconds
                }

                if hasSubmittedDecision {
                    // Already decided — show waiting screen, lock chat
                    isSessionEnded = true
                    showMatchPopup = true
                } else if s.status != "active" || secondsRemaining == 0 {
                    // Server ended session — lock everything
                    isSessionEnded = true
                    showMatchPopup = true
                } else if messagesLeft == 0 {
                    // My messages gone but session still active — show popup, heart still works
                    showMatchPopup = true
                }

                print("✅ [Chat] Session — \(messagesLeft) msgs left, \(secondsRemaining)s, decision: \(decision)")
            }
        } catch { print("❌ [Chat] loadSession: \(error)") }

        do {
            let history = try await apiClient.getSpeedDatingMessages(token: token, sessionId: matchId)
            messages = history.map { item in
                ChatMessage(
                    id:           item.messageId,
                    text:         item.content,
                    isMine:       item.senderId != counterpartUserId,
                    time:         formatTime(item.createdAt),
                    messagesLeft: nil
                )
            }
        } catch { print("❌ [Chat] loadHistory: \(error)") }

        // Only start countdown if session is still going
        if !isSessionEnded {
            startCountdown()
        }
    }

    // MARK: - Send

    private func sendMessage() {
        let trimmed = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, messagesLeft > 0, !isSending else { return }

        messagesLeft -= 1
        let optimistic = ChatMessage.optimistic(text: trimmed, time: formatTime(nil), messagesLeft: messagesLeft)
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { messages.append(optimistic) }
        messageText = ""
        isSending   = true

        Task {
            guard let user  = Auth.auth().currentUser,
                  let token = try? await user.getIDToken() else { isSending = false; return }
            do {
                let result = try await apiClient.sendSpeedDatingMessage(
                    token: token, sessionId: matchId, content: trimmed)
                if let idx = messages.firstIndex(where: { $0.id == optimistic.id }) {
                    messages[idx] = ChatMessage(
                        id: result.messageId, text: result.content,
                        isMine: true, time: formatTime(result.createdAt), messagesLeft: messagesLeft)
                }
            } catch {
                messages.removeAll { $0.id == optimistic.id }
                messagesLeft += 1
                messageText   = trimmed
                print("❌ [Chat] send failed: \(error)")
            }
            isSending = false
            // Out of messages → must show decision popup (non-dismissible)
            if messagesLeft == 0 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { triggerSessionEnd() }
            }
        }
    }

    // MARK: - Request Early Match (heart button during active session)

    private func requestEarlyMatch() {
        Task {
            guard let user  = Auth.auth().currentUser,
                  let token = try? await user.getIDToken() else { return }
            do {
                try await apiClient.requestMoveToPermanent(token: token, sessionId: matchId)
                print("✅ [EarlyMatch] Request sent")
            } catch {
                print("❌ [EarlyMatch] Request failed: \(error)")
            }
        }
    }

    // MARK: - Respond to Partner Early Match Request

    private func respondToPartnerRequest(accept: Bool) {
        Task {
            guard let user  = Auth.auth().currentUser,
                  let token = try? await user.getIDToken() else { return }
            do {
                try await apiClient.respondMoveToPermanent(token: token, sessionId: matchId, accept: accept)
                print("✅ [EarlyMatch] Responded: \(accept ? "yes" : "no")")
            } catch {
                print("❌ [EarlyMatch] Respond failed: \(error)")
            }
        }
    }

    // MARK: - Submit Final Decision

    private func submitDecision(_ decision: String) {
        Task {
            guard let user  = Auth.auth().currentUser,
                  let token = try? await user.getIDToken() else { return }
            do {
                try await apiClient.submitFinalDecision(token: token, sessionId: matchId, decision: decision)
                print("✅ [Decision] Submitted: \(decision)")
            } catch {
                print("❌ [Decision] Failed: \(error)")
                // Even on error keep waiting state — don't close
            }
            // Do NOT call onClose() here — stay on screen waiting for partner
        }
    }

    // MARK: - Countdown

    private func startCountdown() {
        timerTask?.cancel()
        timerTask = Task {
            while secondsRemaining > 0 {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    secondsRemaining -= 1
                    if secondsRemaining == 0 { triggerServerSessionEnd() }
                }
            }
        }
    }

    private func triggerSessionEnd() {
        guard !showMatchPopup else { return }   // already showing popup
        // Only fully lock the chat when server says session is over
        // When just out of messages, keep session visually open but show popup
        if isSessionEnded {
            showMatchPopup = true
            return
        }
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) { showMatchPopup = true }
    }

    private func triggerServerSessionEnd() {
        // Called when timer = 0 or server emits session.ended — fully locks everything
        guard !isSessionEnded else { return }
        timerTask?.cancel()
        withAnimation(.easeInOut(duration: 0.4)) { isSessionEnded = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) { showMatchPopup = true }
        }
    }

    private func formatTime(_ iso: String?) -> String {
        let f = DateFormatter(); f.dateFormat = "h:mm a"
        if let iso, !iso.isEmpty {
            let f2 = ISO8601DateFormatter()
            f2.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = f2.date(from: iso) { return f.string(from: date) }
            if let date = ISO8601DateFormatter().date(from: iso) { return f.string(from: date) }
        }
        return f.string(from: Date())
    }
}

// MARK: - Message Bubble

private struct MessageBubble: View {
    let message: ChatMessage
    var body: some View {
        HStack {
            if message.isMine { Spacer(minLength: 60) }
            VStack(alignment: message.isMine ? .trailing : .leading, spacing: 4) {
                Text(message.text).font(.system(size: 15)).foregroundStyle(Color(hex: "#1A3A1A"))
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .background(RoundedRectangle(cornerRadius: 18)
                        .fill(message.isMine ? Color(hex: "#DAFFC2") : Color(hex: "#D6E8D6")))
                HStack(spacing: 4) {
                    if let left = message.messagesLeft {
                        Text("(\(left) left)").font(.system(size: 11))
                            .foregroundStyle(left <= 5 ? Color.red.opacity(0.8) : Color(hex: "#5A8A5A").opacity(0.7))
                    }
                    Text(message.time).font(.system(size: 11)).foregroundStyle(Color(hex: "#5A8A5A").opacity(0.7))
                }
            }
            if !message.isMine { Spacer(minLength: 60) }
        }
        .padding(.horizontal, 14).padding(.vertical, 4)
    }
}

// MARK: - Match Decision Sheet

private struct MatchDecisionSheet: View {
    var onMatch: () -> Void
    var onSkip: () -> Void
    var onDismiss: () -> Void
    var canDismiss: Bool    // false when messages ran out — must decide

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                RoundedRectangle(cornerRadius: 3).fill(Color(hex: "#C8E6C9")).frame(width: 36, height: 4)
                if canDismiss {
                    HStack {
                        Spacer()
                        Button { onDismiss() } label: {
                            Image(systemName: "xmark").font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Color(hex: "#9E9E9E"))
                                .frame(width: 28, height: 28).background(Circle().fill(Color(hex: "#F0F0F0")))
                        }.padding(.trailing, 20)
                    }
                }
            }.padding(.top, 12).padding(.bottom, 20)

            LogoWithoutText(size: 44).padding(.bottom, 14)
            Text("Session's over! 🎉").font(.system(size: 20, weight: .black))
                .foregroundStyle(Color(hex: "#1A3A1A")).padding(.bottom, 6)
            Text("Did you vibe with this person?\nLet them know before they disappear.")
                .font(.system(size: 14)).foregroundStyle(Color(hex: "#5A8A5A"))
                .multilineTextAlignment(.center).lineSpacing(4).padding(.horizontal, 32).padding(.bottom, 28)

            HStack(spacing: 16) {
                Button(action: onSkip) {
                    VStack(spacing: 6) {
                        ZStack {
                            Circle().fill(Color(hex: "#F5F5F5"))
                                .overlay(Circle().strokeBorder(Color(hex: "#E0E0E0"), lineWidth: 1.5))
                                .frame(width: 64, height: 64)
                            Image(systemName: "xmark").font(.system(size: 22, weight: .bold))
                                .foregroundStyle(Color(hex: "#9E9E9E"))
                        }
                        Text("nah").font(.system(size: 12, weight: .semibold)).foregroundStyle(Color(hex: "#9E9E9E"))
                    }
                }.buttonStyle(ScaleButtonStyle())

                Button(action: onMatch) {
                    VStack(spacing: 6) {
                        ZStack {
                            Circle().fill(LinearGradient(
                                colors: [Color(hex: "#22A855"), Color(hex: "#1A8C4E")],
                                startPoint: .topLeading, endPoint: .bottomTrailing))
                                .overlay(Circle().strokeBorder(Color(hex: "#1A8C4E").opacity(0.3), lineWidth: 1.5))
                                .frame(width: 64, height: 64)
                                .shadow(color: Color(hex: "#1A8C4E").opacity(0.4), radius: 12, x: 0, y: 4)
                            Image(systemName: "checkmark").font(.system(size: 22, weight: .bold)).foregroundStyle(.white)
                        }
                        Text("match!").font(.system(size: 12, weight: .bold)).foregroundStyle(Color(hex: "#1A8C4E"))
                    }
                }.buttonStyle(ScaleButtonStyle())
            }.padding(.bottom, 48)
        }
        .frame(maxWidth: .infinity)
        .background(Color.white.ignoresSafeArea(edges: .bottom)
            .shadow(color: .black.opacity(0.12), radius: 24, x: 0, y: -8))
    }
}

// MARK: - Waiting For Partner Sheet

private struct WaitingForPartnerSheet: View {
    let myDecision: String
    var onBackToList: () -> Void
    @State private var dotScale: [CGFloat] = [1, 1, 1]

    private var decidedYes: Bool { myDecision == "yes" }

    var body: some View {
        VStack(spacing: 0) {

            RoundedRectangle(cornerRadius: 3).fill(Color(hex: "#C8E6C9"))
                .frame(width: 36, height: 4).padding(.top, 12).padding(.bottom, 24)

            ZStack {
                Circle()
                    .fill(decidedYes
                          ? LinearGradient(colors: [Color(hex: "#22A855"), Color(hex: "#1A8C4E")], startPoint: .topLeading, endPoint: .bottomTrailing)
                          : LinearGradient(colors: [Color(hex: "#E0E0E0"), Color(hex: "#BDBDBD")], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 72, height: 72)
                    .shadow(color: decidedYes ? Color(hex: "#1A8C4E").opacity(0.3) : .clear, radius: 12, x: 0, y: 4)
                Image(systemName: decidedYes ? "heart.fill" : "xmark")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.white)
            }
            .padding(.bottom, 20)

            Text(decidedYes ? "You said yes! 💚" : "You passed on this one")
                .font(.system(size: 20, weight: .black))
                .foregroundStyle(Color(hex: "#1A3A1A"))
                .padding(.bottom, 8)

            Text("Waiting for their decision...")
                .font(.system(size: 14))
                .foregroundStyle(Color(hex: "#5A8A5A"))
                .padding(.bottom, 24)

            HStack(spacing: 8) {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(Color(hex: "#1A8C4E"))
                        .frame(width: 10, height: 10)
                        .scaleEffect(dotScale[i])
                        .animation(
                            .easeInOut(duration: 0.5)
                            .repeatForever(autoreverses: true)
                            .delay(Double(i) * 0.2),
                            value: dotScale[i]
                        )
                }
            }
            .padding(.bottom, 24)

            Text(decidedYes
                 ? "If they say yes too, you'll be connected in a permanent chat 🎉"
                 : "The session has ended. Thanks for chatting!")
                .font(.system(size: 13))
                .foregroundStyle(Color(hex: "#9E9E9E"))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
                .padding(.bottom, 24)

            // Back to list button
            Button(action: onBackToList) {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 13, weight: .semibold))
                    Text("Back to chats")
                        .font(.system(size: 15, weight: .semibold))
                }
                .foregroundStyle(Color(hex: "#1A8C4E"))
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color(hex: "#1A8C4E").opacity(0.08))
                        .overlay(RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(Color(hex: "#1A8C4E").opacity(0.2), lineWidth: 1))
                )
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 48)
        }
        .frame(maxWidth: .infinity)
        .background(Color.white.ignoresSafeArea(edges: .bottom)
            .shadow(color: .black.opacity(0.12), radius: 24, x: 0, y: -8))
        .onAppear {
            for i in 0..<3 {
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.15) {
                    dotScale[i] = 1.6
                }
            }
        }
    }
}

// MARK: - Scale Button Style

private struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.scaleEffect(configuration.isPressed ? 0.93 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - Leave Session Sheet

private struct LeaveSessionSheet: View {
    var onLeave: () -> Void; var onStay: () -> Void
    var body: some View {
        VStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 3).fill(Color(hex: "#C8E6C9"))
                .frame(width: 36, height: 4).padding(.top, 12).padding(.bottom, 20)
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 36)).foregroundStyle(Color.orange).padding(.bottom, 12)
            Text("Leave this session?").font(.system(size: 20, weight: .black))
                .foregroundStyle(Color(hex: "#1A3A1A")).padding(.bottom, 6)
            Text("If you leave now, this chat will end\nand you won't be able to come back.")
                .font(.system(size: 14)).foregroundStyle(Color(hex: "#5A8A5A"))
                .multilineTextAlignment(.center).lineSpacing(4).padding(.horizontal, 32).padding(.bottom, 28)
            VStack(spacing: 10) {
                Button(action: onStay) {
                    Text("Stay in chat").font(.system(size: 16, weight: .bold)).foregroundStyle(.white)
                        .frame(maxWidth: .infinity).frame(height: 52)
                        .background(RoundedRectangle(cornerRadius: 16)
                            .fill(LinearGradient(colors: [Color(hex: "#22A855"), Color(hex: "#1A8C4E")],
                                                 startPoint: .topLeading, endPoint: .bottomTrailing))
                            .shadow(color: Color(hex: "#1A8C4E").opacity(0.35), radius: 10, x: 0, y: 4))
                }.buttonStyle(ScaleButtonStyle())
                Button(action: onLeave) {
                    Text("Yes, leave").font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.red.opacity(0.8))
                        .frame(maxWidth: .infinity).frame(height: 48)
                        .background(RoundedRectangle(cornerRadius: 14).fill(Color.red.opacity(0.06))
                            .overlay(RoundedRectangle(cornerRadius: 14)
                                .strokeBorder(Color.red.opacity(0.2), lineWidth: 1)))
                }.buttonStyle(ScaleButtonStyle())
            }.padding(.horizontal, 24).padding(.bottom, 48)
        }
        .frame(maxWidth: .infinity)
        .background(Color.white.ignoresSafeArea(edges: .bottom)
            .shadow(color: .black.opacity(0.12), radius: 24, x: 0, y: -8))
    }
}

// MARK: - Partner Request Sheet

private struct PartnerRequestSheet: View {
    var onAccept: () -> Void
    var onDeclineAndContinue: () -> Void
    var onDeclineAndEnd: () -> Void

    var body: some View {
        VStack(spacing: 0) {

            RoundedRectangle(cornerRadius: 3).fill(Color(hex: "#C8E6C9"))
                .frame(width: 36, height: 4).padding(.top, 12).padding(.bottom, 20)

            Text("💚").font(.system(size: 44)).padding(.bottom, 12)

            Text("They want to match!")
                .font(.system(size: 20, weight: .black))
                .foregroundStyle(Color(hex: "#1A3A1A")).padding(.bottom, 6)

            Text("Your chat partner sent a match request.\nDo you want to match with them?")
                .font(.system(size: 14)).foregroundStyle(Color(hex: "#5A8A5A"))
                .multilineTextAlignment(.center).lineSpacing(4)
                .padding(.horizontal, 32).padding(.bottom, 28)

            VStack(spacing: 10) {

                // Yes — accept
                Button(action: onAccept) {
                    Text("Yes, match! 💚")
                        .font(.system(size: 16, weight: .bold)).foregroundStyle(.white)
                        .frame(maxWidth: .infinity).frame(height: 52)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(LinearGradient(
                                    colors: [Color(hex: "#22A855"), Color(hex: "#1A8C4E")],
                                    startPoint: .topLeading, endPoint: .bottomTrailing))
                                .shadow(color: Color(hex: "#1A8C4E").opacity(0.35), radius: 10, x: 0, y: 4))
                }.buttonStyle(ScaleButtonStyle())

                // Not yet — decline but keep chatting
                Button(action: onDeclineAndContinue) {
                    Text("Not yet — keep chatting")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color(hex: "#1A8C4E"))
                        .frame(maxWidth: .infinity).frame(height: 48)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Color(hex: "#1A8C4E").opacity(0.06))
                                .overlay(RoundedRectangle(cornerRadius: 14)
                                    .strokeBorder(Color(hex: "#1A8C4E").opacity(0.2), lineWidth: 1)))
                }.buttonStyle(ScaleButtonStyle())

                // No — decline and end session
                Button(action: onDeclineAndEnd) {
                    Text("No thanks, end session")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.red.opacity(0.7))
                }
                .padding(.top, 4)
            }
            .padding(.horizontal, 24).padding(.bottom, 48)
        }
        .frame(maxWidth: .infinity)
        .background(Color.white.ignoresSafeArea(edges: .bottom)
            .shadow(color: .black.opacity(0.12), radius: 24, x: 0, y: -8))
    }
}

// MARK: - Matched Celebration Overlay

private struct MatchedCelebrationOverlay: View {
    var onContinue: () -> Void
    @State private var scale: CGFloat  = 0.5
    @State private var opacity: Double = 0
    @State private var heartScale: CGFloat = 1.0

    var body: some View {
        ZStack {
            Color.black.opacity(0.75).ignoresSafeArea()

            VStack(spacing: 20) {

                // Pulsing heart
                Image(systemName: "heart.fill")
                    .font(.system(size: 72))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color(hex: "#22A855"), Color(hex: "#1A8C4E")],
                            startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .scaleEffect(heartScale)
                    .onAppear {
                        withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                            heartScale = 1.15
                        }
                    }
                    .padding(.bottom, 4)

                Text("It's a Match! 🎉")
                    .font(.system(size: 32, weight: .black))
                    .foregroundStyle(.white)

                Text("You both said yes!\nYou're now connected in\na permanent chat.")
                    .font(.system(size: 16))
                    .foregroundStyle(.white.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 40)

                Button(action: onContinue) {
                    Text("Go to chat 💬")
                        .font(.system(size: 16, weight: .bold)).foregroundStyle(.white)
                        .frame(maxWidth: .infinity).frame(height: 54)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(LinearGradient(
                                    colors: [Color(hex: "#22A855"), Color(hex: "#1A8C4E")],
                                    startPoint: .topLeading, endPoint: .bottomTrailing))
                                .shadow(color: Color(hex: "#1A8C4E").opacity(0.5), radius: 12, x: 0, y: 4))
                }
                .padding(.horizontal, 40)
                .padding(.top, 10)
            }
            .scaleEffect(scale)
            .opacity(opacity)
            .onAppear {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                    scale   = 1
                    opacity = 1
                }
            }
        }
    }
}

// MARK: - Early Match Confirm Sheet

private struct EarlyMatchConfirmSheet: View {
    var onConfirm: () -> Void
    var onCancel: () -> Void

    var body: some View {
        VStack(spacing: 0) {

            // Handle
            RoundedRectangle(cornerRadius: 3).fill(Color(hex: "#C8E6C9"))
                .frame(width: 36, height: 4).padding(.top, 12).padding(.bottom, 20)

            // Icon
            Text("💚")
                .font(.system(size: 52))
                .padding(.bottom, 12)

            // Title
            Text("Match early?")
                .font(.system(size: 22, weight: .black))
                .foregroundStyle(Color(hex: "#1A3A1A"))
                .padding(.bottom, 6)

            // Subtitle
            Text("You like them that much already? 😄\nSend them a match request and see if they feel the same!")
                .font(.system(size: 14))
                .foregroundStyle(Color(hex: "#5A8A5A"))
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.horizontal, 32)
                .padding(.bottom, 28)

            VStack(spacing: 10) {

                // Confirm
                Button(action: onConfirm) {
                    HStack(spacing: 8) {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 14))
                        Text("Yes, send match request!")
                            .font(.system(size: 16, weight: .bold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(LinearGradient(
                                colors: [Color(hex: "#22A855"), Color(hex: "#1A8C4E")],
                                startPoint: .topLeading, endPoint: .bottomTrailing))
                            .shadow(color: Color(hex: "#1A8C4E").opacity(0.35), radius: 10, x: 0, y: 4)
                    )
                }
                .buttonStyle(ScaleButtonStyle())

                // Cancel
                Button(action: onCancel) {
                    Text("Not yet, keep chatting")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Color(hex: "#5A8A5A"))
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                }
                .buttonStyle(ScaleButtonStyle())
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 48)
        }
        .frame(maxWidth: .infinity)
        .background(Color.white.ignoresSafeArea(edges: .bottom)
            .shadow(color: .black.opacity(0.12), radius: 24, x: 0, y: -8))
    }
}
