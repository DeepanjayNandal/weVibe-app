import SwiftUI

struct LogoWithoutText: View {
    var size: CGFloat = 120

    var body: some View {
        Image("LogoApp")
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
    }
}
