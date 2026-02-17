import SwiftUI

struct LogoView: View {
    var size: CGFloat = 120

    var body: some View {
        Image("LogoPlaceholder")
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
    }
}

#Preview {
    ZStack {
        AppTheme.primaryBackground.ignoresSafeArea()
        LogoView(size: 120)
    }
}
