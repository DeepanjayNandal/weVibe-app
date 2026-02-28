import SwiftUI

struct TextFieldView: View {

    @Binding var title: String
    @Binding var fullSize: Bool

    var body: some View {
        Text(title)
            .foregroundStyle(.white)
            .font(.title)
    }
}
