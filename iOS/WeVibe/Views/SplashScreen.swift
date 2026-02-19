import SwiftUI
struct SplashScreen: View {
    @State private var chevronOffset: CGFloat = 0
    @State private var chevronOpacity: Double = 1.0
    @Environment(Router.self) private var router

    var body: some View {
        ZStack {
            AppTheme.primaryBackground
                .ignoresSafeArea()

            VStack {
                Spacer()

                LogoView(size: 130)

                Spacer()

                ChevronUp()
                    .stroke(AppTheme.iconColor, style: StrokeStyle(lineWidth: 8, lineCap: .round, lineJoin: .round))
                    .frame(width: 40, height: 30)
                    .offset(y: chevronOffset)
                    .opacity(chevronOpacity)
                    .padding(.bottom, 60)
                
                Button("Go to Login") {
                    router.navigateToLogin()
                }
                
                
            }
        }
        .onAppear {
            withAnimation(
                .easeInOut(duration: 1.0)
                .repeatForever(autoreverses: true)
            ) {
                chevronOffset = -10
                chevronOpacity = 0.4
            }
        }
    }
}


struct ChevronUp: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        return path
    }
}

#Preview {
    SplashScreen()
}
