import AppKit
import SwiftUI

@MainActor
class ToastManager {
    static let shared = ToastManager()

    private var panel: NSPanel?

    func show(title: String, subtitle: String? = nil) {
        panel?.orderOut(nil)

        let isDark = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        let toastView = ToastView(title: title, subtitle: subtitle, isDark: isDark)
        let hostingView = NSHostingView(rootView: toastView)
        hostingView.setFrameSize(hostingView.fittingSize)

        let width = max(hostingView.fittingSize.width + 8, 180)
        let height = hostingView.fittingSize.height

        guard let screen = NSScreen.main else { return }
        let x = screen.frame.midX - width / 2
        let y = screen.visibleFrame.maxY - height - 10

        let toast = NSPanel(
            contentRect: NSRect(x: x, y: y, width: width, height: height),
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )
        toast.isFloatingPanel = true
        toast.level = .statusBar
        toast.hasShadow = true
        toast.isOpaque = false
        toast.backgroundColor = .clear
        toast.contentView = hostingView
        toast.isMovableByWindowBackground = false

        // Slide-down entrance
        toast.alphaValue = 0
        var frame = toast.frame
        frame.origin.y += 15
        toast.setFrame(frame, display: false)
        toast.orderFrontRegardless()

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.3
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            toast.animator().alphaValue = 1
            frame.origin.y -= 15
            toast.animator().setFrame(frame, display: true)
        }

        self.panel = toast

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in
            guard let self, let panel = self.panel, panel === toast else { return }
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.3
                ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
                panel.animator().alphaValue = 0
                var f = panel.frame
                f.origin.y += 10
                panel.animator().setFrame(f, display: true)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
                guard let self, self.panel === toast else { return }
                toast.orderOut(nil)
                self.panel = nil
            }
        }
    }

    // Legacy support
    func show(message: String, preview: String? = nil) {
        show(title: message, subtitle: preview)
    }
}

// MARK: - Toast View (adaptive light/dark)

struct ToastView: View {
    let title: String
    let subtitle: String?
    let isDark: Bool

    private var bgColor: Color { isDark ? Color.white : Color.black }
    private var textColor: Color { isDark ? .black : .white }
    private var subtitleColor: Color { isDark ? .black.opacity(0.5) : .white.opacity(0.6) }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(brandPurple)
                .font(.system(size: 18))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(textColor)

                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(subtitleColor)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(
            Capsule()
                .fill(bgColor.opacity(0.9))
                .shadow(color: .black.opacity(0.12), radius: 12, y: 4)
        )
    }
}
