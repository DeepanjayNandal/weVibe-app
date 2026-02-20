import SwiftUI

struct GenderCheckbox: View {
    let label: String
    @Binding var isSelected: Bool
    
    var body: some View {
        Button {
            isSelected.toggle()
        } label: {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .stroke(.white, lineWidth: 2)
                        .frame(width: 24, height: 24)
                    if isSelected {
                        Circle()
                            .fill(.green)
                            .frame(width: 14, height: 14)
                    }
                }
                Text(label)
                    .foregroundStyle(.white)
                    .font(.system(size: 16))
            }
        }
        .buttonStyle(.plain)
    }
}
