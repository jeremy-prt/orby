import SwiftUI

struct FreehandPreview: View {
    let points: [CGPoint]
    let color: Color
    let lineWidth: CGFloat
    var zoomLevel: CGFloat = 1.0

    var body: some View {
        Canvas { ctx, _ in
            guard points.count >= 2 else { return }
            var p = Path()
            let firstPt = CGPoint(x: points[0].x * zoomLevel, y: points[0].y * zoomLevel)
            p.move(to: firstPt)
            for i in 1..<points.count {
                let prevPt = CGPoint(x: points[i - 1].x * zoomLevel, y: points[i - 1].y * zoomLevel)
                let currPt = CGPoint(x: points[i].x * zoomLevel, y: points[i].y * zoomLevel)
                let mid = CGPoint(x: (prevPt.x + currPt.x) / 2, y: (prevPt.y + currPt.y) / 2)
                p.addQuadCurve(to: mid, control: prevPt)
            }
            let lastPt = CGPoint(x: points.last!.x * zoomLevel, y: points.last!.y * zoomLevel)
            p.addLine(to: lastPt)
            ctx.stroke(p, with: .color(color), lineWidth: lineWidth * zoomLevel)
        }
        .allowsHitTesting(false)
    }
}
