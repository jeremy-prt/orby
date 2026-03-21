import SwiftUI
import AppKit

// MARK: - DPI normalization

/// Downscale Retina image to 1x: pixel count matches point dimensions
func normalizeImageDPI(_ image: NSImage) -> NSImage {
    let pointSize = image.size
    let targetW = Int(pointSize.width)
    let targetH = Int(pointSize.height)
    guard targetW > 0, targetH > 0 else { return image }

    guard let bitmapRep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: targetW,
        pixelsHigh: targetH,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else { return image }

    bitmapRep.size = pointSize

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmapRep)
    image.draw(in: NSRect(origin: .zero, size: pointSize),
               from: NSRect(origin: .zero, size: pointSize),
               operation: .copy, fraction: 1.0)
    NSGraphicsContext.restoreGraphicsState()

    let result = NSImage(size: pointSize)
    result.addRepresentation(bitmapRep)
    return result
}

// MARK: - Save

@MainActor
func saveImage(_ image: NSImage, to savePath: URL) {
    let exportImage = UserDefaults.standard.bool(forKey: "exportRetina") ? image : normalizeImageDPI(image)
    guard let tiff = exportImage.tiffRepresentation,
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
    let fullPath = savePath.appending(path: filename)
    try? data.write(to: fullPath)
    let en = L10n.lang == "en"
    ToastManager.shared.show(
        title: en ? "Saved!" : "Sauvegardé !",
        subtitle: en ? "Saved to \(fullPath.lastPathComponent)" : "Sauvegardé dans \(fullPath.lastPathComponent)"
    )
}

// MARK: - Filename helpers

func uniqueDragFilename() -> String {
    "Screenshot_\(DateFormatter.yyyyMMdd_HHmmss.string(from: Date()))_\(UUID().uuidString.prefix(6)).png"
}

extension DateFormatter {
    static let yyyyMMdd_HHmmss: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd_HH-mm-ss"; return f
    }()
}
