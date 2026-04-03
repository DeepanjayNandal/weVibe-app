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

    private var isWarning: Bool { secondsRemaining <= 600 } // last 10 mins

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
    var onLeaveSession: () -> Void 

    @Environment(ChatRouter.self) private var chatRouter
    @Environment(MatchmakingService.self) private var matchmakingService
    @State private var messageText: String = ""
    @FocusState private var inputFocused: Bool


    @State private var secondsRemaining: Int = 86400
    @State private var timerTask: Task<Void, Never>? = nil
    @State private var showMatchPopup: Bool = false
    @State private var isSessionEnded: Bool = false
    @State private var showLeaveConfirm: Bool = false

    @State private var messages: [ChatMessage] = [
        ChatMessage(text: "Hi Emelie!", isMine: true,  time: "3:02 PM", messagesLeft: 19),
        ChatMessage(text: "Hello 😊",   isMine: false, time: "3:10 PM", messagesLeft: nil),
        ChatMessage(text: "Are you a cats or dogs person?", isMine: true, time: "3:02 PM", messagesLeft: 18),
    ]

    @State private var messagesLeft: Int = 18

    private var showLowMessagesBanner: Bool { messagesLeft > 0 && messagesLeft <= 5 }
    private var isTimerWarning: Bool { secondsRemaining <= 600 }
    private var isChatDisabled: Bool { isSessionEnded || messagesLeft == 0 }

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

                            // ── Logo
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
        .overlay {
            if isSessionEnded {
                Color.black.opacity(0.2)
                    .ignoresSafeArea()
                    .transition(.opacity)
            }
        }
        .overlay(alignment: .bottom) {
            if showMatchPopup {
                MatchDecisionSheet(onMatch: {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { showMatchPopup = false }
                    onClose()
                }, onSkip: {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { showMatchPopup = false }
                    onClose()
                }, onDismiss: {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                        showMatchPopup = false
                        isSessionEnded = false
                    }
                })
                .transition(.move(edge: .bottom))
                .ignoresSafeArea(edges: .bottom)
            }
        }
        .overlay(alignment: .bottom) {
            if showLeaveConfirm {
                LeaveSessionSheet(
                    onLeave: {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { showLeaveConfirm = false }
                        matchmakingService.cancelSearch()
                        onLeaveSession()  // ← use this instead of onClose()
                    },
                    onStay: {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { showLeaveConfirm = false }
                    }
                )
                .transition(.move(edge: .bottom))
                .ignoresSafeArea(edges: .bottom)
            }
        }
        // Dim behind leave sheet
        .overlay {
            if showLeaveConfirm {
                Color.black.opacity(0.15)
                    .ignoresSafeArea()
                    .transition(.opacity)
                    .onTapGesture {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                            showLeaveConfirm = false
                        }
                    }
            }
        }
        // Dim behind match sheet
        .overlay {
            if showMatchPopup {
                Color.black.opacity(0.15)
                    .ignoresSafeArea()
                    .transition(.opacity)
                    .onTapGesture {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                            showMatchPopup = false
                            isSessionEnded = false
                        }
                    }
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
            Button { showLeaveConfirm = true } label: {
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

                // ── Early match button
                Button {
                    triggerSessionEnd()
                } label: {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
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
                .disabled(isChatDisabled)
                .opacity(isChatDisabled ? 0.4 : 1)

                TextField(
                    messagesLeft > 0 ? "Your message" : "No messages left",
                    text: $messageText,
                    axis: .vertical
                )
                .font(.system(size: 15))
                .foregroundStyle(Color(hex: "#1A3A1A"))
                .lineLimit(1...4)
                .focused($inputFocused)
                .disabled(isChatDisabled)
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
                    if secondsRemaining == 0 {
                        triggerSessionEnd()
                    }
                }
            }
        }
    }

    private func triggerSessionEnd() {
        withAnimation(.easeInOut(duration: 0.4)) {
            isSessionEnded = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                showMatchPopup = true
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
        if messagesLeft == 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                triggerSessionEnd()
            }
        }
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

// MARK: - Match Decision Sheet

private struct MatchDecisionSheet: View {
    var onMatch: () -> Void
    var onSkip: () -> Void
    var onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 0) {

            ZStack {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color(hex: "#C8E6C9"))
                    .frame(width: 36, height: 4)
            }
            .padding(.top, 12)
            .padding(.bottom, 20)

            LogoWithoutText(size: 44)
                .padding(.bottom, 14)

            Text("Session's over! 🎉")
                .font(.system(size: 20, weight: .black))
                .foregroundStyle(Color(hex: "#1A3A1A"))
                .padding(.bottom, 6)

            Text("Did you vibe with this person?\nLet them know before they disappear.")
                .font(.system(size: 14))
                .foregroundStyle(Color(hex: "#5A8A5A"))
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.horizontal, 32)
                .padding(.bottom, 28)

            HStack(spacing: 16) {

                Button(action: onSkip) {
                    VStack(spacing: 6) {
                        ZStack {
                            Circle()
                                .fill(Color(hex: "#F5F5F5"))
                                .overlay(Circle().strokeBorder(Color(hex: "#E0E0E0"), lineWidth: 1.5))
                                .frame(width: 64, height: 64)
                            Image(systemName: "xmark")
                                .font(.system(size: 22, weight: .bold))
                                .foregroundStyle(Color(hex: "#9E9E9E"))
                        }
                        Text("nah")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color(hex: "#9E9E9E"))
                    }
                }
                .buttonStyle(ScaleButtonStyle())

                // ✓ Match
                Button(action: onMatch) {
                    VStack(spacing: 6) {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [Color(hex: "#22A855"), Color(hex: "#1A8C4E")],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .overlay(Circle().strokeBorder(Color(hex: "#1A8C4E").opacity(0.3), lineWidth: 1.5))
                                .frame(width: 64, height: 64)
                                .shadow(color: Color(hex: "#1A8C4E").opacity(0.4), radius: 12, x: 0, y: 4)
                            Image(systemName: "checkmark")
                                .font(.system(size: 22, weight: .bold))
                                .foregroundStyle(.white)
                        }
                        Text("match!")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Color(hex: "#1A8C4E"))
                    }
                }
                .buttonStyle(ScaleButtonStyle())
            }
            .padding(.bottom, 48)
        }
        .frame(maxWidth: .infinity)
        .background(
            Color.white
                .ignoresSafeArea(edges: .bottom)
                .shadow(color: .black.opacity(0.12), radius: 24, x: 0, y: -8)
        )
    }
}

// MARK: - Scale Button Style

private struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.93 : 1.0)
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
            RoundedRectangle(cornerRadius: 3)
                .fill(Color(hex: "#C8E6C9"))
                .frame(width: 36, height: 4)
                .padding(.top, 12)
                .padding(.bottom, 20)

            // Icon
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 36))
                .foregroundStyle(Color.orange)
                .padding(.bottom, 12)

            // Title
            Text("Leave this session?")
                .font(.system(size: 20, weight: .black))
                .foregroundStyle(Color(hex: "#1A3A1A"))
                .padding(.bottom, 6)

            // Subtitle
            Text("If you leave now, this chat will end\nand you won't be able to come back.")
                .font(.system(size: 14))
                .foregroundStyle(Color(hex: "#5A8A5A"))
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.horizontal, 32)
                .padding(.bottom, 28)

            // Buttons
            VStack(spacing: 10) {

                // Stay
                Button(action: onStay) {
                    Text("Stay in chat")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(
                                    LinearGradient(
                                        colors: [Color(hex: "#22A855"), Color(hex: "#1A8C4E")],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .shadow(color: Color(hex: "#1A8C4E").opacity(0.35), radius: 10, x: 0, y: 4)
                        )
                }
                .buttonStyle(ScaleButtonStyle())

                // Leave
                Button(action: onLeave) {
                    Text("Yes, leave")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.red.opacity(0.8))
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Color.red.opacity(0.06))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .strokeBorder(Color.red.opacity(0.2), lineWidth: 1)
                                )
                        )
                }
                .buttonStyle(ScaleButtonStyle())
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 48)
        }
        .frame(maxWidth: .infinity)
        .background(
            Color.white
                .ignoresSafeArea(edges: .bottom)
                .shadow(color: .black.opacity(0.12), radius: 24, x: 0, y: -8)
        )
    }
}
