import SwiftUI
import FirebaseAuth
import UserNotifications

// MARK: - Permanent Message Model

struct PermanentMessage: Identifiable {
    let id: String
    let text: String
    let isMine: Bool
    let time: String
}

// MARK: - Permanent Chat View

struct PermanentChatView: View {

    let matchId: String
    let matchName: String
    let counterpartUserId: String
    var photoUrl: String? = nil
    var onBack: (() -> Void)? = nil

    @Environment(ChatRouter.self)      private var chatRouter
    @Environment(SocketService.self)   private var socketService
    @Environment(ChatStore.self)       private var chatStore

    @State private var messageText: String           = ""
    @State private var messages: [PermanentMessage]  = []
    @State private var isSending: Bool               = false
    @State private var isMatchRemoved: Bool          = false
    @State private var isMatchBlocked: Bool          = false
    @State private var isCounterpartTyping: Bool     = false
    @State private var matchProfile: MatchProfile?   = nil
    @State private var showProfile: Bool             = false
    @State private var showMenu: Bool                = false
    @State private var showBlockSheet: Bool          = false
    @State private var showReportSheet: Bool         = false
    @State private var isRemovingMatch: Bool          = false
    @State private var isLoadingProfile: Bool         = false
    @State private var isLoadingMore: Bool            = false
    @State private var hasMore: Bool                  = false

    @FocusState private var inputFocused: Bool

    private var initialsCircle: some View {
        ZStack {
            Circle()
                .fill(LinearGradient(
                    colors: [Color(hex: "#1A8C4E"), Color(hex: "#0d5c32")],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ))
                .frame(width: 40, height: 40)
            Text(matchName.prefix(2).uppercased())
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white)
        }
    }

    private let apiClient = APIClient()

    var body: some View {
        ZStack(alignment: .bottom) {
            AppTheme.primaryBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                headerBar
                Divider().background(Color.white.opacity(0.08))

                ScrollViewReader { proxy in
                    ScrollView(showsIndicators: false) {
                        LazyVStack(spacing: 0) {
                            // Load-more trigger — appears when user scrolls to the top
                            if hasMore {
                                Color.clear.frame(height: 1)
                                    .onAppear {
                                        guard !isLoadingMore, !messages.isEmpty else { return }
                                        Task { await loadMoreMessages() }
                                    }
                            }
                            if isLoadingMore {
                                ProgressView()
                                    .tint(Color(hex: "#22A855"))
                                    .padding(.vertical, 12)
                            }

                            ForEach(messages) { message in
                                PermanentMessageBubble(message: message).id(message.id)
                            }

                            if isCounterpartTyping {
                                TypingBubble()
                                    .id("typing")
                                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                            }

                            Color.clear.frame(height: 90).id("bottom")
                        }
                        .padding(.top, 12)
                    }
                    .defaultScrollAnchor(.bottom)
                    .onChange(of: messages.count) { _, _ in
                        // Only auto-scroll for newly appended messages, not prepended pages
                        guard !isLoadingMore, let last = messages.last else { return }
                        withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                    }
                    .onChange(of: isCounterpartTyping) { _, typing in
                        if typing { withAnimation { proxy.scrollTo("typing", anchor: .bottom) } }
                    }
                    .scrollDismissesKeyboard(.interactively)
                    .onTapGesture { inputFocused = false }
                }

                if !isMatchRemoved && !isMatchBlocked {
                    inputBar
                } else {
                    disabledBar
                }
            }
        }
        .navigationBarHidden(true)
        .onAppear  { AppDelegate.activeMatchId = matchId }
        .onDisappear { AppDelegate.activeMatchId = nil }
        .task { await loadMessages() }
        .sheet(isPresented: $showProfile) {
            if let profile = matchProfile {
                OtherUserProfileView(profile: profile, onDismiss: { showProfile = false })
            }
        }
        .sheet(isPresented: $showBlockSheet) {
            BlockMatchSheet(matchId: matchId, onSuccess: {
                showBlockSheet = false
                if let onBack { onBack() } else { chatRouter.pop() }
            })
        }
        .sheet(isPresented: $showReportSheet) {
            ReportMatchSheet(matchId: matchId, onSuccess: { showReportSheet = false })
        }
        .sheet(isPresented: $showMenu) {
            MatchMenuSheet(
                onBlock:   { showMenu = false; showBlockSheet  = true },
                onReport:  { showMenu = false; showReportSheet = true },
                onRemove:  { showMenu = false; Task { await removeMatchAndPop() } },
                onDismiss: { showMenu = false }
            )
            .presentationDetents([.height(240)])
            .presentationBackground(Color(hex: "#111111"))
            .presentationDragIndicator(.hidden)
        }

        .onChange(of: socketService.lastPermanentMessage) { _, event in
            guard let event, event.matchId == matchId else { return }
            guard !messages.contains(where: { $0.id == event.messageId }) else {
                socketService.lastPermanentMessage = nil
                return
            }
            let msg = PermanentMessage(
                id:     event.messageId,
                text:   event.content,
                isMine: false,
                time:   formatTime(event.createdAt)
            )
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                messages.append(msg)
            }
            socketService.lastPermanentMessage = nil
        }

        .onChange(of: socketService.lastPermanentTyping) { _, event in
            guard let event, event.matchId == matchId else { return }
            withAnimation { isCounterpartTyping = event.isTyping }
            socketService.lastPermanentTyping = nil
        }

        .onChange(of: socketService.lastPermanentMatchRemoved) { _, event in
            guard let event, event.matchId == matchId else { return }
            withAnimation { isMatchRemoved = true }
            socketService.lastPermanentMatchRemoved = nil
        }

        .onChange(of: socketService.lastPermanentMatchBlocked) { _, event in
            guard let event, event.matchId == matchId else { return }
            withAnimation { isMatchBlocked = true }
            socketService.lastPermanentMatchBlocked = nil
        }
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack(spacing: 12) {
            Button {
                if let onBack { onBack() } else { chatRouter.pop() }
            } label: {
                Image(systemName: "arrow.left")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
            }


            Button {
                guard !isLoadingProfile else { return }
                isLoadingProfile = true
                Task {
                    await fetchMatchProfile()
                    isLoadingProfile = false
                }
            } label: {
                HStack(spacing: 12) {
                    Group {
                        if let photoUrl, let url = URL(string: photoUrl) {
                            AsyncImage(url: url) { phase in
                                switch phase {
                                case .success(let img):
                                    img.resizable().scaledToFill()
                                        .frame(width: 40, height: 40)
                                        .clipShape(Circle())
                                default:
                                    initialsCircle
                                }
                            }
                        } else {
                            initialsCircle
                        }
                    }
                    .overlay(Circle().strokeBorder(Color.white.opacity(0.15), lineWidth: 1.5))
                    .overlay {
                        if isLoadingProfile {
                            ProgressView().tint(.white).scaleEffect(0.55)
                        }
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(matchName)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                        if !isMatchRemoved && !isMatchBlocked {
                            if isCounterpartTyping {
                                Text("typing...")
                                    .font(.system(size: 11))
                                    .foregroundStyle(Color(hex: "#22A855"))
                                    .transition(.opacity)
                            } else {
                                HStack(spacing: 4) {
                                    Circle().fill(Color(hex: "#22A855")).frame(width: 6, height: 6)
                                    Text("Online").font(.system(size: 11)).foregroundStyle(.white.opacity(0.5))
                                }
                            }
                        }
                    }
                    .animation(.easeInOut(duration: 0.2), value: isCounterpartTyping)
                }
            }
            .buttonStyle(.plain)

            Spacer()

            if !isMatchRemoved && !isMatchBlocked {
                Button { showMenu = true } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.7))
                        .rotationEffect(.degrees(90))
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(AppTheme.primaryBackground)
    }

    // MARK: - Input Bar

    private var inputBar: some View {
        HStack(spacing: 10) {
            TextField("Message \(matchName)...", text: $messageText, axis: .vertical)
                .font(.system(size: 15))
                .foregroundStyle(.white)
                .lineLimit(1...5)
                .focused($inputFocused)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 24)
                        .fill(Color.white.opacity(0.08))
                        .overlay(RoundedRectangle(cornerRadius: 24)
                            .strokeBorder(Color.white.opacity(0.12), lineWidth: 1))
                )
                .onChange(of: messageText) { _, _ in
                    socketService.emitTyping(chatType: "permanent", chatId: matchId,
                                             isTyping: !messageText.isEmpty)
                }

            if !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Button { sendMessage() } label: {
                    if isSending {
                        ProgressView().tint(.white).frame(width: 42, height: 42)
                            .background(Circle().fill(Color(hex: "#1A8C4E")))
                    } else {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 42, height: 42)
                            .background(Circle().fill(LinearGradient(
                                colors: [Color(hex: "#22A855"), Color(hex: "#1A8C4E")],
                                startPoint: .topLeading, endPoint: .bottomTrailing))
                                .shadow(color: Color(hex: "#1A8C4E").opacity(0.4), radius: 8, x: 0, y: 3))
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


    private var disabledBar: some View {
        Text(isMatchBlocked ? "You've been blocked" : "This match has been removed")
            .font(.system(size: 13))
            .foregroundStyle(.white.opacity(0.4))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(AppTheme.primaryBackground)
    }




    private func loadMessages() async {
        guard let user  = Auth.auth().currentUser,
              let token = try? await user.getIDToken() else { return }
        do {
            let detail = try await apiClient.getMatch(matchId: matchId, token: token)
            if !detail.isActive {
                withAnimation { isMatchRemoved = true }
                // Don't return — still load message history so old messages are visible
            }

            let result = try await apiClient.getMatchMessages(matchId: matchId, token: token, limit: 30)

            messages = result.messages.map { item in
                let isMine = !item.senderId.isEmpty && item.senderId != counterpartUserId
                return PermanentMessage(
                    id:     item.messageId,
                    text:   item.content,
                    isMine: isMine,
                    time:   formatTime(item.createdAt)
                )
            }
            hasMore = result.hasMore

            try? await apiClient.markMatchMessagesRead(matchId: matchId, token: token)
            chatStore.clearUnread(matchId: matchId)
            clearMatchNotifications()
        } catch {
            AppLogger.recordError(error, context: "loadMessages", logger: AppLogger.permanentChat)
        }
    }

    private func loadMoreMessages() async {
        guard hasMore, !isLoadingMore, let cursor = messages.first?.id else { return }
        guard let user  = Auth.auth().currentUser,
              let token = try? await user.getIDToken() else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }
        do {
            let result = try await apiClient.getMatchMessages(
                matchId: matchId, token: token, before: cursor, limit: 30)
            let older = result.messages.map { item in
                let isMine = !item.senderId.isEmpty && item.senderId != counterpartUserId
                return PermanentMessage(
                    id:     item.messageId,
                    text:   item.content,
                    isMine: isMine,
                    time:   formatTime(item.createdAt)
                )
            }
            messages = older + messages
            hasMore = result.hasMore
        } catch {
            AppLogger.recordError(error, context: "loadMoreMessages", logger: AppLogger.permanentChat)
        }
    }

    private func clearMatchNotifications() {
        let threadId = "match_\(matchId)"
        UNUserNotificationCenter.current().getDeliveredNotifications { notifications in
            let ids = notifications
                .filter { $0.request.content.threadIdentifier == threadId }
                .map    { $0.request.identifier }
            UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: ids)
        }
    }

    // MARK: - Profile

    private func fetchMatchProfile() async {
        guard let user  = Auth.auth().currentUser,
              let token = try? await user.getIDToken() else { return }
        do {
            let profile = try await apiClient.fetchMatchProfile(token: token, matchId: matchId)
            matchProfile = profile
            showProfile  = true
        } catch {
            AppLogger.recordError(error, context: "fetchMatchProfile", logger: AppLogger.permanentChat)
        }
    }

    // MARK: - Remove Match

    private func removeMatchAndPop() async {
        guard !isRemovingMatch else { return }
        isRemovingMatch = true
        guard let user  = Auth.auth().currentUser,
              let token = try? await user.getIDToken() else { isRemovingMatch = false; return }
        do {
            try await apiClient.removeMatch(matchId: matchId, token: token)
            chatStore.removeMatch(matchId: matchId)
            if let onBack { onBack() } else { chatRouter.pop() }
        } catch {
            AppLogger.recordError(error, context: "removeMatch", logger: AppLogger.permanentChat)
        }
        isRemovingMatch = false
    }

    // MARK: - Send

    private func sendMessage() {
        let trimmed = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isSending else { return }

        socketService.emitTyping(chatType: "permanent", chatId: matchId, isTyping: false)

        let optimisticId = UUID().uuidString
        let optimistic   = PermanentMessage(id: optimisticId, text: trimmed, isMine: true,
                                             time: formatTime(nil))
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { messages.append(optimistic) }
        messageText = ""
        isSending   = true

        Task {
            guard let user  = Auth.auth().currentUser,
                  let token = try? await user.getIDToken() else { isSending = false; return }
            do {
                let result = try await apiClient.sendPermanentMessage(
                    matchId: matchId, content: trimmed, token: token)
                if let idx = messages.firstIndex(where: { $0.id == optimisticId }) {
                    messages[idx] = PermanentMessage(
                        id: result.messageId, text: result.content,
                        isMine: true, time: formatTime(result.createdAt))
                }
            } catch {
                messages.removeAll { $0.id == optimisticId }
                messageText = trimmed
                AppLogger.recordError(error, context: "sendMessage", logger: AppLogger.permanentChat)
            }
            isSending = false
        }
    }

    private func formatTime(_ iso: String?) -> String {
        let f = DateFormatter(); f.dateFormat = "h:mm a"
        if let iso, !iso.isEmpty {
            let f2 = ISO8601DateFormatter()
            f2.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = f2.date(from: iso) ?? ISO8601DateFormatter().date(from: iso) {
                return f.string(from: date)
            }
        }
        return f.string(from: Date())
    }
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
                            .fill(message.isMine
                                  ? LinearGradient(colors: [Color(hex: "#22A855"), Color(hex: "#1A8C4E")],
                                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                                  : LinearGradient(colors: [.white, .white],
                                                   startPoint: .top, endPoint: .bottom))
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


private struct TypingBubble: View {
    @State private var activeIndex = 0
    private let timer = Timer.publish(every: 0.4, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(alignment: .bottom) {
            HStack(spacing: 5) {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(Color.gray.opacity(activeIndex == i ? 0.8 : 0.3))
                        .frame(width: 8, height: 8)
                        .scaleEffect(activeIndex == i ? 1.2 : 1.0)
                        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: activeIndex)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(RoundedRectangle(cornerRadius: 18).fill(Color.white))
            Spacer(minLength: 60)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 4)
        .onReceive(timer) { _ in activeIndex = (activeIndex + 1) % 3 }
    }
}
