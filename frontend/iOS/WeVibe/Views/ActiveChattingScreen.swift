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
    var onMatchedToPermanent: ((String) -> Void)? = nil

    @Environment(ChatRouter.self) private var chatRouter
    @Environment(MatchmakingService.self) private var matchmakingService
    @Environment(SocketService.self) private var socketService
    @Environment(ChatStore.self) private var chatStore
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

    // Pending early match request state
    @State private var hasPendingMatchRequest: Bool = false
    @State private var showDeclinedFeedback:   Bool = false
    @State private var heartPulse: CGFloat          = 1.0
    /// Mirrors mtp.canRequest from the server. Set false after sending a request (one-shot per session).
    @State private var canRequestMatch: Bool        = true

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
    // Heart disabled when chat is over OR request already used (and not in pending/session-end mode)
    private var isHeartDisabled: Bool {
        isChatDisabled || (!canRequestMatch && !hasPendingMatchRequest)
    }

    var body: some View {
        mainContent
            .socketListeners(
                matchId:          matchId,
                messages:         $messages,
                secondsRemaining: $secondsRemaining,
                showMatchPopup:   $showMatchPopup,
                showPartnerRequestPopup: $showPartnerRequestPopup,
                showMatchedCelebration:  $showMatchedCelebration,
                matchedPermanentMatchId: $matchedPermanentMatchId,
                hasSubmittedDecision:    $hasSubmittedDecision,
                socketService:    socketService,
                triggerSessionEnd: triggerSessionEnd,
                triggerServerSessionEnd: triggerServerSessionEnd,
                formatTime:       formatTime,
                clearSessionUnread: { chatStore.clearSessionUnread(sessionId: matchId) },
                hasPendingMatchRequest: $hasPendingMatchRequest,
                showDeclinedFeedback:   $showDeclinedFeedback
            )
    }

    private var mainContent: some View {
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
                        LazyVStack(spacing: 0) {
                            ForEach(messages) { msg in
                                MessageBubble(message: msg).id(msg.id)
                            }
                            Color.clear.frame(height: 90)
                        }
                        .padding(.top, 12)
                    }
                    .defaultScrollAnchor(.bottom)
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
        .overlay { sessionEndedDim }
        .overlay { matchPopupDim }
        .overlay(alignment: .bottom) { matchPopupSheet }
        .overlay { partnerRequestDim }
        .overlay(alignment: .bottom) { partnerRequestSheet }
        .overlay { matchedCelebration }
        .navigationBarHidden(true)
        .onDisappear {
            timerTask?.cancel()
            Task {
                guard let token = try? await Auth.auth().currentUser?.getIDToken() else { return }
                await chatStore.fetchSessions(token: token)
            }
        }
        .sheet(isPresented: $showLeaveConfirm) {
            LeaveSessionSheet(
                onLeave: {
                    showLeaveConfirm = false
                    matchmakingService.cancelSearch()
                    leaveAndEndSession()
                },
                onStay: { showLeaveConfirm = false }
            )
            .presentationDetents([.height(400)])
            .presentationDragIndicator(.hidden)
            .presentationBackground(.white)
        }
        .sheet(isPresented: $showEarlyMatchConfirm) {
            EarlyMatchConfirmSheet(
                onConfirm: {
                    showEarlyMatchConfirm = false
                    requestEarlyMatch()
                },
                onCancel: { showEarlyMatchConfirm = false }
            )
            .presentationDetents([.height(430)])
            .presentationDragIndicator(.hidden)
            .presentationBackground(.white)
        }
        .task { await loadSession() }
        .onChange(of: scenePhase) { _, phase in
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
        .onChange(of: showMatchedCelebration) { _, celebrating in
            if celebrating {
                hasPendingMatchRequest = false
                inputFocused = false
            }
        }
        .onChange(of: showMatchPopup) { _, showing in
            if showing { inputFocused = false }
        }
        .onChange(of: showPartnerRequestPopup) { _, showing in
            if showing { inputFocused = false }
        }
        .onChange(of: hasPendingMatchRequest) { _, pending in
            if pending {
                withAnimation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true)) {
                    heartPulse = 1.15
                }
            } else {
                withAnimation(.default) { heartPulse = 1.0 }
            }
        }
    }

    // MARK: - Overlay Views

    @ViewBuilder private var sessionEndedDim: some View {
        if isSessionEnded {
            Color.black.opacity(0.2).ignoresSafeArea().transition(.opacity)
        }
    }

    @ViewBuilder private var matchPopupDim: some View {
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

    @ViewBuilder private var matchPopupSheet: some View {
        if showMatchPopup {
            if hasSubmittedDecision {
                WaitingForPartnerSheet(myDecision: myDecision, onBackToList: { onClose() })
                    .transition(.move(edge: .bottom))
                    .ignoresSafeArea(edges: .bottom)
            } else {
                MatchDecisionSheet(
                    onMatch: {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                            hasSubmittedDecision = true; myDecision = "yes"
                        }
                        submitDecision("yes")
                    },
                    onSkip: {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                            hasSubmittedDecision = true; myDecision = "no"
                        }
                        submitDecision("no")
                    },
                    onDismiss: {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                            showMatchPopup = false
                        }
                    },
                    canDismiss: true
                )
                .transition(.move(edge: .bottom))
                .ignoresSafeArea(edges: .bottom)
            }
        }
    }

    @ViewBuilder private var partnerRequestDim: some View {
        if showPartnerRequestPopup {
            Color.black.opacity(0.2).ignoresSafeArea().transition(.opacity)
                .onTapGesture {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                        showPartnerRequestPopup = false
                    }
                }
        }
    }

    @ViewBuilder private var partnerRequestSheet: some View {
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
                }
            )
            .transition(.move(edge: .bottom))
            .ignoresSafeArea(edges: .bottom)
        }
    }

    @ViewBuilder private var matchedCelebration: some View {
        if showMatchedCelebration {
            MatchedCelebrationOverlay(onContinue: {
                if let permanentMatchId = matchedPermanentMatchId,
                   let handler = onMatchedToPermanent {
                    handler(permanentMatchId)
                } else {
                    onClose()
                }
            })
            .transition(.opacity)
            .ignoresSafeArea()
        }
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack(spacing: 12) {
            Button { onClose() } label: {
                Image(systemName: "arrow.left").font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color(hex: "#1A8C4E")).frame(width: 36, height: 36)
            }
            Circle().fill(Color(hex: "#C8E6C9")).frame(width: 44, height: 44)
                .overlay(Image(systemName: "person.fill").font(.system(size: 20)).foregroundStyle(Color(hex: "#1A8C4E").opacity(0.5)))
                .overlay(Circle().strokeBorder(Color(hex: "#A5D6A7"), lineWidth: 1.5))
            Text(counterpartLabel).font(.system(size: 18, weight: .bold)).foregroundStyle(Color(hex: "#1A3A1A"))
            Spacer()
            Button {
                inputFocused = false
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    showLeaveConfirm = true
                }
            } label: {
                Image(systemName: "ellipsis").font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color(hex: "#1A8C4E")).rotationEffect(.degrees(90))
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 12).background(Color(hex: "#F0FAF0"))
    }

    private var inputBar: some View {
        VStack(spacing: 0) {
            // ── Awaiting / declined banner (non-blocking, above the text row)
            if hasPendingMatchRequest {
                HStack(spacing: 6) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color(hex: "#22A855"))
                    Text("Match request sent · Awaiting their reply...")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color(hex: "#2E7D32"))
                }
                .padding(.horizontal, 14).padding(.vertical, 6)
                .background(Capsule().fill(Color(hex: "#E8F5E9")))
                .padding(.bottom, 6)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            } else if showDeclinedFeedback {
                HStack(spacing: 6) {
                    Text("They're not ready yet — keep chatting! 💬")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color(hex: "#795548"))
                }
                .padding(.horizontal, 14).padding(.vertical, 6)
                .background(Capsule().fill(Color(hex: "#FFF8E1")))
                .padding(.bottom, 6)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            } else if !canRequestMatch {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color(hex: "#5A8A5A"))
                    Text("Match request already sent — only one per session")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color(hex: "#5A8A5A"))
                }
                .padding(.horizontal, 14).padding(.vertical, 6)
                .background(Capsule().fill(Color(hex: "#E8F5E9")))
                .padding(.bottom, 6)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            HStack(spacing: 10) {
                // ❤️ Heart — pending state suppresses re-confirm; pulses while awaiting
                Button {
                    if isSessionEnded {
                        triggerSessionEnd()
                    } else if canRequestMatch && !hasPendingMatchRequest {
                        inputFocused = false
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            showEarlyMatchConfirm = true
                        }
                    }
                } label: {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 17, weight: .bold)).foregroundStyle(.white)
                        .scaleEffect(heartPulse)
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(LinearGradient(
                            colors: hasPendingMatchRequest
                                ? [Color(hex: "#1A8C4E"), Color(hex: "#22A855")]
                                : canRequestMatch
                                    ? [Color(hex: "#22A855"), Color(hex: "#1A8C4E")]
                                    : [Color(hex: "#9E9E9E"), Color(hex: "#757575")],
                            startPoint: .topLeading, endPoint: .bottomTrailing))
                            .shadow(color: canRequestMatch ? Color(hex: "#1A8C4E").opacity(0.4) : .clear, radius: 8, x: 0, y: 3))
                }
                .disabled(isChatDisabled).opacity(isChatDisabled ? 0.4 : 1)

                // Text field — disabled when out of messages OR session ended
                TextField(
                    text: $messageText,
                    prompt: Text(messagesLeft > 0 ? "Your message" : "No messages left")
                        .foregroundStyle(Color(hex: "#1A3A1A").opacity(0.6)),
                    axis: .vertical
                ) { EmptyView() }
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
            .padding(.horizontal, 16).padding(.vertical, 10)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: messageText.isEmpty)
        }
        .background(Color(hex: "#E8F5E9"))
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: hasPendingMatchRequest)
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: showDeclinedFeedback)
    }

    // MARK: - Load Session + History

    private func loadSession() async {
        guard let user  = Auth.auth().currentUser,
              let token = try? await user.getIDToken() else { return }

        do {
            let result = try await apiClient.getSpeedDatingSession(token: token, sessionId: matchId)
            guard let s = result.session else {
                onClose()
                return
            }
            sessionDetail     = s
            expiresAt         = s.expiresAt
            counterpartLabel  = s.counterpart.initials
            counterpartUserId = s.counterpart.userId
            messagesLeft      = s.messageLimit - s.myMessageCount

            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let expiry = formatter.date(from: s.expiresAt) {
                let fromDate = max(0, Int(expiry.timeIntervalSinceNow))
                // If parsing gives 0 but server reports time remaining, trust the server
                secondsRemaining = fromDate > 0 ? fromDate : s.remainingSeconds
            } else {
                secondsRemaining = s.remainingSeconds
            }

            let mtp      = s.moveToPermanent
            let decision = mtp.myDecision

            // ── Restore UI state based on server-side moveToPermanent fields

            if s.status == "awaiting_decision" {
                // Natural decision phase (timer expired or message limit hit)
                isSessionEnded = true
                if decision == "yes" || decision == "no" {
                    // Already submitted — show waiting screen
                    hasSubmittedDecision = true
                    myDecision           = decision
                    showMatchPopup       = true
                } else {
                    // Haven't decided yet — show decision sheet
                    showMatchPopup = true
                }

            } else if s.status != "active" {
                // Terminal state (ended_early, graduated, expired, archived) — lock only
                // canSubmitFinalDecision is false for these; no decision popup
                isSessionEnded = true

            } else if secondsRemaining == 0 {
                // Timer expired locally
                isSessionEnded = true
                showMatchPopup = true

            } else if mtp.canRespond {
                // Partner sent a request and we haven't responded yet — show respond popup
                showPartnerRequestPopup = true

            } else if mtp.requestStatus == "sent" {
                // We sent a request, waiting for partner — restore pending indicator
                hasPendingMatchRequest = true
            }
            canRequestMatch = mtp.canRequest
            // Note: messagesLeft == 0 alone doesn't lock — heart button stays for early match
        } catch { AppLogger.recordError(error, context: "loadSession", logger: AppLogger.chat) }

        do {
            let history = try await apiClient.getSpeedDatingMessages(token: token, sessionId: matchId)
            messages = history.map { item in
                ChatMessage(
                    id:           item.messageId,
                    text:         item.content,
                    isMine:       !item.senderId.isEmpty && item.senderId != counterpartUserId,
                    time:         formatTime(item.createdAt),
                    messagesLeft: nil
                )
            }
            // Clear unread badge — fire-and-forget, non-critical
            try? await apiClient.markSessionMessagesRead(sessionId: matchId, token: token)
            chatStore.clearSessionUnread(sessionId: matchId)
        } catch { AppLogger.recordError(error, context: "loadHistory", logger: AppLogger.chat) }

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
                // Remove optimistic placeholder; if socket already delivered the real
                // message (race), don't add a duplicate.
                messages.removeAll { $0.id == optimistic.id }
                if !messages.contains(where: { $0.id == result.messageId }) {
                    messages.append(ChatMessage(
                        id: result.messageId, text: result.content,
                        isMine: true, time: formatTime(result.createdAt), messagesLeft: messagesLeft))
                }
            } catch {
                messages.removeAll { $0.id == optimistic.id }
                messagesLeft += 1
                messageText   = trimmed
            }
            isSending = false
            // Text input auto-disables via isTextDisabled when messagesLeft == 0
            // Heart button stays active for early match request
        }
    }

    // MARK: - Request Early Match (heart button during active session)

    private func requestEarlyMatch() {
        hasPendingMatchRequest = true   // optimistic — show indicator immediately
        canRequestMatch = false         // one-shot: block further requests immediately
        Task {
            guard let user  = Auth.auth().currentUser,
                  let token = try? await user.getIDToken() else {
                hasPendingMatchRequest = false; canRequestMatch = true; return
            }
            do {
                try await apiClient.requestMoveToPermanent(token: token, sessionId: matchId)
            } catch {
                hasPendingMatchRequest = false  // revert on failure
                canRequestMatch = true
                AppLogger.recordError(error, context: "requestEarlyMatch", logger: AppLogger.chat)
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
            } catch {
                AppLogger.recordError(error, context: "respondToPartnerRequest", logger: AppLogger.chat)
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
            } catch {
                AppLogger.recordError(error, context: "submitDecision", logger: AppLogger.chat)
            }
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

    // MARK: - Leave Early

    private func leaveAndEndSession() {
        // Navigate immediately — don't block on the network call.
        onLeaveSession()
        Task {
            guard let token = try? await Auth.auth().currentUser?.getIDToken() else { return }
            try? await apiClient.endSession(sessionId: matchId, token: token)
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
        // Reload session to check if final decision is allowed (not the case for ended_early)
        Task {
            guard let token = try? await Auth.auth().currentUser?.getIDToken() else { return }
            guard let result = try? await apiClient.getSpeedDatingSession(token: token, sessionId: matchId),
                  let s = result.session else {
                // Fallback: show popup only for awaiting_decision
                return
            }
            let canDecide = s.moveToPermanent.canSubmitFinalDecision
            await MainActor.run {
                guard canDecide else { return }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) { showMatchPopup = true }
                }
            }
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
    var onLeave: () -> Void
    var onStay: () -> Void

    var body: some View {
        VStack(spacing: 0) {

            // Handle
            RoundedRectangle(cornerRadius: 3).fill(Color(hex: "#C8E6C9"))
                .frame(width: 36, height: 4).padding(.top, 12).padding(.bottom, 20)

            // Icon
            Text("⚠️")
                .font(.system(size: 52))
                .padding(.bottom, 12)

            // Title
            Text("End session early?")
                .font(.system(size: 22, weight: .black))
                .foregroundStyle(Color(hex: "#1A3A1A"))
                .padding(.bottom, 6)

            // Subtitle
            Text("Ending early forfeits your match decision. If you want to match, use the ❤️ button before leaving.")
                .font(.system(size: 14))
                .foregroundStyle(Color(hex: "#5A8A5A"))
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.horizontal, 32)
                .padding(.bottom, 28)

            VStack(spacing: 10) {

                // Primary — safe action
                Button(action: onStay) {
                    Text("Keep chatting")
                        .font(.system(size: 16, weight: .bold)).foregroundStyle(.white)
                        .frame(maxWidth: .infinity).frame(height: 52)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(LinearGradient(
                                    colors: [Color(hex: "#22A855"), Color(hex: "#1A8C4E")],
                                    startPoint: .topLeading, endPoint: .bottomTrailing))
                                .shadow(color: Color(hex: "#1A8C4E").opacity(0.35), radius: 10, x: 0, y: 4))
                }.buttonStyle(ScaleButtonStyle())

                // Destructive — plain text
                Button(action: onLeave) {
                    Text("End session")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Color.red.opacity(0.8))
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                }.buttonStyle(ScaleButtonStyle())
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 48)
        }
        .frame(maxWidth: .infinity)
        .background(Color.white)
    }
}

// MARK: - Partner Request Sheet

private struct PartnerRequestSheet: View {
    var onAccept: () -> Void
    var onDeclineAndContinue: () -> Void

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
                .padding(.bottom, 12)

            // One-shot warning
            Text("You only get one match request per session — use it wisely!")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color(hex: "#C05050"))
                .multilineTextAlignment(.center)
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
        .background(Color.white)
    }
}

// MARK: - Socket Listeners (split into small modifiers to avoid type-check timeout)

private struct MessageSocketModifier: ViewModifier {
    let matchId: String
    @Binding var messages: [ChatMessage]
    let socketService: SocketService
    let formatTime: (String?) -> String
    let clearSessionUnread: () -> Void

    func body(content: Content) -> some View {
        content.onChange(of: socketService.lastSpeedDatingMessage) {
            guard let event = socketService.lastSpeedDatingMessage,
                  event.sessionId == matchId else { return }

            guard !messages.contains(where: { $0.id == event.messageId }) else {
                socketService.lastSpeedDatingMessage = nil
                return
            }

            let msg = ChatMessage(
                id: event.messageId,
                text: event.content,
                isMine: false,
                time: formatTime(event.createdAt),
                messagesLeft: nil
            )

            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                messages.append(msg)
            }
            // User is actively viewing this chat — clear badge immediately
            clearSessionUnread()
            socketService.lastSpeedDatingMessage = nil
        }
    }
}
 

private struct SessionEndedSocketModifier: ViewModifier {
    let matchId: String
    @Binding var showMatchPopup: Bool
    @Binding var showMatchedCelebration: Bool
    @Binding var matchedPermanentMatchId: String?
    let socketService: SocketService
    let triggerServerSessionEnd: () -> Void

    func body(content: Content) -> some View {
        content.onChange(of: socketService.lastSpeedDatingSessionEnded) { _, event in
            guard let event, event.sessionId == matchId else { return }
            if event.reason == "graduated", let mId = event.matchId, matchedPermanentMatchId == nil {
                matchedPermanentMatchId = mId
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    showMatchPopup = false
                    showMatchedCelebration = true
                }
            } else {
                triggerServerSessionEnd()
            }
            socketService.lastSpeedDatingSessionEnded = nil
        }
    }
}

private struct PartnerRequestSocketModifier: ViewModifier {
    let matchId: String
    @Binding var showPartnerRequestPopup: Bool
    let socketService: SocketService

    func body(content: Content) -> some View {
        content.onChange(of: socketService.lastMoveToPermanentRequested) { _, event in
            guard let event, event.sessionId == matchId else { return }
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { showPartnerRequestPopup = true }
            socketService.lastMoveToPermanentRequested = nil
        }
    }
}

private struct PartnerRespondedSocketModifier: ViewModifier {
    let matchId: String
    @Binding var hasPendingMatchRequest: Bool
    @Binding var showDeclinedFeedback:   Bool
    let socketService: SocketService

    func body(content: Content) -> some View {
        content.onChange(of: socketService.lastMoveToPermanentResponded) { _, event in
            guard let event, event.sessionId == matchId else { return }
            // Backend only emits this event when partner declines — clear pending state
            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                hasPendingMatchRequest = false
                showDeclinedFeedback   = true
            }
            Task {
                try? await Task.sleep(for: .seconds(3))
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    showDeclinedFeedback = false
                }
            }
            socketService.lastMoveToPermanentResponded = nil
        }
    }
}

private struct FinalDecisionSocketModifier: ViewModifier {
    let matchId: String
    @Binding var showMatchPopup: Bool
    @Binding var hasSubmittedDecision: Bool
    let socketService: SocketService

    func body(content: Content) -> some View {
        content.onChange(of: socketService.lastFinalDecisionUpdated) { _, event in
            guard let event, event.sessionId == matchId else { return }
            socketService.lastFinalDecisionUpdated = nil
            if !hasSubmittedDecision && !showMatchPopup {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) { showMatchPopup = true }
            }
        }
    }
}

private struct MoveToPermanentSocketModifier: ViewModifier {
    let matchId: String
    @Binding var showMatchPopup: Bool
    @Binding var showMatchedCelebration: Bool
    @Binding var matchedPermanentMatchId: String?
    let socketService: SocketService

    func body(content: Content) -> some View {
        content.onChange(of: socketService.lastMoveToPermanentUpdated) { _, event in
            guard let event, event.sessionId == matchId else { return }
            matchedPermanentMatchId = event.matchId
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                showMatchPopup = false
                showMatchedCelebration = true
            }
            socketService.lastMoveToPermanentUpdated = nil
        }
    }
}

private extension View {
    func socketListeners(
        matchId: String,
        messages: Binding<[ChatMessage]>,
        secondsRemaining: Binding<Int>,
        showMatchPopup: Binding<Bool>,
        showPartnerRequestPopup: Binding<Bool>,
        showMatchedCelebration: Binding<Bool>,
        matchedPermanentMatchId: Binding<String?>,
        hasSubmittedDecision: Binding<Bool>,
        socketService: SocketService,
        triggerSessionEnd: @escaping () -> Void,
        triggerServerSessionEnd: @escaping () -> Void,
        formatTime: @escaping (String?) -> String,
        clearSessionUnread: @escaping () -> Void,
        hasPendingMatchRequest: Binding<Bool>,
        showDeclinedFeedback: Binding<Bool>
    ) -> some View {
        self
            .modifier(MessageSocketModifier(
                matchId: matchId, messages: messages,
                socketService: socketService, formatTime: formatTime,
                clearSessionUnread: clearSessionUnread))
            .modifier(SessionEndedSocketModifier(
                matchId: matchId, showMatchPopup: showMatchPopup,
                showMatchedCelebration: showMatchedCelebration,
                matchedPermanentMatchId: matchedPermanentMatchId,
                socketService: socketService,
                triggerServerSessionEnd: triggerServerSessionEnd))
            .modifier(PartnerRequestSocketModifier(
                matchId: matchId, showPartnerRequestPopup: showPartnerRequestPopup,
                socketService: socketService))
            .modifier(PartnerRespondedSocketModifier(
                matchId: matchId,
                hasPendingMatchRequest: hasPendingMatchRequest,
                showDeclinedFeedback: showDeclinedFeedback,
                socketService: socketService))
            .modifier(FinalDecisionSocketModifier(
                matchId: matchId, showMatchPopup: showMatchPopup,
                hasSubmittedDecision: hasSubmittedDecision,
                socketService: socketService))
            .modifier(MoveToPermanentSocketModifier(
                matchId: matchId, showMatchPopup: showMatchPopup,
                showMatchedCelebration: showMatchedCelebration,
                matchedPermanentMatchId: matchedPermanentMatchId,
                socketService: socketService))
    }
}
