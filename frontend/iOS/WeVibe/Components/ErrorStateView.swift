import SwiftUI

/// Full-screen error state with an icon, title, message, and a retry button.
/// Covers the entire screen with `AppTheme.primaryBackground`.
/// Place `.transition(.opacity)` at the call site to control animation.
struct ErrorStateView: View {
    var icon: String = "exclamationmark.triangle.fill"
    let title: String
    let message: String
    var actionLabel: String = "Try Again"
    let onRetry: () -> Void

    var body: some View {
        ZStack {
            AppTheme.primaryBackground.ignoresSafeArea()
            VStack(spacing: 20) {
                Spacer()
                Image(systemName: icon)
                    .font(.system(size: 48))
                    .foregroundStyle(.white.opacity(0.5))
                VStack(spacing: 8) {
                    Text(title)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.white)
                    Text(message)
                        .font(.system(size: 14))
                        .foregroundStyle(.white.opacity(0.6))
                        .multilineTextAlignment(.center)
                }
                Button(action: onRetry) {
                    Text(actionLabel)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(AppTheme.primaryBackground)
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .background(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 25))
                }
                .padding(.horizontal, 48)
                Spacer()
            }
        }
    }
}
