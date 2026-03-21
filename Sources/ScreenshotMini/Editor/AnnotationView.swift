import SwiftUI
import AppKit

// MARK: - Annotation View

struct AnnotationView: View {
    let annotation: Annotation

    var body: some View {
        if annotation.shape == .text {
            textView
        } else {
            Canvas { ctx, _ in
                if annotation.shape == .freehand {
                    drawFreehand(ctx: ctx)
                } else {
                    let s = annotation.start, e = annotation.end
                    if annotation.shape == .arrow {
                        drawArrow(ctx: ctx, from: s, to: e)
                    } else {
                        let path = shapePath(from: s, to: e)
                        if annotation.filled && (annotation.shape == .rect || annotation.shape == .circle) {
                            let opacity: Double = annotation.solidFill ? 1.0 : 0.3
                            ctx.fill(path, with: .color(annotation.color.opacity(opacity)))
                        }
                        ctx.stroke(path, with: .color(annotation.color), lineWidth: annotation.lineWidth)
                    }
                }
            }
            .allowsHitTesting(false)
        }
    }

    @ViewBuilder
    private var textView: some View {
        if !annotation.text.isEmpty {
            let rect = annotation.boundingRect
            let textColor: Color = annotation.textHasBackground ? textColorForBackground(annotation.color) : annotation.color

            ZStack(alignment: .leading) {
                if annotation.textHasBackground {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(annotation.color)
                }
                Text(annotation.text)
                    .font(.system(size: annotation.fontSize, weight: .medium))
                    .foregroundStyle(textColor)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 4)
            }
            .fixedSize()
            .position(x: annotation.start.x + rect.width / 2,
                      y: annotation.start.y + rect.height / 2)
            .allowsHitTesting(false)
        }
    }

    /// Returns white or black text depending on background luminance
    private func textColorForBackground(_ color: Color) -> Color {
        let nsColor = NSColor(color).usingColorSpace(.deviceRGB) ?? NSColor(color)
        let r = nsColor.redComponent, g = nsColor.greenComponent, b = nsColor.blueComponent
        let luminance = 0.299 * r + 0.587 * g + 0.114 * b
        return luminance > 0.6 ? .black : .white
    }

    private func drawFreehand(ctx: GraphicsContext) {
        guard annotation.points.count >= 2 else { return }
        var p = Path()
        p.move(to: annotation.points[0])
        if annotation.points.count == 2 {
            p.addLine(to: annotation.points[1])
        } else {
            for i in 1..<annotation.points.count {
                let mid = CGPoint(
                    x: (annotation.points[i - 1].x + annotation.points[i].x) / 2,
                    y: (annotation.points[i - 1].y + annotation.points[i].y) / 2
                )
                p.addQuadCurve(to: mid, control: annotation.points[i - 1])
            }
            p.addLine(to: annotation.points.last!)
        }
        ctx.stroke(p, with: .color(annotation.color), lineWidth: annotation.lineWidth)
    }

    private func shapePath(from s: CGPoint, to e: CGPoint) -> Path {
        var p = Path()
        let r = CGRect(x: min(s.x, e.x), y: min(s.y, e.y), width: abs(e.x - s.x), height: abs(e.y - s.y))
        switch annotation.shape {
        case .rect: p.addRect(r)
        case .circle: p.addEllipse(in: r)
        case .line: p.move(to: s); p.addLine(to: e)
        case .arrow, .text, .freehand: break
        }
        return p
    }

    // MARK: - Arrow drawing

    private func drawArrow(ctx: GraphicsContext, from s: CGPoint, to e: CGPoint) {
        let cp = annotation.controlPoint
        let hasCurve = cp != nil  // used by drawFilledArrow

        // Tangent angle at the end point (for arrowhead direction)
        let angle: CGFloat
        if let cp = cp {
            angle = atan2(e.y - cp.y, e.x - cp.x)
        } else {
            angle = atan2(e.y - s.y, e.x - s.x)
        }

        // Start angle (for double arrow)
        let startAngle: CGFloat
        if let cp = cp {
            startAngle = atan2(s.y - cp.y, s.x - cp.x)
        } else {
            startAngle = atan2(s.y - e.y, s.x - e.x)
        }

        switch annotation.arrowStyle {
        case .thin:
            drawThinArrow(ctx: ctx, from: s, to: e, cp: cp, angle: angle)
        case .outline:
            drawOutlineArrow(ctx: ctx, from: s, to: e, cp: cp, angle: angle)
        case .filled:
            drawFilledArrow(ctx: ctx, from: s, to: e, cp: cp, angle: angle, hasCurve: hasCurve)
        case .double:
            drawDoubleArrow(ctx: ctx, from: s, to: e, cp: cp, endAngle: angle, startAngle: startAngle)
        }
    }

    /// Thin arrow: simple line + arrowhead lines (original style)
    private func drawThinArrow(ctx: GraphicsContext, from s: CGPoint, to e: CGPoint, cp: CGPoint?, angle: CGFloat) {
        // Shaft
        var shaft = Path()
        shaft.move(to: s)
        if let cp = cp {
            shaft.addQuadCurve(to: e, control: cp)
        } else {
            shaft.addLine(to: e)
        }
        ctx.stroke(shaft, with: .color(annotation.color), lineWidth: annotation.lineWidth)

        // Arrowhead lines
        let hl: CGFloat = 15, ha: CGFloat = .pi / 6
        var head = Path()
        head.move(to: e)
        head.addLine(to: CGPoint(x: e.x - hl * cos(angle - ha), y: e.y - hl * sin(angle - ha)))
        head.move(to: e)
        head.addLine(to: CGPoint(x: e.x - hl * cos(angle + ha), y: e.y - hl * sin(angle + ha)))
        ctx.stroke(head, with: .color(annotation.color), lineWidth: annotation.lineWidth)
    }

    /// Outline arrow: stroked triangular arrowhead + shaft line
    private func drawOutlineArrow(ctx: GraphicsContext, from s: CGPoint, to e: CGPoint, cp: CGPoint?, angle: CGFloat) {
        let hl: CGFloat = 20, ha: CGFloat = .pi / 6

        // Arrowhead triangle (stroked, not filled)
        let tip = e
        let left = CGPoint(x: e.x - hl * cos(angle - ha), y: e.y - hl * sin(angle - ha))
        let right = CGPoint(x: e.x - hl * cos(angle + ha), y: e.y - hl * sin(angle + ha))
        let baseCenter = CGPoint(x: (left.x + right.x) / 2, y: (left.y + right.y) / 2)

        var head = Path()
        head.move(to: tip)
        head.addLine(to: left)
        head.addLine(to: right)
        head.closeSubpath()
        ctx.stroke(head, with: .color(annotation.color), lineWidth: annotation.lineWidth)

        // Shaft (line to base of arrowhead)
        var shaft = Path()
        shaft.move(to: s)
        if let cp = cp {
            shaft.addQuadCurve(to: baseCenter, control: cp)
        } else {
            shaft.addLine(to: baseCenter)
        }
        ctx.stroke(shaft, with: .color(annotation.color), lineWidth: annotation.lineWidth)
    }

    /// Filled arrow: thick filled arrow path (Shottr-style big visible arrow)
    private func drawFilledArrow(ctx: GraphicsContext, from s: CGPoint, to e: CGPoint, cp: CGPoint?, angle: CGFloat, hasCurve: Bool) {
        let shaftWidth = annotation.lineWidth * 3
        let headLength: CGFloat = max(shaftWidth * 3, 30)
        let headWidth: CGFloat = max(shaftWidth * 2.5, 25)

        // Compute the point where the shaft meets the arrowhead base
        let totalLength = hypot(e.x - s.x, e.y - s.y)
        guard totalLength > 1 else { return }

        if hasCurve, let cp = cp {
            // For curved filled arrow, we build left/right offset curves for the shaft
            // and a filled triangular head at the end
            let headRatio = min(headLength / totalLength, 0.5)
            let shaftEndT = max(0, 1.0 - headRatio)

            // Sample the bezier for shaft end point
            let shaftEnd = bezierPoint(t: shaftEndT, from: s, control: cp, to: e)
            // Arrowhead
            let perpHead = bezierTangentAngle(t: 1.0, from: s, control: cp, to: e) + .pi / 2
            let tip = e
            let leftHead = CGPoint(x: shaftEnd.x + headWidth * cos(perpHead), y: shaftEnd.y + headWidth * sin(perpHead))
            let rightHead = CGPoint(x: shaftEnd.x - headWidth * cos(perpHead), y: shaftEnd.y - headWidth * sin(perpHead))

            // Shaft outline: offset curve left and right
            let steps = 12
            var leftPoints: [CGPoint] = []
            var rightPoints: [CGPoint] = []
            for i in 0...steps {
                let t = CGFloat(i) / CGFloat(steps) * shaftEndT
                let pt = bezierPoint(t: t, from: s, control: cp, to: e)
                let tang = bezierTangentAngle(t: t, from: s, control: cp, to: e)
                let perp = tang + .pi / 2
                let halfW = shaftWidth / 2
                leftPoints.append(CGPoint(x: pt.x + halfW * cos(perp), y: pt.y + halfW * sin(perp)))
                rightPoints.append(CGPoint(x: pt.x - halfW * cos(perp), y: pt.y - halfW * sin(perp)))
            }

            var path = Path()
            // Left side of shaft
            path.move(to: leftPoints[0])
            for i in 1..<leftPoints.count { path.addLine(to: leftPoints[i]) }
            // Left head wing
            path.addLine(to: leftHead)
            // Tip
            path.addLine(to: tip)
            // Right head wing
            path.addLine(to: rightHead)
            // Right side of shaft (reversed)
            for i in stride(from: rightPoints.count - 1, through: 0, by: -1) { path.addLine(to: rightPoints[i]) }
            path.closeSubpath()

            ctx.fill(path, with: .color(annotation.color))
        } else {
            // Straight filled arrow
            let perpAngle = angle + .pi / 2
            let halfShaft = shaftWidth / 2

            // Shaft base corners
            let shaftBaseLeft = CGPoint(x: s.x + halfShaft * cos(perpAngle), y: s.y + halfShaft * sin(perpAngle))
            let shaftBaseRight = CGPoint(x: s.x - halfShaft * cos(perpAngle), y: s.y - halfShaft * sin(perpAngle))

            // Shaft meets head
            let headBase = CGPoint(x: e.x - headLength * cos(angle), y: e.y - headLength * sin(angle))
            let shaftTopLeft = CGPoint(x: headBase.x + halfShaft * cos(perpAngle), y: headBase.y + halfShaft * sin(perpAngle))
            let shaftTopRight = CGPoint(x: headBase.x - halfShaft * cos(perpAngle), y: headBase.y - halfShaft * sin(perpAngle))

            // Head wings
            let headLeft = CGPoint(x: headBase.x + headWidth * cos(perpAngle), y: headBase.y + headWidth * sin(perpAngle))
            let headRight = CGPoint(x: headBase.x - headWidth * cos(perpAngle), y: headBase.y - headWidth * sin(perpAngle))

            var path = Path()
            path.move(to: shaftBaseLeft)
            path.addLine(to: shaftTopLeft)
            path.addLine(to: headLeft)
            path.addLine(to: e)
            path.addLine(to: headRight)
            path.addLine(to: shaftTopRight)
            path.addLine(to: shaftBaseRight)
            path.closeSubpath()

            ctx.fill(path, with: .color(annotation.color))
        }
    }

    /// Double arrow: arrowheads on both ends
    private func drawDoubleArrow(ctx: GraphicsContext, from s: CGPoint, to e: CGPoint, cp: CGPoint?, endAngle: CGFloat, startAngle: CGFloat) {
        // Shaft
        var shaft = Path()
        shaft.move(to: s)
        if let cp = cp {
            shaft.addQuadCurve(to: e, control: cp)
        } else {
            shaft.addLine(to: e)
        }
        ctx.stroke(shaft, with: .color(annotation.color), lineWidth: annotation.lineWidth)

        let hl: CGFloat = 15, ha: CGFloat = .pi / 6

        // Arrowhead at end
        var headEnd = Path()
        headEnd.move(to: e)
        headEnd.addLine(to: CGPoint(x: e.x - hl * cos(endAngle - ha), y: e.y - hl * sin(endAngle - ha)))
        headEnd.move(to: e)
        headEnd.addLine(to: CGPoint(x: e.x - hl * cos(endAngle + ha), y: e.y - hl * sin(endAngle + ha)))
        ctx.stroke(headEnd, with: .color(annotation.color), lineWidth: annotation.lineWidth)

        // Arrowhead at start
        var headStart = Path()
        headStart.move(to: s)
        headStart.addLine(to: CGPoint(x: s.x - hl * cos(startAngle - ha), y: s.y - hl * sin(startAngle - ha)))
        headStart.move(to: s)
        headStart.addLine(to: CGPoint(x: s.x - hl * cos(startAngle + ha), y: s.y - hl * sin(startAngle + ha)))
        ctx.stroke(headStart, with: .color(annotation.color), lineWidth: annotation.lineWidth)
    }

    // MARK: - Bézier helpers

    private func bezierPoint(t: CGFloat, from a: CGPoint, control c: CGPoint, to b: CGPoint) -> CGPoint {
        let omt = 1 - t
        return CGPoint(
            x: omt * omt * a.x + 2 * omt * t * c.x + t * t * b.x,
            y: omt * omt * a.y + 2 * omt * t * c.y + t * t * b.y
        )
    }

    private func bezierTangentAngle(t: CGFloat, from a: CGPoint, control c: CGPoint, to b: CGPoint) -> CGFloat {
        // Derivative of quadratic Bézier: 2(1-t)(c-a) + 2t(b-c)
        let dx = 2 * (1 - t) * (c.x - a.x) + 2 * t * (b.x - c.x)
        let dy = 2 * (1 - t) * (c.y - a.y) + 2 * t * (b.y - c.y)
        return atan2(dy, dx)
    }
}

// MARK: - Freehand Preview (during drawing)

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
