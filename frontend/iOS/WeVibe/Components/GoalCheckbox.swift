import SwiftUI

struct GoalCheckbox: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(isSelected ? Color.green : .white.opacity(0.4), lineWidth: 2)
                        .frame(width: 28, height: 28)
                    if isSelected {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(.green)
                            .frame(width: 28, height: 28)
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
                Text(label)
                    .foregroundStyle(.white)
                    .font(.system(size: 16, weight: .bold))
            }
        }
        .buttonStyle(.plain)
    }
}
