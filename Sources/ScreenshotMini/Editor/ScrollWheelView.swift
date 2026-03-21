import SwiftUI
import AppKit

// MARK: - Scroll Phase

enum ScrollPhase { case scroll, zoom }

// MARK: - Scroll Wheel View (for pan/zoom via trackpad)

struct ScrollWheelView: NSViewRepresentable {
    let onScroll: (_ dx: CGFloat, _ dy: CGFloat, _ phase: ScrollPhase) -> Void

    func makeNSView(context: Context) -> ScrollWheelNSView {
        let view = ScrollWheelNSView()
        view.onScroll = onScroll
        return view
    }

    func updateNSView(_ nsView: ScrollWheelNSView, context: Context) {
        nsView.onScroll = onScroll
    }
}

final class ScrollWheelNSView: NSView {
    var onScroll: ((_ dx: CGFloat, _ dy: CGFloat, _ phase: ScrollPhase) -> Void)?

    override var acceptsFirstResponder: Bool { true }

    override func scrollWheel(with event: NSEvent) {
        if event.modifierFlags.contains(.command) {
            onScroll?(event.scrollingDeltaX, event.scrollingDeltaY, .zoom)
        } else {
            onScroll?(event.scrollingDeltaX, event.scrollingDeltaY, .scroll)
        }
    }

    override func magnify(with event: NSEvent) {
        onScroll?(0, event.magnification * 100, .zoom)
    }
}

// MARK: - Zoom Indicator

struct ZoomIndicator: View {
    let zoom: CGFloat
    let onZoomIn: () -> Void
    let onZoomOut: () -> Void
    let onReset: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Button { onZoomOut() } label: {
                Image(systemName: "minus")
                    .font(.system(size: 11, weight: .medium))
                    .frame(width: 22, height: 22)
            }.buttonStyle(.plain)

            Button { onReset() } label: {
                Text("\(Int(zoom * 100))%")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .frame(minWidth: 40)
            }.buttonStyle(.plain)

            Button { onZoomIn() } label: {
                Image(systemName: "plus")
                    .font(.system(size: 11, weight: .medium))
                    .frame(width: 22, height: 22)
            }.buttonStyle(.plain)
        }
        .padding(.horizontal, 8).padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(nsColor: .windowBackgroundColor).opacity(0.9))
                .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
        )
    }
}
