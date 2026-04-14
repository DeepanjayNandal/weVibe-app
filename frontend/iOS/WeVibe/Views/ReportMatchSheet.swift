import SwiftUI
import FirebaseAuth

// MARK: - Report Match Sheet

struct ReportMatchSheet: View {

    let matchId: String
    var onSuccess: () -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var selectedReason: String? = nil
    @State private var details: String = ""
    @State private var alsoBlock = false
    @State private var isReporting = false
    @State private var error: String? = nil

    private let reasons = [
        "Harassment or bullying",
        "Inappropriate content",
        "Spam or scam",
        "Fake profile",
        "Hate speech",
        "Underage user",
        "Other",
    ]

    private var canSubmit: Bool { selectedReason != nil && !isReporting }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.primaryBackground.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {

                        titleSection

                        Divider()
                            .background(Color.white.opacity(0.08))

                        reasonLabel

                        reasonList

                        detailsSection

                        alsoBlockToggle

                        if let error {
                            Text(error)
                                .font(.system(size: 13))
                                .foregroundStyle(.red.opacity(0.85))
                                .padding(.horizontal, 24)
                                .padding(.top, 8)
                        }

                        actionButtons
                    }
                }
            }
            .navigationBarHidden(true)
        }
    }

    // MARK: - Sections

    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Report this person")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.white)
            Text("Help us understand what happened. Reports are reviewed by our team.")
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.5))
                .lineSpacing(4)
        }
        .padding(.horizontal, 24)
        .padding(.top, 28)
        .padding(.bottom, 20)
    }

    private var reasonLabel: some View {
        Text("What happened?")
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
                    selectedReason = reason
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

    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Additional details (optional)")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.4))
                .textCase(.uppercase)

            TextField("Describe what happened...", text: $details, axis: .vertical)
                .font(.system(size: 14))
                .foregroundStyle(.white)
                .lineLimit(3...6)
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.06))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
                        )
                )
        }
        .padding(.horizontal, 24)
        .padding(.top, 24)
        .padding(.bottom, 8)
    }

    private var alsoBlockToggle: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Also block this person")
                    .font(.system(size: 15))
                    .foregroundStyle(.white)
                Text("They won't be able to contact you")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.4))
            }
            Spacer()
            Toggle("", isOn: $alsoBlock)
                .labelsHidden()
                .tint(AppTheme.primaryButton)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(Color.white.opacity(0.04))
        .padding(.top, 8)
    }

    private var actionButtons: some View {
        VStack(spacing: 10) {
            Button {
                Task { await performReport() }
            } label: {
                HStack(spacing: 8) {
                    if isReporting {
                        ProgressView()
                            .tint(.white)
                            .scaleEffect(0.8)
                    }
                    Text(isReporting ? "Submitting..." : "Submit Report")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(canSubmit ? .white : .white.opacity(0.35))
                }
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(canSubmit ? Color.red.opacity(0.8) : Color.white.opacity(0.1))
                )
                .animation(.easeInOut(duration: 0.15), value: canSubmit)
            }
            .disabled(!canSubmit)

            Button {
                dismiss()
            } label: {
                Text("Cancel")
                    .font(.system(size: 16))
                    .foregroundStyle(.white.opacity(0.5))
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
            }
            .disabled(isReporting)
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
        .padding(.bottom, 32)
    }

    // MARK: - Action

    private func performReport() async {
        guard let reason = selectedReason else { return }
        isReporting = true
        error = nil
        do {
            guard let user = Auth.auth().currentUser,
                  let token = try? await user.getIDToken() else {
                error = "Not signed in"
                isReporting = false
                return
            }
            let client = APIClient()
            let trimmedDetails = details.trimmingCharacters(in: .whitespacesAndNewlines)
            try await client.reportMatch(
                matchId: matchId,
                reason: reason,
                details: trimmedDetails.isEmpty ? nil : trimmedDetails,
                token: token
            )
            if alsoBlock {
                try await client.blockMatch(matchId: matchId, reason: reason, token: token)
            }
            onSuccess()
        } catch {
            self.error = (error as? APIError)?.errorDescription ?? "Something went wrong. Try again."
            isReporting = false
        }
    }
}
