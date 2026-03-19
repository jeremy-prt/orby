import SwiftUI
import AppKit

@MainActor
class ThumbnailPanel {
    static let shared = ThumbnailPanel()

    private var panel: NSPanel?
    private var dismissTimer: Timer?

    func show(image: NSImage) {
        dismiss()

        let thumbnailView = ThumbnailView(image: image) { [weak self] in
            self?.copyToClipboard(image: image)
        } onDismiss: { [weak self] in
            self?.dismiss()
        }

        let hostingView = NSHostingView(rootView: thumbnailView)
        hostingView.frame = NSRect(x: 0, y: 0, width: 320, height: 210)

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 210),
            styleMask: [.nonactivatingPanel, .hudWindow],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.hasShadow = true
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.contentView = hostingView
        panel.isMovableByWindowBackground = true

        // Position bottom-left
        if let screen = NSScreen.main {
            let x = screen.visibleFrame.origin.x + 20
            let y = screen.visibleFrame.origin.y + 20
            panel.setFrameOrigin(NSPoint(x: x, y: y))
        }

        panel.alphaValue = 0
        panel.orderFrontRegardless()

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.3
            panel.animator().alphaValue = 1
        }

        self.panel = panel

        dismissTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.dismiss()
            }
        }
    }

    func dismiss() {
        dismissTimer?.invalidate()
        dismissTimer = nil

        guard let panel else { return }
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.3
            panel.animator().alphaValue = 0
        }, completionHandler: {
            MainActor.assumeIsolated {
                panel.orderOut(nil)
                self.panel = nil
            }
        })
    }

    private func copyToClipboard(image: NSImage) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects([image])
        dismiss()
    }
}

struct ThumbnailView: View {
    let image: NSImage
    let onCopy: () -> Void
    let onDismiss: () -> Void

    @State private var isHovered = false

    var body: some View {
        VStack(spacing: 0) {
            // Screenshot preview
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: 300, maxHeight: 170)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .shadow(radius: 4)

            // Action bar
            HStack(spacing: 12) {
                Button(action: onCopy) {
                    Label("Copier", systemImage: "doc.on.doc")
                        .font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)

                Spacer()

                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 8)
            .padding(.horizontal, 4)
        }
        .padding(10)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}
