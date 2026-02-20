import SwiftUI

struct GoalCheckbox: View {
    let label: String
    @Binding var isSelected: Bool
    
    var body: some View {
        Button {
            isSelected.toggle()
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(.white.opacity(0.4), lineWidth: 2)
                        .frame(width: 28, height: 28)
                    if isSelected {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(.green)
                            .frame(width: 28, height: 28)
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
