import SwiftUI

// MARK: - Shape types

enum AnnotationShape: Equatable, Sendable {
    case rect, circle, line, arrow, text, freehand, blur
}

// MARK: - Blur style

enum BlurStyle: Equatable, Sendable {
    case gaussian   // classic Gaussian blur
    case pixelate   // mosaic / pixelate
}

// MARK: - Arrow style

enum ArrowStyle: Equatable, Sendable {
    case outline    // hollow arrowhead
    case thin       // simple line + arrowhead (current behavior)
    case filled     // thick filled arrow (big visible arrow like Shottr)
    case double     // arrowheads on both ends (↔)
}

// MARK: - Resize handle

enum ResizeHandle: Equatable {
    case topLeft, topRight, bottomLeft, bottomRight
    case startPoint, endPoint
    case midPoint  // control point for arrow curve
    case rotating  // rotation handle above top-center
}

// MARK: - Single annotation

struct Annotation: Identifiable, Equatable {
    let id: UUID
    var shape: AnnotationShape
    var start: CGPoint
    var end: CGPoint
    var color: Color
    var lineWidth: CGFloat
    var filled: Bool
    var solidFill: Bool
    var text: String
    var fontSize: CGFloat
    var points: [CGPoint]
    var arrowStyle: ArrowStyle
    var controlPoint: CGPoint?
    var textHasBackground: Bool
    var blurRadius: CGFloat
    var blurStyle: BlurStyle
    var rotation: Double

    init(shape: AnnotationShape, start: CGPoint, end: CGPoint,
         color: Color = .red, lineWidth: CGFloat = 3, filled: Bool = false, solidFill: Bool = false,
         text: String = "", fontSize: CGFloat = 20, points: [CGPoint] = [],
         arrowStyle: ArrowStyle = .thin, controlPoint: CGPoint? = nil,
         textHasBackground: Bool = true,
         blurRadius: CGFloat = 10, blurStyle: BlurStyle = .gaussian,
         rotation: Double = 0) {
        self.id = UUID()
        self.shape = shape
        self.start = start
        self.end = end
        self.color = color
        self.lineWidth = lineWidth
        self.filled = filled
        self.solidFill = solidFill
        self.text = text
        self.fontSize = fontSize
        self.points = points
        self.arrowStyle = arrowStyle
        self.controlPoint = controlPoint
        self.textHasBackground = textHasBackground
        self.blurRadius = blurRadius
        self.blurStyle = blurStyle
        self.rotation = rotation
    }

    var boundingRect: CGRect {
        if shape == .freehand && !points.isEmpty {
            let xs = points.map(\.x), ys = points.map(\.y)
            return CGRect(x: xs.min()!, y: ys.min()!, width: xs.max()! - xs.min()!, height: ys.max()! - ys.min()!)
        }
        if shape == .text {
            let w = textMeasuredWidth + 10
            let h = fontSize * 1.3 + 8
            return CGRect(x: start.x, y: start.y, width: w, height: h)
        }
        if shape == .arrow, let cp = controlPoint {
            let xs = [start.x, end.x, cp.x], ys = [start.y, end.y, cp.y]
            return CGRect(x: xs.min()!, y: ys.min()!, width: xs.max()! - xs.min()!, height: ys.max()! - ys.min()!)
        }
        return CGRect(
            x: min(start.x, end.x), y: min(start.y, end.y),
            width: abs(end.x - start.x), height: abs(end.y - start.y)
        )
    }

    var textMeasuredWidth: CGFloat {
        guard !text.isEmpty else { return 20 }
        let font = NSFont.systemFont(ofSize: fontSize, weight: .medium)
        let size = (text as NSString).size(withAttributes: [.font: font])
        return max(size.width, 20)
    }

    // MARK: - Rotation helper

    /// Un-rotate a point around annotation center (inverse rotation)
    private func unrotatedPoint(_ point: CGPoint) -> CGPoint {
        guard rotation != 0 else { return point }
        let center = CGPoint(x: boundingRect.midX, y: boundingRect.midY)
        let rad = -rotation * .pi / 180
        let dx = point.x - center.x
        let dy = point.y - center.y
        return CGPoint(
            x: center.x + dx * cos(rad) - dy * sin(rad),
            y: center.y + dx * sin(rad) + dy * cos(rad)
        )
    }

    // MARK: - Hit testing

    func hitTest(_ point: CGPoint, tolerance: CGFloat = 10) -> Bool {
        let point = unrotatedPoint(point)
        switch shape {
        case .blur:
            return boundingRect.insetBy(dx: -tolerance, dy: -tolerance).contains(point)
        case .rect, .circle:
            if filled { return boundingRect.insetBy(dx: -tolerance, dy: -tolerance).contains(point) }
            let outer = boundingRect.insetBy(dx: -tolerance, dy: -tolerance)
            let inner = boundingRect.insetBy(dx: tolerance, dy: tolerance)
            return outer.contains(point) && (inner.width < 0 || inner.height < 0 || !inner.contains(point))
        case .line:
            return distanceToSegment(point: point, from: start, to: end) < tolerance
        case .arrow:
            if let cp = controlPoint {
                return distanceToBezier(point: point, from: start, control: cp, to: end) < tolerance
            }
            return distanceToSegment(point: point, from: start, to: end) < tolerance
        case .text:
            return boundingRect.insetBy(dx: -tolerance, dy: -tolerance).contains(point)
        case .freehand:
            guard points.count >= 2 else { return false }
            for i in 0..<(points.count - 1) {
                if distanceToSegment(point: point, from: points[i], to: points[i + 1]) < tolerance { return true }
            }
            return false
        }
    }

    func handleAt(_ point: CGPoint, tolerance: CGFloat = 10) -> ResizeHandle? {
        // For rotation handle, test in ROTATED space (don't un-rotate)
        // because the handle visually moves with rotation
        let r = boundingRect
        let center = CGPoint(x: r.midX, y: r.midY)
        let rotHandleUnrotated = CGPoint(x: r.midX, y: r.minY - 25)
        // Rotate the handle position to where it visually is
        let rad = rotation * .pi / 180
        let dx = rotHandleUnrotated.x - center.x
        let dy = rotHandleUnrotated.y - center.y
        let rotHandlePos = CGPoint(
            x: center.x + dx * cos(rad) - dy * sin(rad),
            y: center.y + dx * sin(rad) + dy * cos(rad)
        )
        if hypot(point.x - rotHandlePos.x, point.y - rotHandlePos.y) < tolerance {
            return .rotating
        }

        // For corner handles, un-rotate the test point
        let unrotated = unrotatedPoint(point)
        let corners: [(CGPoint, ResizeHandle)] = [
            (CGPoint(x: r.minX, y: r.minY), .topLeft),
            (CGPoint(x: r.maxX, y: r.minY), .topRight),
            (CGPoint(x: r.minX, y: r.maxY), .bottomLeft),
            (CGPoint(x: r.maxX, y: r.maxY), .bottomRight),
        ]
        for (corner, handle) in corners {
            if hypot(unrotated.x - corner.x, unrotated.y - corner.y) < tolerance {
                return handle
            }
        }
        // Midpoint handle for arrows (control point or default midpoint)
        if shape == .arrow {
            let mp = controlPoint ?? CGPoint(x: (start.x + end.x) / 2, y: (start.y + end.y) / 2)
            if hypot(unrotated.x - mp.x, unrotated.y - mp.y) < tolerance {
                return .midPoint
            }
        }
        return nil
    }

    private func distanceToSegment(point: CGPoint, from a: CGPoint, to b: CGPoint) -> CGFloat {
        let dx = b.x - a.x, dy = b.y - a.y
        let lenSq = dx * dx + dy * dy
        guard lenSq > 0 else { return hypot(point.x - a.x, point.y - a.y) }
        let t = max(0, min(1, ((point.x - a.x) * dx + (point.y - a.y) * dy) / lenSq))
        return hypot(point.x - (a.x + t * dx), point.y - (a.y + t * dy))
    }

    /// Approximate distance to a quadratic Bézier curve by sampling
    private func distanceToBezier(point: CGPoint, from a: CGPoint, control c: CGPoint, to b: CGPoint) -> CGFloat {
        var minDist: CGFloat = .greatestFiniteMagnitude
        let steps = 20
        for i in 0...steps {
            let t = CGFloat(i) / CGFloat(steps)
            let oneMinusT = 1 - t
            let px = oneMinusT * oneMinusT * a.x + 2 * oneMinusT * t * c.x + t * t * b.x
            let py = oneMinusT * oneMinusT * a.y + 2 * oneMinusT * t * c.y + t * t * b.y
            let d = hypot(point.x - px, point.y - py)
            if d < minDist { minDist = d }
        }
        return minDist
    }

    // MARK: - Resize

    mutating func resize(handle: ResizeHandle, to point: CGPoint) {
        if shape == .text {
            resizeText(handle: handle, to: point)
            return
        }
        if shape == .freehand {
            resizeFreehand(handle: handle, to: point)
            return
        }
        switch handle {
        case .topLeft:
            start = CGPoint(x: min(point.x, end.x), y: min(point.y, end.y))
        case .topRight:
            end = CGPoint(x: max(point.x, start.x), y: end.y)
            start = CGPoint(x: start.x, y: min(point.y, end.y))
        case .bottomLeft:
            start = CGPoint(x: min(point.x, end.x), y: start.y)
            end = CGPoint(x: end.x, y: max(point.y, start.y))
        case .bottomRight:
            end = CGPoint(x: max(point.x, start.x), y: max(point.y, start.y))
        case .startPoint:
            start = point
        case .endPoint:
            end = point
        case .midPoint:
            controlPoint = point
        case .rotating:
            let center = CGPoint(x: boundingRect.midX, y: boundingRect.midY)
            let angle = atan2(point.x - center.x, -(point.y - center.y))
            rotation = angle * 180 / .pi
        }
    }

    private mutating func resizeText(handle: ResizeHandle, to point: CGPoint) {
        let oldRect = boundingRect
        guard oldRect.height > 0 else { return }
        switch handle {
        case .topLeft:
            let newH = oldRect.maxY - point.y
            if newH > 10 {
                fontSize = max(8, (newH - 8) / 1.3)
                start = CGPoint(x: point.x, y: point.y)
            }
        case .topRight:
            let newH = oldRect.maxY - point.y
            if newH > 10 { fontSize = max(8, (newH - 8) / 1.3) }
            start = CGPoint(x: start.x, y: point.y)
        case .bottomLeft:
            let newH = point.y - start.y
            if newH > 10 {
                fontSize = max(8, (newH - 8) / 1.3)
                start = CGPoint(x: point.x, y: start.y)
            }
        case .bottomRight:
            let newH = point.y - start.y
            if newH > 10 { fontSize = max(8, (newH - 8) / 1.3) }
        default: break
        }
    }

    private mutating func resizeFreehand(handle: ResizeHandle, to point: CGPoint) {
        guard !points.isEmpty else { return }
        let oldRect = boundingRect
        guard oldRect.width > 1 && oldRect.height > 1 else { return }

        // Compute new bounding rect based on which handle is dragged
        var newRect = oldRect
        switch handle {
        case .topLeft:
            newRect = CGRect(x: point.x, y: point.y,
                             width: oldRect.maxX - point.x, height: oldRect.maxY - point.y)
        case .topRight:
            newRect = CGRect(x: oldRect.minX, y: point.y,
                             width: point.x - oldRect.minX, height: oldRect.maxY - point.y)
        case .bottomLeft:
            newRect = CGRect(x: point.x, y: oldRect.minY,
                             width: oldRect.maxX - point.x, height: point.y - oldRect.minY)
        case .bottomRight:
            newRect = CGRect(x: oldRect.minX, y: oldRect.minY,
                             width: point.x - oldRect.minX, height: point.y - oldRect.minY)
        default: break
        }
        guard newRect.width > 5 && newRect.height > 5 else { return }

        // Scale all points from oldRect to newRect
        let sx = newRect.width / oldRect.width
        let sy = newRect.height / oldRect.height
        for i in points.indices {
            points[i] = CGPoint(
                x: newRect.minX + (points[i].x - oldRect.minX) * sx,
                y: newRect.minY + (points[i].y - oldRect.minY) * sy
            )
        }
        start = CGPoint(x: newRect.minX, y: newRect.minY)
        end = CGPoint(x: newRect.maxX, y: newRect.maxY)
    }

    // MARK: - Duplicate

    func duplicate(offset: CGSize = .zero) -> Annotation {
        var copy = Annotation(
            shape: shape, start: start, end: end,
            color: color, lineWidth: lineWidth,
            filled: filled, solidFill: solidFill,
            text: text, fontSize: fontSize,
            points: points, arrowStyle: arrowStyle,
            controlPoint: controlPoint,
            textHasBackground: textHasBackground,
            blurRadius: blurRadius, blurStyle: blurStyle,
            rotation: rotation
        )
        if offset.width != 0 || offset.height != 0 {
            copy.start.x += offset.width
            copy.start.y += offset.height
            copy.end.x += offset.width
            copy.end.y += offset.height
            if var cp = copy.controlPoint {
                cp.x += offset.width
                cp.y += offset.height
                copy.controlPoint = cp
            }
            for i in copy.points.indices {
                copy.points[i].x += offset.width
                copy.points[i].y += offset.height
            }
        }
        return copy
    }

    // MARK: - Move

    mutating func move(by delta: CGSize) {
        start.x += delta.width
        start.y += delta.height
        end.x += delta.width
        end.y += delta.height
        if var cp = controlPoint {
            cp.x += delta.width
            cp.y += delta.height
            controlPoint = cp
        }
        for i in points.indices {
            points[i].x += delta.width
            points[i].y += delta.height
        }
    }
}
