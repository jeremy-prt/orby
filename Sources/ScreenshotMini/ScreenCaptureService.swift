@preconcurrency import ScreenCaptureKit
import AppKit

@MainActor
class ScreenCaptureService {

    func captureFullScreen() async {
        do {
            let availableContent = try await SCShareableContent.current
            guard let display = availableContent.displays.first else { return }

            let filter = SCContentFilter(display: display, including: availableContent.windows)
            let config = SCStreamConfiguration()
            config.width = Int(display.width) * 2
            config.height = Int(display.height) * 2

            let cgImage = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)

            let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: display.width, height: display.height))

            ThumbnailPanel.shared.show(image: nsImage)
        } catch {
            print("Screenshot failed: \(error)")
        }
    }
}
