import SwiftUI

struct HabitOption {
    let label: String
}

struct HabitSection: View {
    let title: String
    @Binding var selection: String
    let options: [HabitOption]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .foregroundStyle(.white)
                .font(.system(size: 18, weight: .bold))

            HStack(spacing: 10) {
                ForEach(options, id: \.label) { option in
                    Button {
                        selection = option.label
                    } label: {
                        Text(option.label)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(selection == option.label ? .black : .white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(selection == option.label ? Color.white : Color.clear)
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(.white.opacity(0.5), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}
