import SwiftUI

struct PrimaryButton<S: ShapeStyle>: View {
    let title: String
    let background: S
    let foreground: Color
    var height: CGFloat = 52
    var width: CGFloat? = .infinity
    var cornerRadius: CGFloat = 16
    var isLoading: Bool = false
    var isDisabled: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Group {
                if isLoading {
                    ProgressView()
                        .tint(foreground)
                } else {
                    Text(title)
                        .bold()
                }
            }
            .frame(maxWidth: width ?? .infinity)
            .frame(height: height)
        }
        .background(background)
        .foregroundStyle(foreground)
        .cornerRadius(cornerRadius)
        .opacity(isDisabled || isLoading ? 0.6 : 1.0)
        .disabled(isDisabled || isLoading)
    }
}
