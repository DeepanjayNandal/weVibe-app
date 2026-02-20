import SwiftUI

struct DatePartField: View {
    let placeholder: String
    @Binding var text: String
    let width: CGFloat
    let maxLength: Int
    
    var body: some View {
        HStack() {
            TextField("", text: $text)
                .placeholder(when: text.isEmpty) {
                    Text(placeholder)
                        .foregroundStyle(.white.opacity(0.5))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                }
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .frame(width: width, height: 48)
                .background(.white.opacity(0.1))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(.white.opacity(0.3), lineWidth: 1)
                )
                .onChange(of: text) { _, newValue in
                    if newValue.count > maxLength {
                        text = String(newValue.prefix(maxLength))
                    }
                }
        }
        
    }
}
