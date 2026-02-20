import SwiftUI

struct EthnicityChip: View {
    let label: String
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            Text(label)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(isSelected ? AppTheme.primaryBackground : .white)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(isSelected ? .white : .clear)
                .cornerRadius(20)
                .overlay(
                    Capsule()
                        .stroke(.white.opacity(0.5), lineWidth: 1)
                )
        }
    }
}


