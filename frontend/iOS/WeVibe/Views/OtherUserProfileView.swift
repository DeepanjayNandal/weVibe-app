import SwiftUI

// MARK: - OtherUserProfileView
// Wraps ProfileCardView in match-profile mode.
// All rendering logic lives in ProfileCardView to avoid duplication.

struct OtherUserProfileView: View {
    let profile: MatchProfile
    var onDismiss: () -> Void

    var body: some View {
        ProfileCardView(
            data: ProfileDisplayData(from: profile),
            mode: .matchProfile(
                onDismiss: onDismiss,
                onRemove:  onDismiss   // caller handles actual removal
            )
        )
    }
}

// MARK: - Preview

#Preview {
    OtherUserProfileView(profile: .mock, onDismiss: {})
}
