import SwiftUI

// MARK: - Message Model (placeholder until API)

struct ChatMessage: Identifiable {
    let id = UUID()
    let text: String
    let isMine: Bool
    let time: String
    let messagesLeft: Int?
}

// MARK: - Active Chat View

struct ActiveChatView: View {

    let matchId: String
    var onClose: () -> Void

    @Environment(ChatRouter.self) private var chatRouter
    @State private var messageText: String = ""
    @FocusState private var inputFocused: Bool


    @State private var messages: [ChatMessage] = [
        ChatMessage(text: "Hi Emelie!", isMine: true,  time: "3:02 PM", messagesLeft: 19),
        ChatMessage(text: "Hello 😊",   isMine: false, time: "3:10 PM", messagesLeft: nil),
        ChatMessage(text: "Are you a cats or dogs person?", isMine: true, time: "3:02 PM", messagesLeft: 18),
    ]


    @State private var messagesLeft: Int = 18

    var body: some View {
        ZStack(alignment: .bottom) {

            LinearGradient(
                colors: [
                    Color(hex: "#E8F5E9"),
                    Color(hex: "#F0FAF0"),
                    Color(hex: "#FFFFFF"),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {

                headerBar

                Divider()
                    .background(Color(hex: "#C8E6C9"))

                ScrollViewReader { proxy in
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 0) {

                            LogoWithoutText(size: 60)
                                .padding(.top, 20)
                                .padding(.bottom, 16)

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
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(hex: "#E8F5E9"))
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: messageText.isEmpty)
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
        withAnimation { messages.append(newMessage) }
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
                    .foregroundStyle(message.isMine ? Color(hex: "#1A3A1A") : Color(hex: "#1A3A1A"))
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
                            .foregroundStyle(Color(hex: "#5A8A5A").opacity(0.7))
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

