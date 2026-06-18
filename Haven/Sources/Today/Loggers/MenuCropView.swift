import SwiftUI
import UIKit
import Vision
import CoreImage.CIFilterBuiltins
import HavenDesignSystem

/// Full-screen crop: shows the captured photo with four draggable corner handles
/// (auto-seeded by Vision document detection), then perspective-corrects the selected
/// quad into a flat 2D image before it goes to the AI.
struct MenuCropView: View {
    @Environment(\.theme) private var theme
    let image: UIImage
    let onConfirm: (UIImage) -> Void
    let onCancel: () -> Void

    // Corners normalized to [0,1], origin top-left, order: TL, TR, BR, BL.
    @State private var corners: [CGPoint] = MenuCropView.defaultCorners

    static let defaultCorners: [CGPoint] = [
        CGPoint(x: 0.08, y: 0.10), CGPoint(x: 0.92, y: 0.10),
        CGPoint(x: 0.92, y: 0.90), CGPoint(x: 0.08, y: 0.90),
    ]

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            GeometryReader { geo in
                let rect = Self.fittedRect(imageSize: image.size, in: geo.size)
                ZStack(alignment: .topLeading) {
                    Image(uiImage: image).resizable().scaledToFit()
                    quad(in: rect)
                    ForEach(0..<4, id: \.self) { i in
                        handle
                            .position(point(corners[i], in: rect))
                            .gesture(
                                DragGesture(coordinateSpace: .named("crop"))
                                    .onChanged { corners[i] = normalize($0.location, in: rect) }
                            )
                    }
                }
                .coordinateSpace(name: "crop")
            }
            VStack {
                Text("Drag the corners to the edges of the menu")
                    .havenText(.meta, color: .white)
                    .padding(.top, Spacing.s8)
                Spacer()
                HStack(spacing: Spacing.s4) {
                    Button(action: onCancel) {
                        Text("Retake").havenText(.sectionHead, color: .white)
                            .frame(maxWidth: .infinity).padding(.vertical, Spacing.s4)
                            .background(.white.opacity(0.16), in: Capsule())
                    }
                    Button { onConfirm(Self.perspectiveCorrect(image, corners: corners) ?? image) } label: {
                        Text("Use photo").havenText(.sectionHead, color: theme.ctaInk)
                            .frame(maxWidth: .infinity).padding(.vertical, Spacing.s4)
                            .background(theme.ctaBg, in: Capsule())
                    }
                    .accessibilityIdentifier("crop-confirm")
                }
                .padding(Spacing.s6)
            }
        }
        .task {
            if let detected = await Self.detectCorners(image) { corners = detected }
        }
    }

    private var handle: some View {
        // 44pt hit target, 22pt visible dot.
        ZStack {
            Color.clear.frame(width: 44, height: 44).contentShape(Rectangle())
            Circle().fill(.white).frame(width: 22, height: 22)
                .overlay(Circle().stroke(theme.accent, lineWidth: 3))
                .shadow(radius: 2)
        }
    }

    @ViewBuilder private func quad(in rect: CGRect) -> some View {
        let pts = corners.map { point($0, in: rect) }
        let path = Path { p in
            p.move(to: pts[0]); p.addLine(to: pts[1]); p.addLine(to: pts[2]); p.addLine(to: pts[3]); p.closeSubpath()
        }
        path.fill(theme.accent.opacity(0.12))
        path.stroke(theme.accent, lineWidth: 2)
    }

    private func point(_ n: CGPoint, in rect: CGRect) -> CGPoint {
        CGPoint(x: rect.minX + n.x * rect.width, y: rect.minY + n.y * rect.height)
    }
    private func normalize(_ p: CGPoint, in rect: CGRect) -> CGPoint {
        CGPoint(x: min(max((p.x - rect.minX) / rect.width, 0), 1),
                y: min(max((p.y - rect.minY) / rect.height, 0), 1))
    }

    static func fittedRect(imageSize: CGSize, in size: CGSize) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0 else { return CGRect(origin: .zero, size: size) }
        let scale = min(size.width / imageSize.width, size.height / imageSize.height)
        let w = imageSize.width * scale, h = imageSize.height * scale
        return CGRect(x: (size.width - w) / 2, y: (size.height - h) / 2, width: w, height: h)
    }

    /// Vision document detection → corners in top-left-origin normalized space (TL, TR, BR, BL).
    static func detectCorners(_ image: UIImage) async -> [CGPoint]? {
        guard let cg = image.normalizedUp().cgImage else { return nil }
        return await withCheckedContinuation { cont in
            let request = VNDetectDocumentSegmentationRequest { req, _ in
                guard let obs = req.results?.first as? VNRectangleObservation else { cont.resume(returning: nil); return }
                func flip(_ p: CGPoint) -> CGPoint { CGPoint(x: p.x, y: 1 - p.y) }   // bottom-left → top-left origin
                cont.resume(returning: [flip(obs.topLeft), flip(obs.topRight), flip(obs.bottomRight), flip(obs.bottomLeft)])
            }
            try? VNImageRequestHandler(cgImage: cg, orientation: .up).perform([request])
        }
    }

    /// Map the selected quad onto a flat rectangle via CIPerspectiveCorrection.
    static func perspectiveCorrect(_ image: UIImage, corners: [CGPoint]) -> UIImage? {
        guard let cg = image.normalizedUp().cgImage else { return nil }
        let ci = CIImage(cgImage: cg)
        let w = ci.extent.width, h = ci.extent.height
        func px(_ n: CGPoint) -> CGPoint { CGPoint(x: n.x * w, y: (1 - n.y) * h) }   // top-left norm → CI bottom-left px
        let f = CIFilter.perspectiveCorrection()
        f.inputImage = ci
        f.topLeft = px(corners[0]); f.topRight = px(corners[1]); f.bottomRight = px(corners[2]); f.bottomLeft = px(corners[3])
        guard let out = f.outputImage else { return nil }
        let ctx = CIContext()
        guard let outCG = ctx.createCGImage(out, from: out.extent) else { return nil }
        return UIImage(cgImage: outCG)
    }
}

extension UIImage {
    /// Redraw so the pixel buffer matches the displayed orientation (origin top-left, .up).
    func normalizedUp() -> UIImage {
        if imageOrientation == .up { return self }
        UIGraphicsBeginImageContextWithOptions(size, false, scale)
        draw(in: CGRect(origin: .zero, size: size))
        let img = UIGraphicsGetImageFromCurrentImageContext() ?? self
        UIGraphicsEndImageContext()
        return img
    }
}
