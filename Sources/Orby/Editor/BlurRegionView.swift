import SwiftUI
import AppKit
import CoreImage

struct BlurRegionView: View {
    let annotation: Annotation
    let image: NSImage
    let canvasSize: CGSize
    var zoomLevel: CGFloat = 1.0

    private var rotationAnchor: UnitPoint {
        guard canvasSize.width > 0 && canvasSize.height > 0 else { return .center }
        let r = annotation.boundingRect
        return UnitPoint(x: r.midX / canvasSize.width, y: r.midY / canvasSize.height)
    }

    var body: some View {
        let rect = annotation.boundingRect
        guard rect.width > 2 && rect.height > 2 else { return AnyView(EmptyView()) }

        let blurredImage = createBlurredRegion()
        let rectZoomed = CGRect(x: rect.minX * zoomLevel, y: rect.minY * zoomLevel,
                                width: rect.width * zoomLevel, height: rect.height * zoomLevel)
        return AnyView(
            Group {
                if let blurredImage {
                    Image(nsImage: blurredImage)
                        .resizable()
                        .frame(width: rectZoomed.width, height: rectZoomed.height)
                } else {
                    Rectangle().fill(Color.gray.opacity(0.5))
                        .frame(width: rectZoomed.width, height: rectZoomed.height)
                }
            }
            .clipShape(Rectangle())
            .position(x: rectZoomed.midX, y: rectZoomed.midY)
            .allowsHitTesting(false)
            .rotationEffect(.degrees(annotation.rotation), anchor: rotationAnchor)
        )
    }

    private func createBlurredRegion() -> NSImage? {
        let rect = annotation.boundingRect
        let sx = image.size.width / canvasSize.width
        let sy = image.size.height / canvasSize.height

        let srcRect = NSRect(
            x: rect.origin.x * sx,
            y: (canvasSize.height - rect.origin.y - rect.height) * sy,
            width: rect.width * sx,
            height: rect.height * sy
        )
        let regionSize = srcRect.size
        guard regionSize.width > 1 && regionSize.height > 1 else { return nil }

        let region = NSImage(size: regionSize)
        region.lockFocus()
        image.draw(in: NSRect(origin: .zero, size: regionSize),
                   from: srcRect, operation: .copy, fraction: 1.0)
        region.unlockFocus()

        guard let tiff = region.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let cgImg = bitmap.cgImage else { return nil }

        let ciImage = CIImage(cgImage: cgImg)
        let extent = ciImage.extent
        let scaledRadius = annotation.blurRadius * max(sx, sy)
        let clamped = ciImage.clampedToExtent()

        let output: CIImage?
        switch annotation.blurStyle {
        case .gaussian:
            let f = CIFilter(name: "CIGaussianBlur")!
            f.setValue(clamped, forKey: kCIInputImageKey)
            f.setValue(scaledRadius, forKey: kCIInputRadiusKey)
            output = f.outputImage?.cropped(to: extent)
        case .pixelate:
            let f = CIFilter(name: "CIPixellate")!
            f.setValue(ciImage, forKey: kCIInputImageKey)
            f.setValue(max(scaledRadius * 1.2, 8), forKey: kCIInputScaleKey)
            f.setValue(CIVector(x: extent.midX, y: extent.midY), forKey: kCIInputCenterKey)
            output = f.outputImage?.cropped(to: extent)
        }

        guard let out = output,
              let cgResult = CIContext().createCGImage(out, from: extent) else { return nil }

        return NSImage(cgImage: cgResult, size: regionSize)
    }
}
