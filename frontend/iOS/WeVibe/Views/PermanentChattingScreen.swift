import SwiftUI

// MARK: - Permanent Chat View
// Normal persistent chat between two matched users.
// No timer, no message limit, no match/skip decision.

struct PermanentChatView: View {

    let matchId: String
    let matchName: String
    var onBack: (() -> Void)? = nil    // ← optional back handler

    @Environment(ChatRouter.self) private var chatRouter
    @State private var messageText: String = ""
    @FocusState private var inputFocused: Bool

    // Replace with real API messages
    @State private var messages: [PermanentMessage] = [
        PermanentMessage(text: "Hey! Great to finally match 😊", isMine: false, time: "Yesterday"),
        PermanentMessage(text: "Same! I really enjoyed our chat", isMine: true, time: "Yesterday"),
        PermanentMessage(text: "So where are you based?", isMine: false, time: "10:21 AM"),
    ]

    var body: some View {
        ZStack(alignment: .bottom) {

            // ── Background
            AppTheme.primaryBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {

                // ── Header
                headerBar

                Divider()
                    .background(Color.white.opacity(0.08))

                // ── Messages
                ScrollViewReader { proxy in
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 0) {
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
                }

                // ── Input bar
                inputBar
            }
        }
        .navigationBarHidden(true)
        .ignoresSafeArea(.keyboard, edges: .bottom)
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack(spacing: 12) {

            // Back button
            Button {
                if let onBack { onBack() } else { chatRouter.pop() }
            } label: {
                Image(systemName: "arrow.left")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
            }

            // Avatar
            Circle()
                .fill(Color.white.opacity(0.1))
                .frame(width: 40, height: 40)
                .overlay(
                    Image(systemName: "person.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(.white.opacity(0.5))
                )
                .overlay(Circle().strokeBorder(Color.white.opacity(0.15), lineWidth: 1.5))

            // Name + online status
            VStack(alignment: .leading, spacing: 2) {
                Text(matchName)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)

                HStack(spacing: 4) {
                    Circle()
                        .fill(Color(hex: "#22A855"))
                        .frame(width: 6, height: 6)
                    Text("Online")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.5))
                }
            }

            Spacer()

            // Menu
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
                        .overlay(
                            RoundedRectangle(cornerRadius: 24)
                                .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
                        )
                )

            if !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Button { sendMessage() } label: {
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
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(AppTheme.primaryBackground)
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: messageText.isEmpty)
    }

    // MARK: - Send

    private func sendMessage() {
        let trimmed = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let newMessage = PermanentMessage(
            text: trimmed,
            isMine: true,
            time: formattedTime()
        )
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            messages.append(newMessage)
        }
        messageText = ""
    }

    private func formattedTime() -> String {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f.string(from: Date())
    }
}

// MARK: - Message Model

struct PermanentMessage: Identifiable {
    let id = UUID()
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
