import SwiftUI
import AppKit

// MARK: - Drag Button (compact icon, drag & drop image to Finder/apps)

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

    override var intrinsicContentSize: NSSize { NSSize(width: 28, height: 28) }

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        // Draw a small drag icon (grid of dots)
        let dotSize: CGFloat = 2
        let spacing: CGFloat = 4
        let cols = 2, rows = 3
        let totalW = CGFloat(cols) * dotSize + CGFloat(cols - 1) * spacing
        let totalH = CGFloat(rows) * dotSize + CGFloat(rows - 1) * spacing
        let startX = (bounds.width - totalW) / 2
        let startY = (bounds.height - totalH) / 2

        ctx.setFillColor(NSColor.secondaryLabelColor.cgColor)
        for row in 0..<rows {
            for col in 0..<cols {
                let x = startX + CGFloat(col) * (dotSize + spacing)
                let y = startY + CGFloat(row) * (dotSize + spacing)
                ctx.fillEllipse(in: CGRect(x: x, y: y, width: dotSize, height: dotSize))
            }
        }
    }

    nonisolated func draggingSession(_ s: NSDraggingSession, sourceOperationMaskFor c: NSDraggingContext) -> NSDragOperation { [.copy] }

    override func mouseDown(with e: NSEvent) {
        mouseDownPt = convert(e.locationInWindow, from: nil)
    }

    override func mouseDragged(with e: NSEvent) {
        guard let image, let sp = mouseDownPt else { return }
        let c = convert(e.locationInWindow, from: nil)
        guard hypot(c.x - sp.x, c.y - sp.y) > 4 else { return }

        let url = FileManager.default.temporaryDirectory.appendingPathComponent("Screenshot_drag.png")
        if let t = image.tiffRepresentation,
           let b = NSBitmapImageRep(data: t),
           let d = b.representation(using: .png, properties: [:]) {
            try? d.write(to: url)
        }

        let item = NSDraggingItem(pasteboardWriter: url as NSURL)
        let thumbSize: CGFloat = 40
        let thumb = NSImage(size: NSSize(width: thumbSize, height: thumbSize))
        thumb.lockFocus()
        image.draw(in: NSRect(origin: .zero, size: thumb.size),
                   from: NSRect(origin: .zero, size: image.size),
                   operation: .copy, fraction: 0.8)
        thumb.unlockFocus()
        item.setDraggingFrame(NSRect(x: sp.x - thumbSize/2, y: sp.y - thumbSize/2,
                                      width: thumbSize, height: thumbSize), contents: thumb)
        beginDraggingSession(with: [item], event: e, source: self)
        mouseDownPt = nil
    }
}
