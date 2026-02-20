import SwiftUI

struct ProgressBarView: View {
    let current: Int
    let total: Int
    
    var progress: CGFloat {
        CGFloat(current) / CGFloat(total)
    }
    
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.white.opacity(0.2))
                    .frame(height: 8)
                
                Capsule()
                    .fill(Color(red: 0.1, green: 0.45, blue: 0.25))
                    .frame(width: geo.size.width * progress, height: 8)
            }
        }
        .frame(height: 8)
    }
}
