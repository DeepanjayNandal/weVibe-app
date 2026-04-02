import SwiftUI

// MARK: - Message Model

struct ChatMessage: Identifiable {
    let id = UUID()
    let text: String
    let isMine: Bool
    let time: String
    let messagesLeft: Int?
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
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(isWarning ? Color.red.opacity(0.1) : Color(hex: "#1A8C4E").opacity(0.08))
                .overlay(
                    Capsule()
                        .strokeBorder(
                            isWarning ? Color.red.opacity(0.3) : Color(hex: "#1A8C4E").opacity(0.2),
                            lineWidth: 1
                        )
                )
        )
        .animation(.easeInOut(duration: 0.3), value: isWarning)
    }
}

// MARK: - Messages Left Alert Banner

private struct MessagesLeftBanner: View {
    let count: Int

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 13))
                .foregroundStyle(.red)
            Text("Only \(count) message\(count == 1 ? "" : "s") left — make them count!")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.red)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.red.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color.red.opacity(0.25), lineWidth: 1)
                )
        )
        .padding(.horizontal, 16)
        .transition(.move(edge: .top).combined(with: .opacity))
    }
}

// MARK: - Active Chat View

struct ActiveChatView: View {

    let matchId: String
    var onClose: () -> Void

    @Environment(ChatRouter.self) private var chatRouter
    @State private var messageText: String = ""
    @FocusState private var inputFocused: Bool

    // Countdown — starts at 24 hours in seconds
    @State private var secondsRemaining: Int = 86400
    @State private var timerTask: Task<Void, Never>? = nil

    @State private var messages: [ChatMessage] = [
        ChatMessage(text: "Hi Emelie!", isMine: true,  time: "3:02 PM", messagesLeft: 19),
        ChatMessage(text: "Hello 😊",   isMine: false, time: "3:10 PM", messagesLeft: nil),
        ChatMessage(text: "Are you a cats or dogs person?", isMine: true, time: "3:02 PM", messagesLeft: 18),
    ]

    @State private var messagesLeft: Int = 18


    private var showLowMessagesBanner: Bool { messagesLeft > 0 && messagesLeft <= 5 }
    private var isTimerWarning: Bool { secondsRemaining <= 600 }

    var body: some View {
        ZStack(alignment: .bottom) {
            LinearGradient(
                colors: [Color(hex: "#E8F5E9"), Color(hex: "#F0FAF0"), Color(hex: "#FFFFFF")],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {

                headerBar

                Divider().background(Color(hex: "#C8E6C9"))

                ScrollViewReader { proxy in
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 0) {

                            LogoWithoutText(size: 60)
                                .padding(.top, 20)
                                .padding(.bottom, 10)

                            CountdownTimerView(secondsRemaining: secondsRemaining)
                                .padding(.bottom, 20)

                            if showLowMessagesBanner {
                                MessagesLeftBanner(count: messagesLeft)
                                    .padding(.bottom, 12)
                            }

                            ForEach(messages) { message in
                                MessageBubble(message: message)
                                    .id(message.id)
                            }

                            Color.clear.frame(height: 90)
                        }
                    }
                    .onChange(of: messages.count) { _, _ in
                        if let last = messages.last {
                            withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                        }
                    }
                }

                inputBar
            }
        }
        .navigationBarHidden(true)
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .onAppear { startCountdown() }
        .onDisappear { timerTask?.cancel() }
    }

    // MARK: - Header Bar

    private var headerBar: some View {
        HStack(spacing: 12) {
            Button { onClose() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color(hex: "#1A8C4E"))
                    .frame(width: 36, height: 36)
            }

            Circle()
                .fill(Color(hex: "#C8E6C9"))
                .frame(width: 44, height: 44)
                .overlay(
                    Image(systemName: "person.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(Color(hex: "#1A8C4E").opacity(0.5))
                )
                .overlay(Circle().strokeBorder(Color(hex: "#A5D6A7"), lineWidth: 1.5))

            Text("Anonymous")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Color(hex: "#1A3A1A"))

            Spacer()

            Button {} label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color(hex: "#1A8C4E"))
                    .rotationEffect(.degrees(90))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(hex: "#F0FAF0"))
    }

    // MARK: - Input Bar

    private var inputBar: some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                TextField(
                    messagesLeft > 0 ? "Your message" : "No messages left",
                    text: $messageText,
                    axis: .vertical
                )
                .font(.system(size: 15))
                .foregroundStyle(Color(hex: "#1A3A1A"))
                .lineLimit(1...4)
                .focused($inputFocused)
                .disabled(messagesLeft == 0)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 24)
                        .fill(.white)
                        .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 2)
                )

                if !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && messagesLeft > 0 {
                    Button { sendMessage() } label: {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 40, height: 40)
                            .background(Circle().fill(Color(hex: "#1A8C4E")))
                    }
                    .transition(.scale.combined(with: .opacity))
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(hex: "#E8F5E9"))
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: messageText.isEmpty)
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
                }
            }
        }
    }

    // MARK: - Send

    private func sendMessage() {
        let trimmed = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, messagesLeft > 0 else { return }

        messagesLeft -= 1

        let newMessage = ChatMessage(
            text: trimmed,
            isMine: true,
            time: formattedTime(),
            messagesLeft: messagesLeft
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

// MARK: - Message Bubble

private struct MessageBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack {
            if message.isMine { Spacer(minLength: 60) }

            VStack(alignment: message.isMine ? .trailing : .leading, spacing: 4) {
                Text(message.text)
                    .font(.system(size: 15))
                    .foregroundStyle(Color(hex: "#1A3A1A"))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 18)
                            .fill(message.isMine
                                  ? Color(hex: "#DAFFC2")
                                  : Color(hex: "#D6E8D6"))
                    )

                HStack(spacing: 4) {
                    if let left = message.messagesLeft {
                        Text("(\(left) left)")
                            .font(.system(size: 11))
                            .foregroundStyle(left <= 5 ? Color.red.opacity(0.8) : Color(hex: "#5A8A5A").opacity(0.7))
                    }
                    Text(message.time)
                        .font(.system(size: 11))
                        .foregroundStyle(Color(hex: "#5A8A5A").opacity(0.7))
                }
            }

            if !message.isMine { Spacer(minLength: 60) }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 4)
    }
}
