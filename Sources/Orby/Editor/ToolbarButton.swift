import SwiftUI
import AppKit

// MARK: - Native tooltip via NSView (not clipped, doesn't block clicks)

struct NativeTooltip: NSViewRepresentable {
    let tooltip: String

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        view.toolTip = tooltip
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        nsView.toolTip = tooltip
    }
}

// MARK: - Hover highlight modifier for plain toolbar buttons

struct ToolbarHover: ViewModifier {
    @State private var isHovered = false

    func body(content: Content) -> some View {
        content
            .background(RoundedRectangle(cornerRadius: 6).fill(isHovered ? brandPurple.opacity(0.1) : Color.clear))
            .onHover { isHovered = $0 }
    }
}

extension View {
    func toolbarHover() -> some View { modifier(ToolbarHover()) }
}

// MARK: - Toolbar Button with native tooltip

struct ToolbarButton: View {
    let icon: String
    let label: String
    let shortcut: String
    let isActive: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .frame(width: 30, height: 28)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isActive ? brandPurple.opacity(0.2) :
                              isHovered ? brandPurple.opacity(0.1) : Color.clear)
                )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .background(NativeTooltip(tooltip: "\(label) (\(shortcut))"))
    }
}
