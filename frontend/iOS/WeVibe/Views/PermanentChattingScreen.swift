import SwiftUI
import FirebaseAuth

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
    var onBack: (() -> Void)? = nil

    @Environment(ChatRouter.self)      private var chatRouter
    @Environment(SocketService.self)   private var socketService

    @State private var messageText: String        = ""
    @State private var messages: [PermanentMessage] = []
    @State private var isSending: Bool            = false
    @State private var isMatchRemoved: Bool       = false
    @State private var isMatchBlocked: Bool       = false
    @State private var isCounterpartTyping: Bool  = false

    @FocusState private var inputFocused: Bool

    private let apiClient = APIClient()

    var body: some View {
        ZStack(alignment: .bottom) {
            AppTheme.primaryBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                headerBar
                Divider().background(Color.white.opacity(0.08))

                ScrollViewReader { proxy in
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 0) {
                            ForEach(messages) { message in
                                PermanentMessageBubble(message: message).id(message.id)
                            }
                            // Typing indicator
                            if isCounterpartTyping {
                                TypingBubble()
                                    .id("typing")
                                    .transition(.opacity.combined(with: .move(edge: .bottom)))
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
        .overlay { removedOverlay }
        .navigationBarHidden(true)
        .task { await loadMessages() }

        .onChange(of: socketService.lastPermanentMessage) { event in
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

        .onChange(of: socketService.lastPermanentTyping) { event in
            guard let event, event.matchId == matchId else { return }
            withAnimation { isCounterpartTyping = event.isTyping }
            socketService.lastPermanentTyping = nil
        }

        .onChange(of: socketService.lastPermanentMatchRemoved) { event in
            guard let event, event.matchId == matchId else { return }
            withAnimation { isMatchRemoved = true }
            socketService.lastPermanentMatchRemoved = nil
        }

        .onChange(of: socketService.lastPermanentMatchBlocked) { event in
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
            .overlay(Circle().strokeBorder(Color.white.opacity(0.15), lineWidth: 1.5))

            VStack(alignment: .leading, spacing: 2) {
                Text(matchName)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
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
            .animation(.easeInOut(duration: 0.2), value: isCounterpartTyping)

            Spacer()

            Button {} label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.7))
                    .rotationEffect(.degrees(90))
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


    @ViewBuilder private var removedOverlay: some View {
        if isMatchRemoved || isMatchBlocked {
            VStack {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: isMatchBlocked ? "hand.raised.fill" : "trash.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(.white.opacity(0.4))
                    Text(isMatchBlocked ? "You've been blocked" : "Match removed")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.6))
                    Text("You can no longer send messages")
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.35))
                }
                .padding(24)
                .background(RoundedRectangle(cornerRadius: 20).fill(Color.white.opacity(0.05)))
                .padding(.horizontal, 40)
                .padding(.bottom, 120)
            }
            .transition(.opacity)
        }
    }


    private func loadMessages() async {
        guard let user  = Auth.auth().currentUser,
              let token = try? await user.getIDToken() else { return }
        do {
            let detail = try await apiClient.getMatch(matchId: matchId, token: token)
            if !detail.isActive {
                withAnimation { isMatchRemoved = true }
                return
            }

            let history = try await apiClient.getPermanentMessages(token: token, matchId: matchId)

            messages = history.map { item in
 
                let isMine = !item.senderId.isEmpty && item.senderId != counterpartUserId
                return PermanentMessage(
                    id:     item.messageId,
                    text:   item.content,
                    isMine: isMine,
                    time:   formatTime(item.createdAt)
                )
            }
        } catch {
            print("❌ [Permanent] loadMessages: \(error)")
        }
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
                    token: token, matchId: matchId, content: trimmed)
                if let idx = messages.firstIndex(where: { $0.id == optimisticId }) {
                    messages[idx] = PermanentMessage(
                        id: result.messageId, text: result.content,
                        isMine: true, time: formatTime(result.createdAt))
                }
            } catch {
                messages.removeAll { $0.id == optimisticId }
                messageText = trimmed
                print("❌ [Permanent] send failed: \(error)")
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
