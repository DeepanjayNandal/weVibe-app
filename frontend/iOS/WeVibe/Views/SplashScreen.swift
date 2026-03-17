import SwiftUI

struct SplashScreen: View {
    @Environment(AuthRouter.self) private var authRouter
    @State private var chevronOffset: CGFloat = 0
    @State private var chevronOpacity: Double = 1.0
    @State var currentDragOffsetY: CGFloat = 0
    
    
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
                    .offset(y: currentDragOffsetY)
                    .opacity(chevronOpacity)
                    .padding(.bottom, 60)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                if value.translation.height < 0 {
                                    withAnimation(.spring()) {
                                        currentDragOffsetY = value.translation.height
                                    }
                                }
                            }
                            .onEnded { value in
                                if value.translation.height < -60 {
                                    authRouter.navigate(to: .login)
                                } else {
                                    withAnimation(.spring()) {
                                        currentDragOffsetY = 0
                                        chevronOffset = 0
                                    }
                                }
                            }
                    )

                
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
    
    struct ChevronUp: Shape {
        func path(in rect: CGRect) -> Path {
            var path = Path()
            path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.midX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            return path
        }
    }
}
