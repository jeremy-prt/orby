import AppKit

// MARK: - Custom NSPanel with drag source at window level

final class ThumbnailNSPanel: NSPanel, NSDraggingSource, @unchecked Sendable {
    var dragImage: NSImage?

    private var mouseDownPoint: NSPoint?
    private var dragStarted = false
    private var mouseDownOnHandle = false

    nonisolated func draggingSession(
        _ session: NSDraggingSession,
        sourceOperationMaskFor context: NSDraggingContext
    ) -> NSDragOperation { [.copy] }

    override func sendEvent(_ event: NSEvent) {
        switch event.type {
        case .leftMouseDown:
            mouseDownPoint = event.locationInWindow
            dragStarted = false
            // Check if hit view is the drag handle — don't interfere with window move
            if let hitView = contentView?.hitTest(event.locationInWindow),
               hitView is DragHandleNSView {
                mouseDownOnHandle = true
            } else {
                mouseDownOnHandle = false
            }
            super.sendEvent(event)

        case .leftMouseDragged:
            if !mouseDownOnHandle && !dragStarted,
               let startPoint = mouseDownPoint {
                let current = event.locationInWindow
                let distance = hypot(current.x - startPoint.x, current.y - startPoint.y)
                if distance > 8 {
                    dragStarted = true
                    startImageDrag(event: event)
                    return // consume — don't forward
                }
            }
            super.sendEvent(event)

        case .leftMouseUp:
            mouseDownPoint = nil
            dragStarted = false
            mouseDownOnHandle = false
            super.sendEvent(event)

        default:
            super.sendEvent(event)
        }
    }

    private func startImageDrag(event: NSEvent) {
        guard let image = dragImage, let contentView else { return }

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(uniqueDragFilename())
        if let tiff = image.tiffRepresentation,
           let bitmap = NSBitmapImageRep(data: tiff),
           let png = bitmap.representation(using: .png, properties: [:]) {
            try? png.write(to: tempURL)
        }

        let dragItem = NSDraggingItem(pasteboardWriter: tempURL as NSURL)
        let thumbSize = NSSize(width: 80, height: 55)
        let location = contentView.convert(event.locationInWindow, from: nil)
        dragItem.setDraggingFrame(
            NSRect(x: location.x - thumbSize.width / 2,
                   y: location.y - thumbSize.height / 2,
                   width: thumbSize.width, height: thumbSize.height),
            contents: image
        )

        contentView.beginDraggingSession(with: [dragItem], event: event, source: self)
    }

    nonisolated func draggingSession(_ session: NSDraggingSession, endedAt screenPoint: NSPoint, operation: NSDragOperation) {
        Task { @MainActor in
            if operation != [] {
                // Successful drop — dismiss panel, show toast
                self.orderOut(nil)
                let en = L10n.lang == "en"
                ToastManager.shared.show(
                    title: en ? "Exported!" : "Exporté !",
                    subtitle: en ? "Image dropped successfully" : "Image déposée avec succès"
                )
            }
        }
    }
}
