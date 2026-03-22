import SwiftUI
import AppKit

// MARK: - Editor Window

@MainActor
class EditorWindow {
    static let shared = EditorWindow()
    private var window: NSWindow?

    func open(image: NSImage, savePath: URL) {
        window?.close()

        let editorView = EditorView(originalImage: image, savePath: savePath, onClose: { [weak self] in
            self?.window?.close()
        })

        let hostingView = NSHostingView(rootView: editorView)
        let screen = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1200, height: 800)
        let maxW = screen.width * 0.75, maxH = screen.height * 0.75
        let s = min(maxW / max(image.size.width, 1), maxH / max(image.size.height, 1), 1.0)

        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: max(image.size.width * s, 900), height: max(image.size.height * s, 400) + 50),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered, defer: false
        )
        win.title = "Orby"
        win.titlebarAppearsTransparent = true
        win.titleVisibility = .hidden
        win.styleMask.insert(.fullSizeContentView)
        // Push traffic lights down into the title bar area
        let tb = NSToolbar(identifier: "editorToolbar")
        tb.showsBaselineSeparator = false
        win.toolbar = tb
        win.toolbarStyle = .unifiedCompact
        win.minSize = NSSize(width: 900, height: 400)
        win.contentView = hostingView
        win.center()
        win.isReleasedWhenClosed = false
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        self.window = win
    }
}
