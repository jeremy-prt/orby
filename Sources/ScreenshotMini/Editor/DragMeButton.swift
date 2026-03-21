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
    private var isHovered = false

    override var intrinsicContentSize: NSSize { NSSize(width: 28, height: 28) }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach { removeTrackingArea($0) }
        addTrackingArea(NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeAlways], owner: self))
    }

    override func mouseEntered(with event: NSEvent) {
        isHovered = true
        needsDisplay = true
    }

    override func mouseExited(with event: NSEvent) {
        isHovered = false
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        // Hover background
        if isHovered {
            let bg = NSColor(named: "AccentColor") ?? NSColor.controlAccentColor
            bg.withAlphaComponent(0.1).setFill()
            NSBezierPath(roundedRect: bounds.insetBy(dx: 1, dy: 1), xRadius: 6, yRadius: 6).fill()
        }

        // Draw 2x3 dot grid icon
        let dotSize: CGFloat = 2.0
        let spacing: CGFloat = 4.0
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

    nonisolated func draggingSession(_ s: NSDraggingSession, sourceOperationMaskFor c: NSDraggingContext) -> NSDragOperation { [.copy] }

    override func mouseDown(with e: NSEvent) {
        mouseDownPt = convert(e.locationInWindow, from: nil)

        guard let image else { return }

        // Write temp file immediately
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("Screenshot_drag.png")
        if let t = image.tiffRepresentation,
           let b = NSBitmapImageRep(data: t),
           let d = b.representation(using: .png, properties: [:]) {
            try? d.write(to: url)
        }

        // Start drag session immediately (like Shottr — window hides, cursor shows image)
        let item = NSDraggingItem(pasteboardWriter: url as NSURL)
        let thumbSize: CGFloat = 60
        let aspect = image.size.width / max(image.size.height, 1)
        let thumbW = aspect >= 1 ? thumbSize : thumbSize * aspect
        let thumbH = aspect >= 1 ? thumbSize / aspect : thumbSize
        let thumb = NSImage(size: NSSize(width: thumbW, height: thumbH))
        thumb.lockFocus()
        image.draw(in: NSRect(origin: .zero, size: thumb.size),
                   from: NSRect(origin: .zero, size: image.size),
                   operation: .copy, fraction: 0.85)
        thumb.unlockFocus()

        let sp = mouseDownPt ?? NSPoint(x: bounds.midX, y: bounds.midY)
        item.setDraggingFrame(NSRect(x: sp.x - thumbW/2, y: sp.y - thumbH/2,
                                      width: thumbW, height: thumbH), contents: thumb)

        // Hide window during drag (like Shottr)
        window?.alphaValue = 0.3

        beginDraggingSession(with: [item], event: e, source: self)
    }

    nonisolated func draggingSession(_ session: NSDraggingSession, endedAt screenPoint: NSPoint, operation: NSDragOperation) {
        // Restore window after drag ends
        Task { @MainActor in
            if let win = NSApp.windows.first(where: { $0.title == "Screenshot Mini" && $0.isVisible }) {
                NSAnimationContext.runAnimationGroup { ctx in
                    ctx.duration = 0.2
                    win.animator().alphaValue = 1.0
                }
            }
        }
    }
}
