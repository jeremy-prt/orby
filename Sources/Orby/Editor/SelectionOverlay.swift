import SwiftUI

// MARK: - Hover Overlay
// Uses SwiftUI Rectangle (not Canvas) so the dashed border can overflow the frame without clipping.

struct HoverOverlay: View {
    let annotation: Annotation
    var canvasSize: CGSize = .zero
    var zoomLevel: CGFloat = 1.0
    var canvasOffset: CGPoint = .zero

    private var rotationAnchor: UnitPoint {
        guard canvasSize.width > 0 && canvasSize.height > 0 else { return .center }
        let r = annotation.boundingRect
        return UnitPoint(x: (r.midX + canvasOffset.x) / canvasSize.width, y: (r.midY + canvasOffset.y) / canvasSize.height)
    }

    var body: some View {
        let br = annotation.boundingRect
        let r = CGRect(x: (br.minX - 3 + canvasOffset.x) * zoomLevel, y: (br.minY - 3 + canvasOffset.y) * zoomLevel,
                      width: (br.width + 6) * zoomLevel, height: (br.height + 6) * zoomLevel)

        Rectangle()
            .stroke(brandPurple.opacity(0.5), style: StrokeStyle(lineWidth: 2, dash: [4, 3]))
            .frame(width: r.width, height: r.height)
            .position(x: r.midX, y: r.midY)
            .allowsHitTesting(false)
            .rotationEffect(.degrees(annotation.rotation), anchor: rotationAnchor)
    }
}

// MARK: - Selection Overlay
// Uses SwiftUI views (Rectangle, Circle, Path) instead of Canvas so handles can overflow
// the frame boundary without being clipped. Canvas clips to its own frame — SwiftUI views don't.

struct SelectionOverlay: View {
    let annotation: Annotation
    var canvasSize: CGSize = .zero
    var zoomLevel: CGFloat = 1.0
    var canvasOffset: CGPoint = .zero

    private var rotationAnchor: UnitPoint {
        guard canvasSize.width > 0 && canvasSize.height > 0 else { return .center }
        let r = annotation.boundingRect
        return UnitPoint(x: (r.midX + canvasOffset.x) / canvasSize.width, y: (r.midY + canvasOffset.y) / canvasSize.height)
    }

    var body: some View {
        let br = annotation.boundingRect
        let r = CGRect(x: (br.minX - 5 + canvasOffset.x) * zoomLevel, y: (br.minY - 5 + canvasOffset.y) * zoomLevel,
                      width: (br.width + 10) * zoomLevel, height: (br.height + 10) * zoomLevel)
        let hs: CGFloat = 9
        let corners = [
            CGPoint(x: r.minX, y: r.minY), CGPoint(x: r.maxX, y: r.minY),
            CGPoint(x: r.minX, y: r.maxY), CGPoint(x: r.maxX, y: r.maxY)
        ]
        let topCenter = CGPoint(x: r.midX, y: r.minY)
        let rotHandle = CGPoint(x: r.midX, y: r.minY - 25)
        let rotSize: CGFloat = 10

        ZStack {
            // Dashed selection border
            Rectangle()
                .stroke(brandPurple, style: StrokeStyle(lineWidth: 1.5, dash: [5, 3]))
                .frame(width: r.width, height: r.height)
                .position(x: r.midX, y: r.midY)

            // Corner handles — SwiftUI views overflow the frame (not clipped)
            ForEach(0..<4, id: \.self) { i in
                Rectangle()
                    .fill(.white)
                    .frame(width: hs, height: hs)
                    .overlay(Rectangle().stroke(brandPurple, lineWidth: 2))
                    .position(x: corners[i].x, y: corners[i].y)
            }

            // Arrow midpoint handle
            if annotation.shape == .arrow {
                let mp = annotation.controlPoint ?? CGPoint(
                    x: (annotation.start.x + annotation.end.x) / 2,
                    y: (annotation.start.y + annotation.end.y) / 2
                )
                let mpZoomed = CGPoint(x: (mp.x + canvasOffset.x) * zoomLevel, y: (mp.y + canvasOffset.y) * zoomLevel)
                Rectangle()
                    .fill(.white)
                    .frame(width: hs, height: hs)
                    .overlay(Rectangle().stroke(brandPurple, lineWidth: 2))
                    .position(x: mpZoomed.x, y: mpZoomed.y)
            }

            // Rotation line — Path overflows frame without clipping
            Path { p in
                p.move(to: topCenter)
                p.addLine(to: rotHandle)
            }
            .stroke(brandPurple.opacity(0.6), lineWidth: 1)

            // Rotation handle — Circle overflows frame without clipping
            Circle()
                .fill(brandPurple)
                .frame(width: rotSize, height: rotSize)
                .overlay(Circle().stroke(.white, lineWidth: 1.5))
                .position(x: rotHandle.x, y: rotHandle.y)
        }
        .allowsHitTesting(false)
        .rotationEffect(.degrees(annotation.rotation), anchor: rotationAnchor)
    }
}
