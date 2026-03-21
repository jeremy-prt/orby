import SwiftUI
import AppKit
import CoreImage
import CoreImage.CIFilterBuiltins

// MARK: - Crop helper

func cropImage(_ image: NSImage, to rect: CGRect, canvasSize: CGSize) -> NSImage {
    guard let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return image }
    // Use pixel dimensions (CGImage), not point dimensions (NSImage.size) — Retina images are 2x
    let pixelW = CGFloat(cg.width)
    let pixelH = CGFloat(cg.height)
    let scaleX = pixelW / canvasSize.width
    let scaleY = pixelH / canvasSize.height
    // CGImage origin is top-left (same as canvas Y-down), no flip needed
    let cropRect = CGRect(x: rect.origin.x * scaleX, y: rect.origin.y * scaleY,
                          width: rect.width * scaleX, height: rect.height * scaleY)
    guard let cropped = cg.cropping(to: cropRect) else { return image }
    return NSImage(cgImage: cropped, size: NSSize(width: cropped.width, height: cropped.height))
}

// MARK: - Flatten annotations

func flattenAnnotations(_ annotations: [Annotation], onto image: NSImage, canvasSize: CGSize) -> NSImage {
    guard !annotations.isEmpty else { return image }
    let imgSize = image.size
    let sx = imgSize.width / canvasSize.width, sy = imgSize.height / canvasSize.height

    let result = NSImage(size: imgSize)
    result.lockFocus()
    image.draw(in: NSRect(origin: .zero, size: imgSize))

    for ann in annotations {
        let s = NSPoint(x: ann.start.x * sx, y: (canvasSize.height - ann.start.y) * sy)
        let e = NSPoint(x: ann.end.x * sx, y: (canvasSize.height - ann.end.y) * sy)
        let nsColor = NSColor(ann.color)
        nsColor.setStroke()
        let path = NSBezierPath()
        path.lineWidth = ann.lineWidth * sx

        // Apply rotation transform around annotation center in image coordinates
        let hasRotation = ann.rotation != 0
        if hasRotation {
            NSGraphicsContext.saveGraphicsState()
            let canvasRect = ann.boundingRect
            let cx = canvasRect.midX * sx
            let cy = (canvasSize.height - canvasRect.midY) * sy
            let transform = NSAffineTransform()
            transform.translateX(by: cx, yBy: cy)
            transform.rotate(byDegrees: CGFloat(-ann.rotation))
            transform.translateX(by: -cx, yBy: -cy)
            transform.concat()
        }

        switch ann.shape {
        case .rect:
            let r = NSRect(x: min(s.x, e.x), y: min(s.y, e.y), width: abs(e.x - s.x), height: abs(e.y - s.y))
            path.appendRect(r)
            if ann.filled { nsColor.withAlphaComponent(ann.solidFill ? 1.0 : 0.3).setFill(); path.fill() }
            path.stroke()
        case .circle:
            let r = NSRect(x: min(s.x, e.x), y: min(s.y, e.y), width: abs(e.x - s.x), height: abs(e.y - s.y))
            path.appendOval(in: r)
            if ann.filled { nsColor.withAlphaComponent(ann.solidFill ? 1.0 : 0.3).setFill(); path.fill() }
            path.stroke()
        case .line:
            path.move(to: s); path.line(to: e); path.stroke()
        case .arrow:
            flattenArrow(ann: ann, s: s, e: e, sx: sx, sy: sy, canvasSize: canvasSize)
        case .text:
            flattenText(ann: ann, sx: sx, sy: sy, canvasSize: canvasSize, nsColor: nsColor)
        case .freehand:
            flattenFreehand(ann: ann, sx: sx, sy: sy, canvasSize: canvasSize, nsColor: nsColor)
        case .blur:
            flattenBlur(ann: ann, s: s, e: e, sx: sx, sy: sy, canvasSize: canvasSize,
                        imgSize: imgSize, result: result, hasRotation: hasRotation)
        case .numbered:
            flattenNumbered(ann: ann, sx: sx, sy: sy, canvasSize: canvasSize, nsColor: nsColor)
        }

        if hasRotation {
            NSGraphicsContext.restoreGraphicsState()
        }
    }
    result.unlockFocus()
    return result
}

// MARK: - Flatten helpers

private func flattenArrow(ann: Annotation, s: NSPoint, e: NSPoint, sx: CGFloat, sy: CGFloat, canvasSize: CGSize) {
    let cp: NSPoint? = ann.controlPoint.map { NSPoint(x: $0.x * sx, y: (canvasSize.height - $0.y) * sy) }
    let angle: CGFloat
    if let cp = cp { angle = atan2(e.y - cp.y, e.x - cp.x) }
    else { angle = atan2(e.y - s.y, e.x - s.x) }
    let lw = ann.lineWidth * sx

    switch ann.arrowStyle {
    case .thin:
        let path = NSBezierPath(); path.lineWidth = lw
        path.move(to: s)
        if let cp = cp { path.curve(to: e, controlPoint1: cp, controlPoint2: cp) } else { path.line(to: e) }
        path.stroke()
        let hl: CGFloat = 15 * sx, ha: CGFloat = .pi / 6
        let ap = NSBezierPath(); ap.lineWidth = lw
        ap.move(to: e)
        ap.line(to: NSPoint(x: e.x - hl * cos(angle - ha), y: e.y - hl * sin(angle - ha)))
        ap.move(to: e)
        ap.line(to: NSPoint(x: e.x - hl * cos(angle + ha), y: e.y - hl * sin(angle + ha)))
        ap.stroke()

    case .outline:
        let hl: CGFloat = 20 * sx, ha: CGFloat = .pi / 6
        let left = NSPoint(x: e.x - hl * cos(angle - ha), y: e.y - hl * sin(angle - ha))
        let right = NSPoint(x: e.x - hl * cos(angle + ha), y: e.y - hl * sin(angle + ha))
        let baseCenter = NSPoint(x: (left.x + right.x) / 2, y: (left.y + right.y) / 2)
        let sp = NSBezierPath(); sp.lineWidth = lw
        sp.move(to: s)
        if let cp = cp { sp.curve(to: baseCenter, controlPoint1: cp, controlPoint2: cp) } else { sp.line(to: baseCenter) }
        sp.stroke()
        let hp = NSBezierPath(); hp.lineWidth = lw
        hp.move(to: e); hp.line(to: left); hp.line(to: right); hp.close()
        hp.stroke()

    case .filled:
        let shaftWidth = lw * 3
        let headLength = max(shaftWidth * 3, 30 * sx)
        let headWidth = max(shaftWidth * 2.5, 25 * sx)

        if let cp = cp {
            let totalLength = hypot(e.x - s.x, e.y - s.y)
            guard totalLength > 1 else { break }
            let headRatio = min(headLength / totalLength, 0.5)
            let shaftEndT = max(0, 1.0 - headRatio)
            let steps = 12

            func bezPt(_ t: CGFloat) -> NSPoint {
                let omt = 1 - t
                return NSPoint(x: omt * omt * s.x + 2 * omt * t * cp.x + t * t * e.x,
                               y: omt * omt * s.y + 2 * omt * t * cp.y + t * t * e.y)
            }
            func bezTang(_ t: CGFloat) -> CGFloat {
                let dx = 2 * (1 - t) * (cp.x - s.x) + 2 * t * (e.x - cp.x)
                let dy = 2 * (1 - t) * (cp.y - s.y) + 2 * t * (e.y - cp.y)
                return atan2(dy, dx)
            }

            let shaftEnd = bezPt(shaftEndT)
            let perpHead = bezTang(1.0) + .pi / 2
            let leftHead = NSPoint(x: shaftEnd.x + headWidth * cos(perpHead), y: shaftEnd.y + headWidth * sin(perpHead))
            let rightHead = NSPoint(x: shaftEnd.x - headWidth * cos(perpHead), y: shaftEnd.y - headWidth * sin(perpHead))

            var leftPts: [NSPoint] = [], rightPts: [NSPoint] = []
            for i in 0...steps {
                let t = CGFloat(i) / CGFloat(steps) * shaftEndT
                let pt = bezPt(t)
                let tang = bezTang(t)
                let perp = tang + .pi / 2
                let hw = shaftWidth / 2
                leftPts.append(NSPoint(x: pt.x + hw * cos(perp), y: pt.y + hw * sin(perp)))
                rightPts.append(NSPoint(x: pt.x - hw * cos(perp), y: pt.y - hw * sin(perp)))
            }

            let fp = NSBezierPath()
            fp.move(to: leftPts[0])
            for i in 1..<leftPts.count { fp.line(to: leftPts[i]) }
            fp.line(to: leftHead); fp.line(to: e); fp.line(to: rightHead)
            for i in stride(from: rightPts.count - 1, through: 0, by: -1) { fp.line(to: rightPts[i]) }
            fp.close()
            NSColor(ann.color).setFill(); fp.fill()
        } else {
            let perpAngle = angle + .pi / 2
            let halfShaft = shaftWidth / 2
            let headBase = NSPoint(x: e.x - headLength * cos(angle), y: e.y - headLength * sin(angle))

            let fp = NSBezierPath()
            fp.move(to: NSPoint(x: s.x + halfShaft * cos(perpAngle), y: s.y + halfShaft * sin(perpAngle)))
            fp.line(to: NSPoint(x: headBase.x + halfShaft * cos(perpAngle), y: headBase.y + halfShaft * sin(perpAngle)))
            fp.line(to: NSPoint(x: headBase.x + headWidth * cos(perpAngle), y: headBase.y + headWidth * sin(perpAngle)))
            fp.line(to: e)
            fp.line(to: NSPoint(x: headBase.x - headWidth * cos(perpAngle), y: headBase.y - headWidth * sin(perpAngle)))
            fp.line(to: NSPoint(x: headBase.x - halfShaft * cos(perpAngle), y: headBase.y - halfShaft * sin(perpAngle)))
            fp.line(to: NSPoint(x: s.x - halfShaft * cos(perpAngle), y: s.y - halfShaft * sin(perpAngle)))
            fp.close()
            NSColor(ann.color).setFill(); fp.fill()
        }

    case .double:
        let path = NSBezierPath(); path.lineWidth = lw
        path.move(to: s)
        if let cp = cp { path.curve(to: e, controlPoint1: cp, controlPoint2: cp) } else { path.line(to: e) }
        path.stroke()
        let hl: CGFloat = 15 * sx, ha: CGFloat = .pi / 6
        let ap1 = NSBezierPath(); ap1.lineWidth = lw
        ap1.move(to: e)
        ap1.line(to: NSPoint(x: e.x - hl * cos(angle - ha), y: e.y - hl * sin(angle - ha)))
        ap1.move(to: e)
        ap1.line(to: NSPoint(x: e.x - hl * cos(angle + ha), y: e.y - hl * sin(angle + ha)))
        ap1.stroke()
        let startAngle: CGFloat
        if let cp = cp { startAngle = atan2(s.y - cp.y, s.x - cp.x) }
        else { startAngle = atan2(s.y - e.y, s.x - e.x) }
        let ap2 = NSBezierPath(); ap2.lineWidth = lw
        ap2.move(to: s)
        ap2.line(to: NSPoint(x: s.x - hl * cos(startAngle - ha), y: s.y - hl * sin(startAngle - ha)))
        ap2.move(to: s)
        ap2.line(to: NSPoint(x: s.x - hl * cos(startAngle + ha), y: s.y - hl * sin(startAngle + ha)))
        ap2.stroke()
    }
}

private func flattenText(ann: Annotation, sx: CGFloat, sy: CGFloat, canvasSize: CGSize, nsColor: NSColor) {
    guard !ann.text.isEmpty else { return }
    let fSize = ann.fontSize * sx
    let font = NSFont.systemFont(ofSize: fSize, weight: .medium)
    let padH: CGFloat = 5 * sx
    let padV: CGFloat = 4 * sy
    let tx = ann.start.x * sx
    // start.y is top-left in canvas (Y-down), convert to AppKit (Y-up)
    let ty = (canvasSize.height - ann.start.y) * sy

    // Measure text properly for multiline
    let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: NSColor.white]
    let str = NSAttributedString(string: ann.text, attributes: attrs)
    let textSize = str.size()
    let textW = textSize.width + padH * 2
    let textH = textSize.height + padV * 2

    if ann.textHasBackground {
        let bgRect = NSRect(x: tx, y: ty - textH, width: textW, height: textH)
        let bgPath = NSBezierPath(roundedRect: bgRect, xRadius: 4 * sx, yRadius: 4 * sy)
        nsColor.setFill()
        bgPath.fill()

        let rgbColor = nsColor.usingColorSpace(.deviceRGB) ?? nsColor
        let r = rgbColor.redComponent, g = rgbColor.greenComponent, b = rgbColor.blueComponent
        let luminance = 0.299 * r + 0.587 * g + 0.114 * b
        let textNSColor: NSColor = luminance > 0.6 ? .black : .white

        let textAttrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: textNSColor]
        let textStr = NSAttributedString(string: ann.text, attributes: textAttrs)
        let textRect = NSRect(x: tx + padH, y: ty - textH + padV, width: textSize.width, height: textSize.height)
        textStr.draw(in: textRect)
    } else {
        let textAttrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: nsColor]
        let textStr = NSAttributedString(string: ann.text, attributes: textAttrs)
        let textRect = NSRect(x: tx + padH, y: ty - textH + padV, width: textSize.width, height: textSize.height)
        textStr.draw(in: textRect)
    }
}

private func flattenFreehand(ann: Annotation, sx: CGFloat, sy: CGFloat, canvasSize: CGSize, nsColor: NSColor) {
    guard ann.points.count >= 2 else { return }
    let fp = NSBezierPath(); fp.lineWidth = ann.lineWidth * sx
    let first = NSPoint(x: ann.points[0].x * sx, y: (canvasSize.height - ann.points[0].y) * sy)
    fp.move(to: first)
    for i in 1..<ann.points.count {
        let pt = NSPoint(x: ann.points[i].x * sx, y: (canvasSize.height - ann.points[i].y) * sy)
        let prev = NSPoint(x: ann.points[i-1].x * sx, y: (canvasSize.height - ann.points[i-1].y) * sy)
        let mid = NSPoint(x: (prev.x + pt.x) / 2, y: (prev.y + pt.y) / 2)
        fp.curve(to: mid, controlPoint1: prev, controlPoint2: prev)
    }
    let last = NSPoint(x: ann.points.last!.x * sx, y: (canvasSize.height - ann.points.last!.y) * sy)
    fp.line(to: last)
    nsColor.setStroke()
    fp.stroke()
}

private func flattenNumbered(ann: Annotation, sx: CGFloat, sy: CGFloat, canvasSize: CGSize, nsColor: NSColor) {
    let size = ann.fontSize * 1.6 * sx
    let cx = ann.start.x * sx + size / 2
    let cy = (canvasSize.height - ann.start.y) * sy - size / 2
    let circleRect = NSRect(x: cx - size / 2, y: cy - size / 2, width: size, height: size)

    // Shadow
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.3)
    shadow.shadowBlurRadius = 2 * sx
    shadow.shadowOffset = NSSize(width: 0, height: -1 * sy)
    shadow.set()

    // Filled circle
    nsColor.setFill()
    NSBezierPath(ovalIn: circleRect).fill()
    NSGraphicsContext.restoreGraphicsState()

    // Number text
    let r = nsColor.usingColorSpace(.deviceRGB) ?? nsColor
    let lum = 0.299 * r.redComponent + 0.587 * r.greenComponent + 0.114 * r.blueComponent
    let textColor: NSColor = lum > 0.6 ? .black : .white
    let fontSize = ann.fontSize * 0.75 * sx
    let attrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: fontSize, weight: .bold),
        .foregroundColor: textColor
    ]
    let str = NSAttributedString(string: ann.text, attributes: attrs)
    let strSize = str.size()
    let textOrigin = NSPoint(x: cx - strSize.width / 2, y: cy - strSize.height / 2)
    str.draw(at: textOrigin)
}

private func flattenBlur(ann: Annotation, s: NSPoint, e: NSPoint, sx: CGFloat, sy: CGFloat,
                          canvasSize: CGSize, imgSize: NSSize, result: NSImage, hasRotation: Bool) {
    let blurRect = NSRect(
        x: min(s.x, e.x), y: min(s.y, e.y),
        width: abs(e.x - s.x), height: abs(e.y - s.y)
    )
    guard blurRect.width > 1 && blurRect.height > 1 else { return }

    let scaledRadius = ann.blurRadius * sx
    let pad = scaledRadius * 2
    let padRect = NSRect(
        x: max(0, blurRect.origin.x - pad),
        y: max(0, blurRect.origin.y - pad),
        width: min(imgSize.width - max(0, blurRect.origin.x - pad), blurRect.width + pad * 2),
        height: min(imgSize.height - max(0, blurRect.origin.y - pad), blurRect.height + pad * 2)
    )

    if hasRotation { NSGraphicsContext.restoreGraphicsState() }
    result.unlockFocus()
    let padRegion = NSImage(size: padRect.size)
    padRegion.lockFocus()
    result.draw(in: NSRect(origin: .zero, size: padRect.size),
                from: padRect, operation: .copy, fraction: 1.0)
    padRegion.unlockFocus()

    guard let tiff = padRegion.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiff),
          let cgRegion = bitmap.cgImage else {
        result.lockFocus()
        if hasRotation { NSGraphicsContext.saveGraphicsState() }
        return
    }

    let ciImage = CIImage(cgImage: cgRegion)
    let fullExtent = ciImage.extent
    let innerRect = CGRect(
        x: blurRect.origin.x - padRect.origin.x,
        y: blurRect.origin.y - padRect.origin.y,
        width: blurRect.width,
        height: blurRect.height
    )

    let clamped = ciImage.clampedToExtent()
    let output: CIImage?
    switch ann.blurStyle {
    case .gaussian:
        let f = CIFilter(name: "CIGaussianBlur")!
        f.setValue(clamped, forKey: kCIInputImageKey)
        f.setValue(scaledRadius, forKey: kCIInputRadiusKey)
        output = f.outputImage?.cropped(to: fullExtent)
    case .pixelate:
        let f = CIFilter(name: "CIPixellate")!
        f.setValue(clamped, forKey: kCIInputImageKey)
        f.setValue(max(scaledRadius * 1.2, 8), forKey: kCIInputScaleKey)
        f.setValue(CIVector(x: fullExtent.midX, y: fullExtent.midY), forKey: kCIInputCenterKey)
        output = f.outputImage?.cropped(to: fullExtent)
    }

    result.lockFocus()
    if hasRotation {
        NSGraphicsContext.saveGraphicsState()
        let canvasRect = ann.boundingRect
        let cx = canvasRect.midX * sx
        let cy = (canvasSize.height - canvasRect.midY) * sy
        let transform = NSAffineTransform()
        transform.translateX(by: cx, yBy: cy)
        transform.rotate(byDegrees: CGFloat(-ann.rotation))
        transform.translateX(by: -cx, yBy: -cy)
        transform.concat()
    }
    if let out = output,
       let cgResult = CIContext().createCGImage(out, from: fullExtent) {
        let fullBlurred = NSImage(cgImage: cgResult, size: padRect.size)
        fullBlurred.draw(in: blurRect, from: innerRect,
                         operation: .copy, fraction: 1.0)
    }
}

// MARK: - Drag interaction state

enum CanvasInteraction {
    case none
    case drawing(Annotation)
    case moving(UUID, CGPoint)
    case resizing(UUID, ResizeHandle)
    case freehand([CGPoint])
    case rotating(UUID)
}
