import SwiftUI

struct ErrorToast: View {
    let message: String
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundStyle(.white)
                .font(.system(size: 16))

            Text(message)
                .foregroundStyle(.white)
                .font(.system(size: 14, weight: .medium))
                .lineLimit(2)

            Spacer()

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .foregroundStyle(.white.opacity(0.8))
                    .font(.system(size: 12, weight: .semibold))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color(hex: "C0392B").opacity(0.95))
        .cornerRadius(12)
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
    }
}
