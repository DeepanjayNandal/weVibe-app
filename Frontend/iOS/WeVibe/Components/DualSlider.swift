import SwiftUI

struct DualSlider: View {
    @Binding var minValue: Double
    @Binding var maxValue: Double
    let bounds: ClosedRange<Double>
    
    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let range = bounds.upperBound - bounds.lowerBound
            let minX = (minValue - bounds.lowerBound) / range * width
            let maxX = (maxValue - bounds.lowerBound) / range * width
            
            ZStack(alignment: .leading) {
                // Track background
                Capsule()
                    .fill(.white.opacity(0.3))
                    .frame(height: 6)
                
                // Active track
                Capsule()
                    .fill(Color(red: 0.1, green: 0.45, blue: 0.25))
                    .frame(width: maxX - minX, height: 6)
                    .offset(x: minX)
                
                // Min thumb
                Circle()
                    .fill(.green)
                    .frame(width: 26, height: 26)
                    .offset(x: minX - 13)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                let newVal = bounds.lowerBound + value.location.x / width * range
                                minValue = min(max(newVal, bounds.lowerBound), maxValue - 1)
                            }
                    )
                
                // Max thumb
                Circle()
                    .fill(.green)
                    .frame(width: 26, height: 26)
                    .offset(x: maxX - 13)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                let newVal = bounds.lowerBound + value.location.x / width * range
                                maxValue = min(max(newVal, minValue + 1), bounds.upperBound)
                            }
                    )
            }
        }
        .frame(height: 26)
    }
}
