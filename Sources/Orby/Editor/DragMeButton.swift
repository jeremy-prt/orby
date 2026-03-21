import SwiftUI
import AppKit

// MARK: - Drag Button (drag & drop image to Finder/apps)

struct DragMeButton: NSViewRepresentable {
    let image: NSImage

    func makeNSView(context: Context) -> DragMeNSView {
        let v = DragMeNSView()
        v.image = image
        return v
    }

    func updateNSView(_ v: DragMeNSView, context: Context) {
        v.image = image
    }
}

final class DragMeNSView: NSView, NSDraggingSource {
    var image: NSImage?
    private var mouseDownPt: NSPoint?
    private var dragStarted = false
    private var isHovered = false

    override var intrinsicContentSize: NSSize { NSSize(width: 28, height: 28) }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach { removeTrackingArea($0) }
        addTrackingArea(NSTrackingArea(rect: bounds,
                                        options: [.mouseEnteredAndExited, .activeAlways],
                                        owner: self))
    }

    override func mouseEntered(with event: NSEvent) { isHovered = true; needsDisplay = true }
    override func mouseExited(with event: NSEvent) { isHovered = false; needsDisplay = true }

    override func draw(_ dirtyRect: NSRect) {
        if isHovered {
            NSColor(red: 0x9F / 255.0, green: 0x01 / 255.0, blue: 0xA0 / 255.0, alpha: 0.1).setFill()
            NSBezierPath(roundedRect: bounds.insetBy(dx: 1, dy: 1), xRadius: 6, yRadius: 6).fill()
        }

        // 2x3 dot grid
        let dotSize: CGFloat = 2, spacing: CGFloat = 4
        let cols = 2, rows = 3
        let totalW = CGFloat(cols) * dotSize + CGFloat(cols - 1) * spacing
        let totalH = CGFloat(rows) * dotSize + CGFloat(rows - 1) * spacing
        let startX = (bounds.width - totalW) / 2
        let startY = (bounds.height - totalH) / 2
        NSColor.secondaryLabelColor.setFill()
        for row in 0..<rows {
            for col in 0..<cols {
                let x = startX + CGFloat(col) * (dotSize + spacing)
                let y = startY + CGFloat(row) * (dotSize + spacing)
                NSBezierPath(ovalIn: CGRect(x: x, y: y, width: dotSize, height: dotSize)).fill()
            }
        }
    }

    nonisolated func draggingSession(_ s: NSDraggingSession, sourceOperationMaskFor c: NSDraggingContext) -> NSDragOperation {
        [.copy]
    }

    override func mouseDown(with e: NSEvent) {
        mouseDownPt = convert(e.locationInWindow, from: nil)
        dragStarted = false
    }

    override func mouseDragged(with e: NSEvent) {
        guard !dragStarted, let sp = mouseDownPt, let image else { return }
        let c = convert(e.locationInWindow, from: nil)
        guard hypot(c.x - sp.x, c.y - sp.y) > 4 else { return }
        dragStarted = true

        // Write temp PNG with unique name
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(uniqueDragFilename())
        if let t = image.tiffRepresentation,
           let b = NSBitmapImageRep(data: t),
           let d = b.representation(using: .png, properties: [:]) {
            try? d.write(to: url)
        }

        let item = NSDraggingItem(pasteboardWriter: url as NSURL)
        let thumbSize = NSSize(width: 80, height: 55)
        item.setDraggingFrame(
            NSRect(x: sp.x - thumbSize.width / 2, y: sp.y - thumbSize.height / 2,
                   width: thumbSize.width, height: thumbSize.height),
            contents: image
        )

        // Hide window so drop targets underneath are accessible
        window?.orderOut(nil)

        beginDraggingSession(with: [item], event: e, source: self)
    }

    override func mouseUp(with e: NSEvent) {
        mouseDownPt = nil
        dragStarted = false
    }

    nonisolated func draggingSession(_ session: NSDraggingSession, endedAt screenPoint: NSPoint, operation: NSDragOperation) {
        Task { @MainActor in
            if operation != [] {
                // Successful drop — close editor, show toast
                if let win = NSApp.windows.first(where: { $0.title == "Orby" }) {
                    win.close()
                }
                let en = L10n.lang == "en"
                ToastManager.shared.show(
                    title: en ? "Exported!" : "Exporté !",
                    subtitle: en ? "Image dropped successfully" : "Image déposée avec succès"
                )
            } else {
                // Cancelled — restore window
                if let win = NSApp.windows.first(where: { $0.title == "Orby" }) {
                    win.makeKeyAndOrderFront(nil)
                }
            }
        }
    }
}
