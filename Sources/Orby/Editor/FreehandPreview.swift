import SwiftUI

struct FreehandPreview: View {
    let points: [CGPoint]
    let color: Color
    let lineWidth: CGFloat

    var body: some View {
        Canvas { ctx, _ in
            guard points.count >= 2 else { return }
            var p = Path()
            p.move(to: points[0])
            for i in 1..<points.count {
                let mid = CGPoint(
                    x: (points[i - 1].x + points[i].x) / 2,
                    y: (points[i - 1].y + points[i].y) / 2
                )
                p.addQuadCurve(to: mid, control: points[i - 1])
            }
            p.addLine(to: points.last!)
            ctx.stroke(p, with: .color(color), lineWidth: lineWidth)
        }
        .allowsHitTesting(false)
    }
}
