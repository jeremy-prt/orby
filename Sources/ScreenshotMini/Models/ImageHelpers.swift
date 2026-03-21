import SwiftUI
import AppKit
import CoreImage
import CoreImage.CIFilterBuiltins

// MARK: - Save helper

@MainActor
func saveImage(_ image: NSImage, to savePath: URL) {
    guard let tiff = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiff) else { return }
    let format = UserDefaults.standard.string(forKey: "imageFormat") ?? "png"
    let (fileType, ext): (NSBitmapImageRep.FileType, String) = switch format {
        case "jpeg": (.jpeg, "jpg")
        case "tiff": (.tiff, "tiff")
        default: (.png, "png")
    }
    let props: [NSBitmapImageRep.PropertyKey: Any] = fileType == .jpeg ? [.compressionFactor: 0.9] : [:]
    guard let data = bitmap.representation(using: fileType, properties: props) else { return }
    let filename = "Screenshot_\(DateFormatter.yyyyMMdd_HHmmss.string(from: Date())).\(ext)"
    try? data.write(to: savePath.appending(path: filename))
    ToastManager.shared.show(message: L10n.lang == "en" ? "Saved!" : "Sauvegardé !")
}

extension DateFormatter {
    static let yyyyMMdd_HHmmss: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd_HH-mm-ss"; return f
    }()
}

// MARK: - Crop helper

func cropImage(_ image: NSImage, to rect: CGRect, canvasSize: CGSize) -> NSImage {
    let scaleX = image.size.width / canvasSize.width
    let scaleY = image.size.height / canvasSize.height
    let cropRect = CGRect(x: rect.origin.x * scaleX, y: rect.origin.y * scaleY,
                          width: rect.width * scaleX, height: rect.height * scaleY)
    guard let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil),
          let cropped = cg.cropping(to: cropRect) else { return image }
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
            let cp: NSPoint? = ann.controlPoint.map { NSPoint(x: $0.x * sx, y: (canvasSize.height - $0.y) * sy) }
            let angle: CGFloat
            if let cp = cp {
                angle = atan2(e.y - cp.y, e.x - cp.x)
            } else {
                angle = atan2(e.y - s.y, e.x - s.x)
            }
            let lw = ann.lineWidth * sx

            switch ann.arrowStyle {
            case .thin:
                path.lineWidth = lw
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
                let tip = e
                let left = NSPoint(x: e.x - hl * cos(angle - ha), y: e.y - hl * sin(angle - ha))
                let right = NSPoint(x: e.x - hl * cos(angle + ha), y: e.y - hl * sin(angle + ha))
                let baseCenter = NSPoint(x: (left.x + right.x) / 2, y: (left.y + right.y) / 2)
                // Shaft
                let sp = NSBezierPath(); sp.lineWidth = lw
                sp.move(to: s)
                if let cp = cp { sp.curve(to: baseCenter, controlPoint1: cp, controlPoint2: cp) } else { sp.line(to: baseCenter) }
                sp.stroke()
                // Arrowhead triangle (stroked)
                let hp = NSBezierPath(); hp.lineWidth = lw
                hp.move(to: tip); hp.line(to: left); hp.line(to: right); hp.close()
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
                    nsColor.setFill(); fp.fill()
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
                    nsColor.setFill(); fp.fill()
                }

            case .double:
                path.lineWidth = lw
                path.move(to: s)
                if let cp = cp { path.curve(to: e, controlPoint1: cp, controlPoint2: cp) } else { path.line(to: e) }
                path.stroke()
                let hl: CGFloat = 15 * sx, ha: CGFloat = .pi / 6
                // End arrowhead
                let ap1 = NSBezierPath(); ap1.lineWidth = lw
                ap1.move(to: e)
                ap1.line(to: NSPoint(x: e.x - hl * cos(angle - ha), y: e.y - hl * sin(angle - ha)))
                ap1.move(to: e)
                ap1.line(to: NSPoint(x: e.x - hl * cos(angle + ha), y: e.y - hl * sin(angle + ha)))
                ap1.stroke()
                // Start arrowhead
                let startAngle: CGFloat
                if let cp = cp {
                    startAngle = atan2(s.y - cp.y, s.x - cp.x)
                } else {
                    startAngle = atan2(s.y - e.y, s.x - e.x)
                }
                let ap2 = NSBezierPath(); ap2.lineWidth = lw
                ap2.move(to: s)
                ap2.line(to: NSPoint(x: s.x - hl * cos(startAngle - ha), y: s.y - hl * sin(startAngle - ha)))
                ap2.move(to: s)
                ap2.line(to: NSPoint(x: s.x - hl * cos(startAngle + ha), y: s.y - hl * sin(startAngle + ha)))
                ap2.stroke()
            }
        case .text:
            if !ann.text.isEmpty {
                let fSize = ann.fontSize * sx
                let font = NSFont.systemFont(ofSize: fSize, weight: .medium)
                let tx = ann.start.x * sx
                // start.y is top-left in canvas (Y-down), convert to AppKit (Y-up)
                let ty = (canvasSize.height - ann.start.y) * sy

                if ann.textHasBackground {
                    // Draw background rounded rect
                    let textW = max(CGFloat(ann.text.count) * fSize * 0.55 + 10 * sx, 20 * sx)
                    let textH = fSize * 1.3 + 8 * sy
                    let bgRect = NSRect(x: tx, y: ty - textH, width: textW, height: textH)
                    let bgPath = NSBezierPath(roundedRect: bgRect, xRadius: 4 * sx, yRadius: 4 * sy)
                    nsColor.setFill()
                    bgPath.fill()

                    // Determine contrast text color
                    let rgbColor = nsColor.usingColorSpace(.deviceRGB) ?? nsColor
                    let r = rgbColor.redComponent, g = rgbColor.greenComponent, b = rgbColor.blueComponent
                    let luminance = 0.299 * r + 0.587 * g + 0.114 * b
                    let textNSColor: NSColor = luminance > 0.6 ? .black : .white

                    let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: textNSColor]
                    let str = NSAttributedString(string: ann.text, attributes: attrs)
                    str.draw(at: NSPoint(x: tx + 5 * sx, y: ty - textH + 4 * sy))
                } else {
                    let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: nsColor]
                    let str = NSAttributedString(string: ann.text, attributes: attrs)
                    str.draw(at: NSPoint(x: tx + 5 * sx, y: ty - fSize * 1.3 - 4 * sy))
                }
            }
        case .freehand:
            guard ann.points.count >= 2 else { break }
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

        case .blur:
            let blurRect = NSRect(
                x: min(s.x, e.x), y: min(s.y, e.y),
                width: abs(e.x - s.x), height: abs(e.y - s.y)
            )
            guard blurRect.width > 1 && blurRect.height > 1 else { break }

            let scaledRadius = ann.blurRadius * sx
            // Extract with padding to avoid edge artifacts
            let pad = scaledRadius * 2
            let padRect = NSRect(
                x: max(0, blurRect.origin.x - pad),
                y: max(0, blurRect.origin.y - pad),
                width: min(imgSize.width - max(0, blurRect.origin.x - pad), blurRect.width + pad * 2),
                height: min(imgSize.height - max(0, blurRect.origin.y - pad), blurRect.height + pad * 2)
            )

            result.unlockFocus()
            let padRegion = NSImage(size: padRect.size)
            padRegion.lockFocus()
            result.draw(in: NSRect(origin: .zero, size: padRect.size),
                        from: padRect, operation: .copy, fraction: 1.0)
            padRegion.unlockFocus()

            guard let tiff = padRegion.tiffRepresentation,
                  let bitmap = NSBitmapImageRep(data: tiff),
                  let cgRegion = bitmap.cgImage else {
                result.lockFocus(); break
            }

            let ciImage = CIImage(cgImage: cgRegion)
            let fullExtent = ciImage.extent
            // The actual blur region within the padded image
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
            if let out = output,
               let cgResult = CIContext().createCGImage(out, from: fullExtent) {
                // Draw only the inner (non-padded) part back
                let fullBlurred = NSImage(cgImage: cgResult, size: padRect.size)
                fullBlurred.draw(in: blurRect, from: innerRect,
                                 operation: .copy, fraction: 1.0)
            }
        }
    }
    result.unlockFocus()
    return result
}



// MARK: - Drag interaction state

enum CanvasInteraction {
    case none
    case drawing(Annotation)          // creating new shape
    case moving(UUID, CGPoint)        // moving annotation, last point
    case resizing(UUID, ResizeHandle)  // resizing via handle
    case freehand([CGPoint])          // collecting freehand points
}
