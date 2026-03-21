import SwiftUI
import AppKit

// MARK: - Cursor claimer (prevents background app cursor from showing)

/// Attached as owner of a tracking area with .activeAlways on the hosting view.
/// Forces the arrow cursor over the panel area even when the app is in the background.
final class PanelCursorClaimer: NSObject {
    @objc func cursorUpdate(with event: NSEvent) {
        NSCursor.arrow.set()
    }
}

// MARK: - Window drag handle (for pinned panels)

struct WindowDragHandleView: NSViewRepresentable {
    func makeNSView(context: Context) -> DragHandleNSView { DragHandleNSView() }
    func updateNSView(_ nsView: DragHandleNSView, context: Context) {}
}

final class DragHandleNSView: NSView {
    private var initialLocation: NSPoint?

    override func mouseDown(with event: NSEvent) {
        initialLocation = event.locationInWindow
    }

    override func mouseDragged(with event: NSEvent) {
        guard let window, let initialLocation else { return }
        let current = event.locationInWindow
        var origin = window.frame.origin
        origin.x += current.x - initialLocation.x
        origin.y += current.y - initialLocation.y
        window.setFrameOrigin(origin)
    }
}
