import SwiftUI
import AppKit

// MARK: - Multiline Text Field (NSViewRepresentable)

struct MultilineTextField: NSViewRepresentable {
    @Binding var text: String
    let fontSize: CGFloat
    let textColor: NSColor
    let onCommit: () -> Void

    func makeNSView(context: Context) -> NSTextField {
        let field = NSTextField()
        field.isBezeled = false
        field.drawsBackground = false
        field.isEditable = true
        field.isSelectable = true
        field.focusRingType = .none
        field.lineBreakMode = .byClipping
        field.maximumNumberOfLines = 0
        field.cell?.wraps = false
        field.cell?.isScrollable = false
        field.font = NSFont.systemFont(ofSize: fontSize, weight: .medium)
        field.textColor = textColor
        field.delegate = context.coordinator
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            field.window?.makeFirstResponder(field)
        }
        return field
    }

    func updateNSView(_ field: NSTextField, context: Context) {
        if field.stringValue != text { field.stringValue = text }
        field.font = NSFont.systemFont(ofSize: fontSize, weight: .medium)
        field.textColor = textColor
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject, NSTextFieldDelegate {
        let parent: MultilineTextField
        init(_ parent: MultilineTextField) { self.parent = parent }

        func controlTextDidChange(_ obj: Notification) {
            if let field = obj.object as? NSTextField {
                parent.text = field.stringValue
            }
        }

        func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                if NSEvent.modifierFlags.contains(.shift) {
                    textView.insertNewlineIgnoringFieldEditor(nil)
                    return true
                }
                parent.onCommit()
                return true
            }
            return false
        }
    }
}

// MARK: - Text Editing Overlay

struct TextEditingOverlay: View {
    @Binding var text: String
    let annotation: Annotation
    var canvasSize: CGSize = .zero
    var zoomLevel: CGFloat = 1.0
    let onCommit: () -> Void

    private var rotationAnchor: UnitPoint {
        guard canvasSize.width > 0 && canvasSize.height > 0 else { return .center }
        let r = annotation.boundingRect
        return UnitPoint(x: r.midX / canvasSize.width, y: r.midY / canvasSize.height)
    }

    private var liveWidth: CGFloat {
        guard !text.isEmpty else { return 30 }
        let font = NSFont.systemFont(ofSize: annotation.fontSize, weight: .medium)
        let lines = text.components(separatedBy: "\n")
        let maxWidth = lines.map { ($0 as NSString).size(withAttributes: [.font: font]).width }.max() ?? 0
        return maxWidth + 10
    }

    private var liveHeight: CGFloat {
        let lineCount = max(1, text.components(separatedBy: "\n").count)
        return (annotation.fontSize * 1.3) * CGFloat(lineCount) + 8
    }

    var body: some View {
        let textColor: Color = annotation.textHasBackground
            ? contrastTextColor(for: annotation.color) : annotation.color
        let editW = max(liveWidth, 40) * zoomLevel
        let editH = liveHeight * zoomLevel

        ZStack(alignment: .topLeading) {
            Color.clear
            ZStack(alignment: .leading) {
                if annotation.textHasBackground {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(annotation.color)
                }
                RoundedRectangle(cornerRadius: 4)
                    .stroke(brandPurple.opacity(0.6), style: StrokeStyle(lineWidth: 1.5 / zoomLevel, dash: [4, 2]))
                MultilineTextField(
                    text: $text,
                    fontSize: annotation.fontSize * zoomLevel,
                    textColor: NSColor(textColor),
                    onCommit: onCommit
                )
                .padding(.horizontal, 5)
                .padding(.vertical, 4)
            }
            .frame(width: editW, height: editH)
            .position(x: annotation.start.x * zoomLevel + editW / 2,
                      y: annotation.start.y * zoomLevel + editH / 2)
        }
        .scaleEffect(zoomLevel, anchor: rotationAnchor)
        .rotationEffect(.degrees(annotation.rotation), anchor: rotationAnchor)
        .allowsHitTesting(true)
    }

    private func contrastTextColor(for color: Color) -> Color {
        let nsColor = NSColor(color).usingColorSpace(.deviceRGB) ?? NSColor(color)
        let r = nsColor.redComponent, g = nsColor.greenComponent, b = nsColor.blueComponent
        let luminance = 0.299 * r + 0.587 * g + 0.114 * b
        return luminance > 0.6 ? .black : .white
    }
}
