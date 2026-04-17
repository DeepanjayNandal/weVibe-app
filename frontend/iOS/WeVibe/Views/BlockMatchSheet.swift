import SwiftUI
import FirebaseAuth

// MARK: - Block Match Sheet

struct BlockMatchSheet: View {

    let matchId: String
    var onSuccess: () -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var selectedReason: String? = nil
    @State private var isBlocking = false
    @State private var error: String? = nil

    private let reasons = [
        "Harassment or bullying",
        "Inappropriate content",
        "Spam or scam",
        "Hate speech",
        "Other",
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.primaryBackground.ignoresSafeArea()

                VStack(alignment: .leading, spacing: 0) {

                    titleSection

                    Divider()
                        .background(Color.white.opacity(0.08))

                    reasonLabel

                    reasonList

                    if let error {
                        Text(error)
                            .font(.system(size: 13))
                            .foregroundStyle(.red.opacity(0.85))
                            .padding(.horizontal, 24)
                            .padding(.top, 16)
                    }

                    Spacer()

                    actionButtons
                }
            }
            .navigationBarHidden(true)
        }
    }

    // MARK: - Sections

    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Block this person?")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.white)
            Text("They won't be able to contact you and this match will be removed.")
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.5))
                .lineSpacing(4)
        }
        .padding(.horizontal, 24)
        .padding(.top, 28)
        .padding(.bottom, 20)
    }

    private var reasonLabel: some View {
        Text("Reason (optional)")
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.white.opacity(0.4))
            .textCase(.uppercase)
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .padding(.bottom, 10)
    }

    private var reasonList: some View {
        VStack(spacing: 0) {
            ForEach(reasons, id: \.self) { reason in
                Button {
                    selectedReason = selectedReason == reason ? nil : reason
                } label: {
                    HStack {
                        Text(reason)
                            .font(.system(size: 15))
                            .foregroundStyle(.white)
                        Spacer()
                        if selectedReason == reason {
                            Image(systemName: "checkmark")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(AppTheme.primaryButton)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 15)
                    .background(
                        selectedReason == reason
                            ? Color.white.opacity(0.05)
                            : Color.clear
                    )
                    .animation(.easeInOut(duration: 0.15), value: selectedReason)
                }
                .buttonStyle(.plain)

                if reason != reasons.last {
                    Divider()
                        .background(Color.white.opacity(0.06))
                        .padding(.leading, 24)
                }
            }
        }
    }

    private var actionButtons: some View {
        VStack(spacing: 10) {
            Button {
                Task { await performBlock() }
            } label: {
                HStack(spacing: 8) {
                    if isBlocking {
                        ProgressView()
                            .tint(.white)
                            .scaleEffect(0.8)
                    }
                    Text(isBlocking ? "Blocking..." : "Block")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.red.opacity(isBlocking ? 0.5 : 0.8))
                )
            }
            .disabled(isBlocking)

            Button {
                dismiss()
            } label: {
                Text("Cancel")
                    .font(.system(size: 16))
                    .foregroundStyle(.white.opacity(0.5))
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
            }
            .disabled(isBlocking)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 32)
    }

    // MARK: - Action

    private func performBlock() async {
        isBlocking = true
        error = nil
        do {
            guard let user = Auth.auth().currentUser,
                  let token = try? await user.getIDToken() else {
                error = "Not signed in"
                isBlocking = false
                return
            }
            try await APIClient().blockMatch(matchId: matchId, reason: selectedReason, token: token)
            onSuccess()
        } catch {
            self.error = (error as? APIError)?.errorDescription ?? "Something went wrong. Try again."
            isBlocking = false
        }
    }
}
