import SwiftUI

/// Reusable back-navigation button with two visual styles.
///
/// - `.text`   — chevron + "Back" label, white; used on auth screens
/// - `.circle` — chevron in a white circle, primary-background tint; used on survey steps
struct BackButton: View {
    enum Style {
        case text
        case circle
    }

    let style: Style
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            switch style {
            case .text:
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .semibold))
                    Text("Back")
                        .font(.system(size: 17))
                }
                .foregroundStyle(.white)

            case .circle:
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(AppTheme.primaryBackground)
                    .frame(width: 48, height: 48)
                    .background(.white)
                    .clipShape(Circle())
            }
        }
    }
}
