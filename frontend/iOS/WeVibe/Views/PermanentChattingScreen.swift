import SwiftUI
import FirebaseAuth

// MARK: - Permanent Chat View

struct PermanentChatView: View {

    let matchId: String
    var onClose: () -> Void

    @Environment(ChatRouter.self) private var chatRouter
    @Environment(SocketService.self) private var socketService

    @State private var messageText: String = ""
    @FocusState private var inputFocused: Bool

    @State private var matchProfile: MatchProfile?
    @State private var showProfile = false
    private let apiClient = APIClient()

    @State private var showRemoveAlert = false
    @State private var showBlockSheet = false
    @State private var showReportSheet = false
    @State private var isRemoving = false

    // Chat state
    @State private var messages: [PermanentMessage] = []
    @State private var counterpartUserId: String = ""
    @State private var isSending = false
    @State private var isLoadingHistory = false

    var body: some View {
        ZStack(alignment: .bottom) {

            AppTheme.primaryBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {

                headerBar

                Divider()
                    .background(Color.white.opacity(0.08))

                ScrollViewReader { proxy in
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 0) {
                            if isLoadingHistory {
                                ProgressView()
                                    .tint(AppTheme.primaryButton)
                                    .padding(.top, 40)
                            }
                            ForEach(messages) { message in
                                PermanentMessageBubble(message: message)
                                    .id(message.id)
                            }
                            Color.clear.frame(height: 90)
                        }
                        .padding(.top, 12)
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
        .navigationBarHidden(true)
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .task { await loadChat() }
        .sheet(isPresented: $showProfile) {
            if let profile = matchProfile {
                OtherUserProfileView(profile: profile, onDismiss: { showProfile = false })
            }
        }
        .confirmationDialog(
            "Remove this match?",
            isPresented: $showRemoveAlert,
            titleVisibility: .visible
        ) {
            Button("Remove Match", role: .destructive) {
                Task { await performRemoveMatch() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This match will be permanently removed.")
        }
        .sheet(isPresented: $showBlockSheet) {
            BlockMatchSheet(matchId: matchId) {
                onClose()
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showReportSheet) {
            ReportMatchSheet(matchId: matchId) {
                onClose()
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        // ── REALTIME: incoming message from counterpart
        .onChange(of: socketService.lastPermanentMessage) { _, event in
            guard let event, event.matchId == matchId else { return }
            guard !messages.contains(where: { $0.id == event.messageId }) else {
                socketService.lastPermanentMessage = nil
                return
            }
            let incoming = PermanentMessage(
                id:     event.messageId,
                text:   event.content,
                isMine: false,
                time:   formatTime(event.createdAt.isEmpty ? nil : event.createdAt)
            )
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                messages.append(incoming)
            }
            socketService.lastPermanentMessage = nil
            // Mark read since the chat is open
            Task {
                guard let user  = Auth.auth().currentUser,
                      let token = try? await user.getIDToken() else { return }
                try? await apiClient.markMatchMessagesRead(matchId: matchId, token: token)
            }
        }
        // ── Match removed by counterpart
        .onChange(of: socketService.lastMatchRemovedId) { _, removedId in
            guard removedId == matchId else { return }
            socketService.lastMatchRemovedId = nil
            onClose()
        }
        // ── Match blocked by counterpart
        .onChange(of: socketService.lastMatchBlockedId) { _, blockedId in
            guard blockedId == matchId else { return }
            socketService.lastMatchBlockedId = nil
            onClose()
        }
    }

    // MARK: - Load Chat

    private func loadChat() async {
        guard let user  = Auth.auth().currentUser,
              let token = try? await user.getIDToken() else { return }

        isLoadingHistory = true

        // Load message history + counterpart ID
        do {
            let result = try await apiClient.getMatchMessages(matchId: matchId, token: token)
            counterpartUserId = result.counterpartUserId
            messages = result.messages.map { item in
                PermanentMessage(
                    id:     item.messageId,
                    text:   item.content,
                    isMine: item.senderId != counterpartUserId,
                    time:   formatTime(item.createdAt)
                )
            }
        } catch {
            print("❌ [PermanentChat] loadMessages: \(error)")
        }

        isLoadingHistory = false

        // Mark all as read now that the chat is open
        try? await apiClient.markMatchMessagesRead(matchId: matchId, token: token)

        // Load counterpart profile for the header
        matchProfile = try? await apiClient.fetchMatchProfile(token: token, matchId: matchId)
        if let profile = matchProfile, counterpartUserId.isEmpty {
            counterpartUserId = profile.id
        }
    }

    // MARK: - Remove Match

    private func performRemoveMatch() async {
        isRemoving = true
        guard let user  = Auth.auth().currentUser,
              let token = try? await user.getIDToken() else {
            isRemoving = false
            return
        }
        try? await apiClient.removeMatch(matchId: matchId, token: token)
        onClose()
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack(spacing: 12) {

            Button {
                chatRouter.pop()
            } label: {
                Image(systemName: "arrow.left")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
            }

            Button {
                if matchProfile != nil { showProfile = true }
            } label: {
                HStack(spacing: 10) {
                    Circle()
                        .fill(Color.white.opacity(0.1))
                        .frame(width: 40, height: 40)
                        .overlay(
                            Image(systemName: "person.fill")
                                .font(.system(size: 18))
                                .foregroundStyle(.white.opacity(0.5))
                        )
                        .overlay(Circle().strokeBorder(Color.white.opacity(0.15), lineWidth: 1.5))

                    VStack(alignment: .leading, spacing: 2) {
                        if let name = matchProfile?.firstName, !name.isEmpty {
                            Text(name)
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(.white)
                        }
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color(hex: "#22A855"))
                                .frame(width: 6, height: 6)
                            Text("Online")
                                .font(.system(size: 11))
                                .foregroundStyle(.white.opacity(0.5))
                        }
                    }
                }
            }
            .disabled(matchProfile == nil)

            Spacer()

            Menu {
                Button(role: .destructive) {
                    showRemoveAlert = true
                } label: {
                    Label("Remove Match", systemImage: "heart.slash")
                }
                Button(role: .destructive) {
                    showBlockSheet = true
                } label: {
                    Label("Block", systemImage: "hand.raised")
                }
                Button(role: .destructive) {
                    showReportSheet = true
                } label: {
                    Label("Report", systemImage: "flag")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.7))
                    .rotationEffect(.degrees(90))
                    .frame(width: 36, height: 36)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(AppTheme.primaryBackground)
    }

    // MARK: - Input Bar

    private var inputBar: some View {
        HStack(spacing: 10) {
            TextField("Message ...", text: $messageText, axis: .vertical)
                .font(.system(size: 15))
                .foregroundStyle(.white)
                .lineLimit(1...5)
                .focused($inputFocused)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 24)
                        .fill(Color.white.opacity(0.08))
                        .overlay(
                            RoundedRectangle(cornerRadius: 24)
                                .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
                        )
                )

            if !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Button { sendMessage() } label: {
                    if isSending {
                        ProgressView()
                            .tint(.white)
                            .frame(width: 42, height: 42)
                            .background(Circle().fill(Color(hex: "#1A8C4E")))
                    } else {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 42, height: 42)
                            .background(
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [Color(hex: "#22A855"), Color(hex: "#1A8C4E")],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .shadow(color: Color(hex: "#1A8C4E").opacity(0.4), radius: 8, x: 0, y: 3)
                            )
                    }
                }
                .disabled(isSending)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(AppTheme.primaryBackground)
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: messageText.isEmpty)
    }

    // MARK: - Send (optimistic UI)

    private func sendMessage() {
        let trimmed = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isSending else { return }

        let optimisticId = UUID().uuidString
        let optimistic = PermanentMessage(
            id:     optimisticId,
            text:   trimmed,
            isMine: true,
            time:   formatTime(nil)
        )
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            messages.append(optimistic)
        }
        messageText = ""
        isSending   = true

        Task {
            guard let user  = Auth.auth().currentUser,
                  let token = try? await user.getIDToken() else {
                isSending = false
                return
            }
            do {
                let result = try await apiClient.sendPermanentMessage(
                    matchId: matchId, content: trimmed, token: token)
                if let idx = messages.firstIndex(where: { $0.id == optimisticId }) {
                    messages[idx] = PermanentMessage(
                        id:     result.messageId,
                        text:   result.content,
                        isMine: true,
                        time:   formatTime(result.createdAt)
                    )
                }
            } catch {
                // Rollback optimistic message
                messages.removeAll { $0.id == optimisticId }
                messageText = trimmed
            }
            isSending = false
        }
    }

    // MARK: - Helpers

    private func formatTime(_ iso: String?) -> String {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        guard let iso else { return f.string(from: Date()) }
        let isoFull = ISO8601DateFormatter()
        isoFull.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = isoFull.date(from: iso) { return f.string(from: date) }
        if let date = ISO8601DateFormatter().date(from: iso) { return f.string(from: date) }
        return f.string(from: Date())
    }
}

// MARK: - Message Model

struct PermanentMessage: Identifiable {
    let id: String
    let text: String
    let isMine: Bool
    let time: String
}

// MARK: - Message Bubble

private struct PermanentMessageBubble: View {
    let message: PermanentMessage

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if message.isMine { Spacer(minLength: 60) }

            VStack(alignment: message.isMine ? .trailing : .leading, spacing: 4) {
                Text(message.text)
                    .font(.system(size: 15))
                    .foregroundStyle(message.isMine ? .white : Color(hex: "#1A3A1A"))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 18)
                            .fill(
                                message.isMine
                                    ? LinearGradient(
                                        colors: [Color(hex: "#22A855"), Color(hex: "#1A8C4E")],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                    : LinearGradient(
                                        colors: [Color.white, Color.white],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                            )
                    )

                Text(message.time)
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.35))
            }

            if !message.isMine { Spacer(minLength: 60) }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 4)
    }
}