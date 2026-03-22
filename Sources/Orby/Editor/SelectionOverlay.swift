import SwiftUI

// MARK: - Hover Overlay

struct HoverOverlay: View {
    let annotation: Annotation
    var canvasSize: CGSize = .zero
    var zoomLevel: CGFloat = 1.0

    private var rotationAnchor: UnitPoint {
        guard canvasSize.width > 0 && canvasSize.height > 0 else { return .center }
        let r = annotation.boundingRect
        return UnitPoint(x: r.midX / canvasSize.width, y: r.midY / canvasSize.height)
    }

    var body: some View {
        Canvas { ctx, _ in
            let br = annotation.boundingRect
            let r = CGRect(x: (br.minX - 3) * zoomLevel, y: (br.minY - 3) * zoomLevel,
                          width: (br.width + 6) * zoomLevel, height: (br.height + 6) * zoomLevel)
            ctx.stroke(Path(r), with: .color(brandPurple.opacity(0.5)),
                       style: StrokeStyle(lineWidth: 2, dash: [4, 3]))
        }
        .allowsHitTesting(false)
        .rotationEffect(.degrees(annotation.rotation), anchor: rotationAnchor)
    }
}

// MARK: - Selection Overlay

struct SelectionOverlay: View {
    let annotation: Annotation
    var canvasSize: CGSize = .zero
    var zoomLevel: CGFloat = 1.0

    private var rotationAnchor: UnitPoint {
        guard canvasSize.width > 0 && canvasSize.height > 0 else { return .center }
        let r = annotation.boundingRect
        return UnitPoint(x: r.midX / canvasSize.width, y: r.midY / canvasSize.height)
    }

    var body: some View {
        Canvas { ctx, _ in
            let br = annotation.boundingRect
            let r = CGRect(x: (br.minX - 5) * zoomLevel, y: (br.minY - 5) * zoomLevel,
                          width: (br.width + 10) * zoomLevel, height: (br.height + 10) * zoomLevel)
            ctx.stroke(Path(r), with: .color(brandPurple),
                       style: StrokeStyle(lineWidth: 1.5, dash: [5, 3]))
            let hs: CGFloat = 9
            let corners = [
                CGPoint(x: r.minX, y: r.minY), CGPoint(x: r.maxX, y: r.minY),
                CGPoint(x: r.minX, y: r.maxY), CGPoint(x: r.maxX, y: r.maxY)
            ]
            for c in corners {
                let hr = CGRect(x: c.x - hs/2, y: c.y - hs/2, width: hs, height: hs)
                ctx.fill(Path(hr), with: .color(.white))
                ctx.stroke(Path(hr), with: .color(brandPurple), lineWidth: 2)
            }
            if annotation.shape == .arrow {
                let mp = annotation.controlPoint ?? CGPoint(
                    x: (annotation.start.x + annotation.end.x) / 2,
                    y: (annotation.start.y + annotation.end.y) / 2
                )
                let mpZoomed = CGPoint(x: mp.x * zoomLevel, y: mp.y * zoomLevel)
                let hr = CGRect(x: mpZoomed.x - hs/2, y: mpZoomed.y - hs/2, width: hs, height: hs)
                ctx.fill(Path(hr), with: .color(.white))
                ctx.stroke(Path(hr), with: .color(brandPurple), lineWidth: 2)
            }

            // Rotation handle
            let topCenter = CGPoint(x: r.midX, y: r.minY)
            let rotHandle = CGPoint(x: r.midX, y: r.minY - 25 * zoomLevel)

            var line = Path()
            line.move(to: topCenter)
            line.addLine(to: rotHandle)
            ctx.stroke(line, with: .color(brandPurple.opacity(0.6)), lineWidth: 1)

            let rotSize: CGFloat = 10
            let rotRect = CGRect(x: rotHandle.x - rotSize / 2, y: rotHandle.y - rotSize / 2,
                                 width: rotSize, height: rotSize)
            ctx.fill(Path(ellipseIn: rotRect), with: .color(brandPurple))
            ctx.stroke(Path(ellipseIn: rotRect), with: .color(.white), lineWidth: 1.5)
        }
        .allowsHitTesting(false)
        .rotationEffect(.degrees(annotation.rotation), anchor: rotationAnchor)
    }
}
