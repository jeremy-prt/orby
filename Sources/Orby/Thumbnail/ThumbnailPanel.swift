import SwiftUI
import AppKit

let thumbWidth: CGFloat = 200
let thumbHeight: CGFloat = 140
let thumbPadding: CGFloat = 6
let stackGap: CGFloat = 8
let pinOffset: CGFloat = 30

// MARK: - ThumbnailPanel

@MainActor
class ThumbnailPanel {
    static let shared = ThumbnailPanel()

    private var panels: [PanelEntry] = []
    private var scrollMonitor: Any?
    private var cursorMonitor: Any?

    private struct PanelEntry {
        let id: UUID
        let panel: ThumbnailNSPanel
        let cursorClaimer: PanelCursorClaimer
        let image: NSImage
        var timer: Timer?
        var isPinned: Bool = false
        var wasMoved: Bool = false
        var scrollAccumX: CGFloat = 0
        var scrollAccumY: CGFloat = 0
    }

    private var position: ScreenPosition {
        ScreenPosition(rawValue: UserDefaults.standard.string(forKey: "previewPosition") ?? "bottomLeft") ?? .bottomLeft
    }

    private var dismissDelay: TimeInterval {
        let val = UserDefaults.standard.double(forKey: "dismissDelay")
        return val > 0 ? val : 5
    }

    private var closeAfterAction: Bool {
        UserDefaults.standard.object(forKey: "closeAfterAction") as? Bool ?? true
    }

    private var savePath: URL {
        let path = UserDefaults.standard.string(forKey: "savePath") ?? ""
        if path.isEmpty {
            return FileManager.default.homeDirectoryForCurrentUser.appending(path: "Desktop")
        }
        return URL(fileURLWithPath: path)
    }

    func show(image: NSImage) {
        let id = UUID()

        let thumbnailView = ThumbnailView(
            image: image,
            onCopy: { [weak self] in
                self?.copyToClipboard(image: image)
                if self?.closeAfterAction == true {
                    self?.dismissAfterFeedback(id: id)
                }
            },
            onSave: { [weak self] in
                self?.saveToDisk(image: image)
                if self?.closeAfterAction == true {
                    self?.dismissAfterFeedback(id: id)
                }
            },
            onEdit: { [weak self] in
                self?.openEditor(image: image, id: id)
            },
            onDismiss: { [weak self] in
                self?.dismissPanel(id: id)
            },
            onPin: { [weak self] pinned in
                self?.setPinned(pinned, id: id)
            },
            onHover: { [weak self] hovering in
                self?.handleHover(hovering, id: id)
            }
        )

        let hostingView = NSHostingView(rootView: thumbnailView)

        let panelW = thumbWidth + thumbPadding * 2
        let panelH = thumbHeight + thumbPadding * 2

        let panel = ThumbnailNSPanel(
            contentRect: NSRect(x: 0, y: 0, width: panelW, height: panelH),
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.hasShadow = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.contentView = hostingView
        panel.isMovableByWindowBackground = false
        panel.dragImage = image

        // Claim cursor over the panel (prevents background app cursor from showing)
        let cursorClaimer = PanelCursorClaimer()
        let trackingArea = NSTrackingArea(
            rect: .zero,
            options: [.cursorUpdate, .activeAlways, .inVisibleRect],
            owner: cursorClaimer,
            userInfo: nil
        )
        hostingView.addTrackingArea(trackingArea)

        let stackIndex = nonPinnedCount()
        let frame = stackFrame(at: stackIndex)
        panel.setFrame(frame, display: false)

        // Entrance animation
        panel.alphaValue = 0
        let finalFrame = panel.frame
        let scaledW = finalFrame.width * 0.6
        let scaledH = finalFrame.height * 0.6
        let offsetX = (finalFrame.width - scaledW) / 2
        let offsetY = (finalFrame.height - scaledH) / 2
        panel.setFrame(
            NSRect(x: finalFrame.origin.x + offsetX, y: finalFrame.origin.y + offsetY,
                   width: scaledW, height: scaledH),
            display: false
        )
        panel.orderFrontRegardless()

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.35
            ctx.timingFunction = CAMediaTimingFunction(controlPoints: 0.34, 1.56, 0.64, 1.0)
            panel.animator().setFrame(finalFrame, display: true)
            panel.animator().alphaValue = 1
        }

        var entry = PanelEntry(id: id, panel: panel, cursorClaimer: cursorClaimer, image: image)
        entry.timer = makeTimer(id: id)
        panels.append(entry)

        installMonitors()
    }

    // MARK: - Event monitors

    private func installMonitors() {
        // Scroll monitor for swipe dismiss
        guard scrollMonitor == nil else { return }

        scrollMonitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
            self?.handleScrollEvent(event)
            return event
        }

        // Global cursor monitor — forces arrow cursor over our panels
        // even when the app is in the background
        guard cursorMonitor == nil else { return }
        cursorMonitor = NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved) { [weak self] _ in
            guard let self else { return }
            let mouseLocation = NSEvent.mouseLocation
            for entry in self.panels {
                if entry.panel.frame.contains(mouseLocation) {
                    NSCursor.arrow.set()
                    return
                }
            }
        }
    }

    private func handleScrollEvent(_ event: NSEvent) {
        guard let eventWindow = event.window else { return }
        guard let idx = panels.firstIndex(where: { $0.panel === eventWindow }) else { return }

        if event.phase == .began {
            panels[idx].scrollAccumX = 0
            panels[idx].scrollAccumY = 0
        }

        panels[idx].scrollAccumX += event.scrollingDeltaX
        panels[idx].scrollAccumY += event.scrollingDeltaY

        if event.phase == .ended || event.phase == .cancelled {
            let threshold: CGFloat = 30
            let accumX = panels[idx].scrollAccumX
            let accumY = panels[idx].scrollAccumY
            let pos = position

            // Only dismiss on swipe toward screen edge or down
            // scrollingDeltaY > 0 = content scrolls down = finger swipes down
            // scrollingDeltaX > 0 = content scrolls right = finger swipes right
            var shouldDismiss = false
            // Swipe down
            if accumY > threshold { shouldDismiss = true }
            // Swipe toward the edge
            switch pos {
            case .bottomLeft, .topLeft:
                if accumX < -threshold { shouldDismiss = true } // swipe left
            case .bottomRight, .topRight:
                if accumX > threshold { shouldDismiss = true } // swipe right
            }

            if shouldDismiss {
                dismissPanel(id: panels[idx].id)
            }
            panels[idx].scrollAccumX = 0
            panels[idx].scrollAccumY = 0
        }
    }

    // MARK: - Helpers

    private func nonPinnedCount() -> Int {
        panels.filter { !$0.isPinned }.count
    }

    private func stackFrame(at stackIndex: Int) -> NSRect {
        guard let screen = NSScreen.main else { return .zero }
        let vis = screen.visibleFrame
        let panelW = thumbWidth + thumbPadding * 2
        let panelH = thumbHeight + thumbPadding * 2
        let margin: CGFloat = 16

        let pos = position
        let x: CGFloat
        let baseY: CGFloat
        let yDirection: CGFloat

        switch pos {
        case .bottomLeft:
            x = vis.origin.x + margin; baseY = vis.origin.y + margin; yDirection = 1
        case .bottomRight:
            x = vis.origin.x + vis.width - panelW - margin; baseY = vis.origin.y + margin; yDirection = 1
        case .topLeft:
            x = vis.origin.x + margin; baseY = vis.origin.y + vis.height - panelH - margin; yDirection = -1
        case .topRight:
            x = vis.origin.x + vis.width - panelW - margin; baseY = vis.origin.y + vis.height - panelH - margin; yDirection = -1
        }

        let y = baseY + yDirection * CGFloat(stackIndex) * (panelH + stackGap)
        return NSRect(x: x, y: y, width: panelW, height: panelH)
    }

    private func pinnedFrame(from frame: NSRect) -> NSRect {
        let dx: CGFloat
        switch position {
        case .bottomLeft, .topLeft: dx = pinOffset
        case .bottomRight, .topRight: dx = -pinOffset
        }
        return NSRect(x: frame.origin.x + dx, y: frame.origin.y,
                       width: frame.width, height: frame.height)
    }

    private func slideOutOffset() -> CGPoint {
        switch position {
        case .bottomLeft, .topLeft: return CGPoint(x: -250, y: 0)
        case .bottomRight, .topRight: return CGPoint(x: 250, y: 0)
        }
    }

    private func makeTimer(id: UUID) -> Timer {
        Timer.scheduledTimer(withTimeInterval: dismissDelay, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.dismissPanel(id: id)
            }
        }
    }

    private func handleHover(_ hovering: Bool, id: UUID) {
        guard let idx = panels.firstIndex(where: { $0.id == id }) else { return }
        if hovering {
            panels[idx].timer?.invalidate()
            panels[idx].timer = nil
        } else if !panels[idx].isPinned {
            panels[idx].timer = makeTimer(id: id)
        }
    }

    // MARK: - Pin

    private func setPinned(_ pinned: Bool, id: UUID) {
        guard let idx = panels.firstIndex(where: { $0.id == id }) else { return }
        panels[idx].isPinned = pinned
        let panel = panels[idx].panel

        if pinned {
            panels[idx].timer?.invalidate()
            panels[idx].timer = nil
            panel.level = .statusBar
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

            let currentFrame = panel.frame
            let targetFrame = pinnedFrame(from: currentFrame)
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.25
                ctx.timingFunction = CAMediaTimingFunction(controlPoints: 0.34, 1.2, 0.64, 1.0)
                panel.animator().setFrame(targetFrame, display: true)
            }

            repositionNonPinnedPanels()

            let pinnedOrigin = targetFrame.origin
            NotificationCenter.default.addObserver(
                forName: NSWindow.didMoveNotification,
                object: panel,
                queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated {
                    guard let self, let i = self.panels.firstIndex(where: { $0.id == id }) else { return }
                    let current = self.panels[i].panel.frame.origin
                    if abs(current.x - pinnedOrigin.x) > 5 || abs(current.y - pinnedOrigin.y) > 5 {
                        self.panels[i].wasMoved = true
                    }
                }
            }
        } else {
            NotificationCenter.default.removeObserver(self, name: NSWindow.didMoveNotification, object: panel)
            panel.level = .floating
            panel.collectionBehavior = []
            panels[idx].wasMoved = false
            panels[idx].timer = makeTimer(id: id)
            repositionNonPinnedPanels()
        }
    }

    // MARK: - Dismiss

    private func dismissAfterFeedback(id: UUID) {
        guard let idx = panels.firstIndex(where: { $0.id == id }) else { return }
        panels[idx].timer?.invalidate()
        panels[idx].timer = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
            self?.dismissPanel(id: id)
        }
    }

    /// Dismiss never saves. Only the Save button saves.
    /// Dismiss all open previews (used when multi-preview is off)
    func dismissAll() {
        let ids = panels.map(\.id)
        for id in ids {
            guard let idx = panels.firstIndex(where: { $0.id == id }) else { continue }
            panels[idx].timer?.invalidate()
            panels[idx].panel.orderOut(nil)
            NotificationCenter.default.removeObserver(self, name: NSWindow.didMoveNotification, object: panels[idx].panel)
        }
        panels.removeAll()
        if let monitor = scrollMonitor {
            NSEvent.removeMonitor(monitor)
            scrollMonitor = nil
        }
        if let monitor = cursorMonitor {
            NSEvent.removeMonitor(monitor)
            cursorMonitor = nil
        }
    }

    func dismissPanel(id: UUID) {
        guard let idx = panels.firstIndex(where: { $0.id == id }) else { return }
        let entry = panels[idx]
        entry.timer?.invalidate()

        NotificationCenter.default.removeObserver(self, name: NSWindow.didMoveNotification, object: entry.panel)

        let panel = entry.panel
        let currentFrame = panel.frame

        let animDuration: TimeInterval
        let targetFrame: NSRect

        if entry.wasMoved {
            animDuration = 0.4
            let scaledW = currentFrame.width * 0.7
            let scaledH = currentFrame.height * 0.7
            targetFrame = NSRect(
                x: currentFrame.origin.x + (currentFrame.width - scaledW) / 2,
                y: currentFrame.origin.y + (currentFrame.height - scaledH) / 2,
                width: scaledW, height: scaledH
            )
        } else {
            animDuration = 0.7
            let offset = slideOutOffset()
            targetFrame = NSRect(
                x: currentFrame.origin.x + offset.x,
                y: currentFrame.origin.y + offset.y,
                width: currentFrame.width,
                height: currentFrame.height
            )
        }

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = animDuration
            ctx.timingFunction = CAMediaTimingFunction(name: .linear)
            ctx.allowsImplicitAnimation = true
            panel.animator().setFrame(targetFrame, display: true)
            panel.animator().alphaValue = 0
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + animDuration + 0.05) { [weak self] in
            guard let self else { return }
            panel.orderOut(nil)
            self.panels.removeAll { $0.id == id }
            self.repositionNonPinnedPanels()
            if self.panels.isEmpty {
                if let monitor = self.scrollMonitor {
                    NSEvent.removeMonitor(monitor)
                    self.scrollMonitor = nil
                }
                if let monitor = self.cursorMonitor {
                    NSEvent.removeMonitor(monitor)
                    self.cursorMonitor = nil
                }
            }
        }
    }

    // MARK: - Reposition

    private func repositionNonPinnedPanels() {
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.3
            ctx.timingFunction = CAMediaTimingFunction(controlPoints: 0.34, 1.2, 0.64, 1.0)
            var stackIndex = 0
            for entry in panels {
                if entry.isPinned { continue }
                let frame = stackFrame(at: stackIndex)
                entry.panel.animator().setFrame(frame, display: true)
                stackIndex += 1
            }
        }
    }

    // MARK: - Editor

    private func openEditor(image: NSImage, id: UUID) {
        dismissPanel(id: id)
        EditorWindow.shared.open(image: image, savePath: savePath)
    }

    // MARK: - Actions

    private func copyToClipboard(image: NSImage) {
        let exportImage = UserDefaults.standard.bool(forKey: "exportRetina") ? image : normalizeImageDPI(image)
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects([exportImage])
        let en = L10n.lang == "en"
        ToastManager.shared.show(
            title: en ? "Copied!" : "Copié !",
            subtitle: en ? "Image copied to clipboard" : "Image copiée dans le presse-papier"
        )
    }

    private func saveToDisk(image: NSImage) {
        guard let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff) else { return }

        let format = UserDefaults.standard.string(forKey: "imageFormat") ?? "png"
        let fileType: NSBitmapImageRep.FileType
        let ext: String

        switch format {
        case "jpeg":
            fileType = .jpeg; ext = "jpg"
        case "tiff":
            fileType = .tiff; ext = "tiff"
        default:
            fileType = .png; ext = "png"
        }

        let properties: [NSBitmapImageRep.PropertyKey: Any] = fileType == .jpeg
            ? [.compressionFactor: 0.9]
            : [:]

        guard let data = bitmap.representation(using: fileType, properties: properties) else { return }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let filename = "Screenshot_\(formatter.string(from: Date())).\(ext)"
        let url = savePath.appending(path: filename)

        try? data.write(to: url)
        let en = L10n.lang == "en"
        ToastManager.shared.show(
            title: en ? "Saved!" : "Sauvegardé !",
            subtitle: en ? "Saved to \(filename)" : "Sauvegardé dans \(filename)"
        )
    }
}
