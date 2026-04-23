import SwiftUI

// MARK: - Match Menu Sheet
// Bottom drawer shown when the user taps ⋮ in a permanent chat.
// Presents Block / Report / Remove Match options.
// "Remove Match" transitions to an inline confirmation within the same sheet.

struct MatchMenuSheet: View {

    var onBlock:   () -> Void
    var onReport:  () -> Void
    var onRemove:  () -> Void
    var onDismiss: () -> Void

    @State private var showRemoveConfirm: Bool = false

    var body: some View {
        ZStack {
            Color(hex: "#111111").ignoresSafeArea()

            if showRemoveConfirm {
                removeConfirmContent
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal:   .move(edge: .leading).combined(with: .opacity)
                    ))
            } else {
                menuContent
                    .transition(.asymmetric(
                        insertion: .move(edge: .leading).combined(with: .opacity),
                        removal:   .move(edge: .trailing).combined(with: .opacity)
                    ))
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: showRemoveConfirm)
    }

    // MARK: - Main Menu

    private var menuContent: some View {
        VStack(spacing: 0) {
            dragHandle

            VStack(spacing: 0) {
                menuRow(
                    icon: "hand.raised.fill",
                    label: "Block",
                    color: .red.opacity(0.85),
                    action: onBlock
                )
                rowDivider
                menuRow(
                    icon: "flag.fill",
                    label: "Report",
                    color: .orange.opacity(0.85),
                    action: onReport
                )
                rowDivider
                menuRow(
                    icon: "trash.fill",
                    label: "Remove Match",
                    color: .red.opacity(0.85),
                    action: { withAnimation { showRemoveConfirm = true } }
                )
            }
            .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 14))
            .padding(.horizontal, 20)

            cancelButton
        }
    }

    // MARK: - Remove Confirm

    private var removeConfirmContent: some View {
        VStack(spacing: 0) {
            dragHandle

            VStack(spacing: 16) {
                Image(systemName: "trash.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(.red.opacity(0.8))

                VStack(spacing: 6) {
                    Text("Remove this match?")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                    Text("This cannot be undone. You'll both lose access to this conversation.")
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.45))
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                }
                .padding(.horizontal, 24)

                VStack(spacing: 10) {
                    Button {
                        onRemove()
                    } label: {
                        Text("Remove Match")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(RoundedRectangle(cornerRadius: 13).fill(.red.opacity(0.8)))
                    }

                    Button {
                        withAnimation { showRemoveConfirm = false }
                    } label: {
                        Text("Go Back")
                            .font(.system(size: 16))
                            .foregroundStyle(.white.opacity(0.5))
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                    }
                }
                .padding(.horizontal, 20)
            }
            .padding(.top, 8)
            .padding(.bottom, 20)
        }
    }

    // MARK: - Reusable Subviews

    private var dragHandle: some View {
        RoundedRectangle(cornerRadius: 3)
            .fill(Color.white.opacity(0.2))
            .frame(width: 36, height: 4)
            .padding(.top, 12)
            .padding(.bottom, 16)
    }

    private var rowDivider: some View {
        Divider()
            .background(Color.white.opacity(0.07))
            .padding(.leading, 52)
    }

    private func menuRow(icon: String, label: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(color)
                    .frame(width: 24)
                Text(label)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(color)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var cancelButton: some View {
        Button(action: onDismiss) {
            Text("Cancel")
                .font(.system(size: 16))
                .foregroundStyle(.white.opacity(0.45))
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 20)
    }
}
