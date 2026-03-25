import SwiftUI

// MARK: - ImageCropView

/// Full-screen crop UI presented after the user picks a photo.
///
/// Always produces an image of exactly `outputSize` pixels (960 × 1200, 4:5 portrait)
/// regardless of whether the source photo is portrait or landscape.
///
/// Usage:
/// ```swift
/// ImageCropView(image: pickedUIImage) { cropped in
///     // cropped is always 960 × 1200 px
/// } onCancel: {
///     // user tapped Cancel
/// }
/// ```
struct ImageCropView: View {

    // MARK: - Constants

    /// Fixed pixel dimensions of every cropped output image.
    static let outputSize = CGSize(width: 1080, height: 1350)

    /// Aspect ratio of the crop window (width ÷ height).
    private static let cropAspect: CGFloat = outputSize.width / outputSize.height   // 0.8 (4:5)

    /// Horizontal margin between crop frame and screen edge.
    private static let cropMargin: CGFloat = 24

    // MARK: - Input

    let image: UIImage
    let onCrop: (UIImage) -> Void
    let onCancel: () -> Void

    // MARK: - Gesture state

    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    // MARK: - Cached layout (set from GeometryReader; used by renderCrop)

    @State private var cachedCropFrame: CGRect = .zero
    @State private var cachedBaseSize: CGSize = .zero
    @State private var cachedContainer: CGSize = .zero

    // MARK: - Body

    var body: some View {
        // GeometryReader at the outermost level gets the true full-screen size
        GeometryReader { geo in
            let c  = geo.size
            let cf = Self.computeCropFrame(in: c)
            let bs = Self.baseDisplaySize(for: image, cropFrame: cf)

            ZStack {
                Color.black

                // MARK: Image layer (pannable / zoomable)
                Image(uiImage: image)
                    .resizable()
                    .frame(
                        width:  bs.width  * scale,
                        height: bs.height * scale
                    )
                    .offset(offset)
                    .allowsHitTesting(false)

                // MARK: Dimming mask + crop border + rule-of-thirds
                cropOverlay(cropFrame: cf)
            }
            // Explicit frame so .overlay knows the exact bounds to anchor against
            .frame(width: c.width, height: c.height)
            // Gesture on the full ZStack frame — fires from anywhere on screen,
            // not just where the image view's layout bounds happen to be.
            .contentShape(Rectangle())
            .gesture(
                SimultaneousGesture(
                    MagnificationGesture()
                        .onChanged { val in
                            let proposed = max(1.0, lastScale * val)
                            scale = proposed
                            offset = Self.clampOffset(
                                lastOffset,
                                baseSize: bs,
                                scale: proposed,
                                cropFrame: cf,
                                container: c
                            )
                        }
                        .onEnded { _ in
                            lastScale = scale
                            lastOffset = offset
                        },
                    DragGesture()
                        .onChanged { val in
                            let proposed = CGSize(
                                width:  lastOffset.width  + val.translation.width,
                                height: lastOffset.height + val.translation.height
                            )
                            offset = Self.clampOffset(
                                proposed,
                                baseSize: bs,
                                scale: scale,
                                cropFrame: cf,
                                container: c
                            )
                        }
                        .onEnded { _ in
                            lastOffset = offset
                        }
                )
            )
            // Controls pinned to the bottom of this known-size frame
            .overlay(alignment: .bottom) {
                bottomBar(safeAreaBottom: geo.safeAreaInsets.bottom)
            }
            .onAppear {
                cachedContainer = c
                cachedCropFrame = cf
                cachedBaseSize  = bs
            }
            .onChange(of: c) { _, newC in
                cachedContainer = newC
                let newCF = Self.computeCropFrame(in: newC)
                cachedCropFrame = newCF
                cachedBaseSize  = Self.baseDisplaySize(for: image, cropFrame: newCF)
            }
        }
        .ignoresSafeArea()
    }

    // MARK: - Bottom bar

    private func bottomBar(safeAreaBottom: CGFloat) -> some View {
        HStack(spacing: 0) {
            Button("Cancel") { onCancel() }
                .font(.system(size: 17, weight: .regular))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)

            Button("Crop") {
                if let img = renderCrop() {
                    onCrop(img)
                }
            }
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(Color(hex: "#E8927C"))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, safeAreaBottom + 8)
        .background(Color.black.opacity(0.55))
    }

    // MARK: - Overlay

    @ViewBuilder
    private func cropOverlay(cropFrame: CGRect) -> some View {
        Canvas { ctx, size in
            // Dim everything
            ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.black.opacity(0.55)))
            // Punch the crop hole using destination-out blend
            ctx.blendMode = .destinationOut
            ctx.fill(
                RoundedRectangle(cornerRadius: 6).path(in: cropFrame),
                with: .color(.black)
            )
        }
        .compositingGroup()
        .allowsHitTesting(false)

        // Crop frame border
        RoundedRectangle(cornerRadius: 6)
            .stroke(Color.white.opacity(0.85), lineWidth: 1.5)
            .frame(width: cropFrame.width, height: cropFrame.height)
            .position(x: cropFrame.midX, y: cropFrame.midY)
            .allowsHitTesting(false)

        // Rule-of-thirds grid
        let thirdW = cropFrame.width / 3
        let thirdH = cropFrame.height / 3
        ForEach(1..<3) { i in
            Rectangle()
                .fill(Color.white.opacity(0.22))
                .frame(width: 0.5, height: cropFrame.height)
                .position(x: cropFrame.minX + thirdW * CGFloat(i), y: cropFrame.midY)
            Rectangle()
                .fill(Color.white.opacity(0.22))
                .frame(width: cropFrame.width, height: 0.5)
                .position(x: cropFrame.midX, y: cropFrame.minY + thirdH * CGFloat(i))
        }
        .allowsHitTesting(false)
    }

    // MARK: - Layout helpers (static, no captured state)

    /// Computes the crop window rect perfectly centered in `container`.
    static func computeCropFrame(in container: CGSize) -> CGRect {
        let maxW = container.width - cropMargin * 2
        // Limit height to 72 % of container so controls have room
        let maxH = container.height * 0.72
        let w: CGFloat
        let h: CGFloat
        if maxW / cropAspect <= maxH {
            w = maxW
            h = maxW / cropAspect
        } else {
            h = maxH
            w = maxH * cropAspect
        }
        let x = (container.width - w) / 2
        let y = (container.height - h) / 2
        return CGRect(x: x, y: y, width: w, height: h)
    }

    /// Base display size of the image so it exactly fills `cropFrame` at scale = 1.0.
    /// The image is scaled up uniformly until both dimensions >= crop frame dimensions.
    static func baseDisplaySize(for image: UIImage, cropFrame: CGRect) -> CGSize {
        guard image.size.width > 0, image.size.height > 0 else { return cropFrame.size }
        let fillScale = max(
            cropFrame.width  / image.size.width,
            cropFrame.height / image.size.height
        )
        return CGSize(width: image.size.width * fillScale, height: image.size.height * fillScale)
    }

    /// Clamps `proposed` offset so the displayed image always covers `cropFrame`.
    ///
    /// Valid range per axis: [centerDelta - halfExcess, centerDelta + halfExcess]
    static func clampOffset(
        _ proposed: CGSize,
        baseSize: CGSize,
        scale: CGFloat,
        cropFrame: CGRect,
        container: CGSize
    ) -> CGSize {
        let displayW = baseSize.width  * scale
        let displayH = baseSize.height * scale

        let halfExcessX = max(0, (displayW - cropFrame.width)  / 2)
        let halfExcessY = max(0, (displayH - cropFrame.height) / 2)

        let centerDeltaX = cropFrame.midX - container.width  / 2
        let centerDeltaY = cropFrame.midY - container.height / 2

        let clampedX = min(max(proposed.width,  centerDeltaX - halfExcessX), centerDeltaX + halfExcessX)
        let clampedY = min(max(proposed.height, centerDeltaY - halfExcessY), centerDeltaY + halfExcessY)

        return CGSize(width: clampedX, height: clampedY)
    }

    // MARK: - Crop rendering

    /// Extracts the crop-frame region from the source image and renders it at `outputSize`.
    ///
    /// Uses cached container / cropFrame / baseSize set by the GeometryReader.
    private func renderCrop() -> UIImage? {
        let bs        = cachedBaseSize
        let cf        = cachedCropFrame
        let c         = cachedContainer

        guard bs.width > 0, bs.height > 0, c.width > 0, c.height > 0 else { return nil }

        let displayW = bs.width  * scale
        let displayH = bs.height * scale

        // Top-left corner of the displayed image in container space
        let imageOriginX = c.width  / 2 + offset.width  - displayW / 2
        let imageOriginY = c.height / 2 + offset.height - displayH / 2

        // Crop frame origin relative to the displayed image's top-left
        let cropInDisplayX = cf.minX - imageOriginX
        let cropInDisplayY = cf.minY - imageOriginY

        // Scale factors: display pixels → source image pixels
        let toSrcX = image.size.width  / displayW
        let toSrcY = image.size.height / displayH

        let srcRect = CGRect(
            x:      cropInDisplayX * toSrcX,
            y:      cropInDisplayY * toSrcY,
            width:  cf.width  * toSrcX,
            height: cf.height * toSrcY
        )

        // Guard against floating-point drift taking us outside image bounds
        let imageBounds = CGRect(origin: .zero, size: image.size)
        let clampedSrc  = srcRect.intersection(imageBounds)
        guard !clampedSrc.isNull, !clampedSrc.isEmpty,
              let cgCropped = image.cgImage?.cropping(to: clampedSrc) else {
            return nil
        }

        // Render the cropped region at exactly outputSize
        let renderer = UIGraphicsImageRenderer(size: Self.outputSize)
        return renderer.image { _ in
            UIImage(cgImage: cgCropped).draw(
                in: CGRect(origin: .zero, size: Self.outputSize)
            )
        }
    }
}
