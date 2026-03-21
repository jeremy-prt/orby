import SwiftUI
import AppKit

// MARK: - Hover Overlay

struct HoverOverlay: View {
    let annotation: Annotation
    var canvasSize: CGSize = .zero

    private var rotationAnchor: UnitPoint {
        guard canvasSize.width > 0 && canvasSize.height > 0 else { return .center }
        let r = annotation.boundingRect
        return UnitPoint(x: r.midX / canvasSize.width, y: r.midY / canvasSize.height)
    }

    var body: some View {
        Canvas { ctx, _ in
            let r = annotation.boundingRect.insetBy(dx: -3, dy: -3)
            ctx.stroke(Path(r), with: .color(brandPurple.opacity(0.5)),
                       style: StrokeStyle(lineWidth: 2, dash: [4, 3]))
        }
        .allowsHitTesting(false)
        .rotationEffect(.degrees(annotation.rotation), anchor: rotationAnchor)
    }
}

// MARK: - Selection Overlay

struct SelectionOverlay: View {
    let annotation: Annotation
    var canvasSize: CGSize = .zero

    /// Anchor point for rotation: annotation center as UnitPoint within the canvas frame
    private var rotationAnchor: UnitPoint {
        guard canvasSize.width > 0 && canvasSize.height > 0 else { return .center }
        let r = annotation.boundingRect
        return UnitPoint(x: r.midX / canvasSize.width, y: r.midY / canvasSize.height)
    }

    var body: some View {
        Canvas { ctx, _ in
            let r = annotation.boundingRect.insetBy(dx: -5, dy: -5)
            ctx.stroke(Path(r), with: .color(brandPurple),
                       style: StrokeStyle(lineWidth: 1.5, dash: [5, 3]))
            let hs: CGFloat = 9
            for c in [CGPoint(x: r.minX, y: r.minY), CGPoint(x: r.maxX, y: r.minY),
                       CGPoint(x: r.minX, y: r.maxY), CGPoint(x: r.maxX, y: r.maxY)] {
                let hr = CGRect(x: c.x - hs/2, y: c.y - hs/2, width: hs, height: hs)
                ctx.fill(Path(hr), with: .color(.white))
                ctx.stroke(Path(hr), with: .color(brandPurple), lineWidth: 2)
            }
            // Midpoint handle for arrows (control point or default midpoint)
            if annotation.shape == .arrow {
                let mp = annotation.controlPoint ?? CGPoint(
                    x: (annotation.start.x + annotation.end.x) / 2,
                    y: (annotation.start.y + annotation.end.y) / 2
                )
                let hr = CGRect(x: mp.x - hs/2, y: mp.y - hs/2, width: hs, height: hs)
                ctx.fill(Path(hr), with: .color(.white))
                ctx.stroke(Path(hr), with: .color(brandPurple), lineWidth: 2)
            }

            // Rotation handle: circle 25px above top-center, connected by a thin line
            let topCenter = CGPoint(x: r.midX, y: r.minY)
            let rotHandle = CGPoint(x: r.midX, y: r.minY - 25)

            // Connecting line
            var line = Path()
            line.move(to: topCenter)
            line.addLine(to: rotHandle)
            ctx.stroke(line, with: .color(brandPurple.opacity(0.6)), lineWidth: 1)

            // Rotation circle handle
            let rotSize: CGFloat = 10
            let rotRect = CGRect(x: rotHandle.x - rotSize / 2, y: rotHandle.y - rotSize / 2,
                                 width: rotSize, height: rotSize)
            ctx.fill(Path(ellipseIn: rotRect), with: .color(brandPurple))
            ctx.stroke(Path(ellipseIn: rotRect), with: .color(.white), lineWidth: 1.5)
        }
        .allowsHitTesting(false)
        .rotationEffect(.degrees(annotation.rotation), anchor: rotationAnchor)
    }
}

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
        field.lineBreakMode = .byWordWrapping
        field.maximumNumberOfLines = 0
        field.cell?.wraps = true
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
        let editW = max(liveWidth, 40)
        let editH = liveHeight

        ZStack(alignment: .topLeading) {
            Color.clear
            ZStack(alignment: .leading) {
                if annotation.textHasBackground {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(annotation.color)
                }
                RoundedRectangle(cornerRadius: 4)
                    .stroke(brandPurple.opacity(0.6), style: StrokeStyle(lineWidth: 1.5, dash: [4, 2]))
                MultilineTextField(
                    text: $text,
                    fontSize: annotation.fontSize,
                    textColor: NSColor(textColor),
                    onCommit: onCommit
                )
                .padding(.horizontal, 5)
                .padding(.vertical, 4)
            }
            .frame(width: editW, height: editH)
            .position(x: annotation.start.x + editW / 2,
                      y: annotation.start.y + editH / 2)
        }
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

// MARK: - Crop Toolbar

struct CropToolbar: View {
    let onApply: () -> Void
    let onCancel: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Button { onCancel() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.red)
                    .frame(width: 28, height: 28)
                    .background(RoundedRectangle(cornerRadius: 6).fill(.red.opacity(0.15)))
            }.buttonStyle(.plain)

            Button { onApply() } label: {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark").font(.system(size: 12, weight: .bold))
                    Text("Apply").font(.system(size: 12, weight: .semibold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(RoundedRectangle(cornerRadius: 6).fill(brandPurple))
            }.buttonStyle(.plain)
        }
        .padding(.horizontal, 8).padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(nsColor: .windowBackgroundColor))
                .shadow(color: .black.opacity(0.15), radius: 6, y: 2)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.2), lineWidth: 0.5))
        )
    }
}

// MARK: - Crop Mask

struct CropMask: Shape {
    let rect: CGRect; let size: CGSize
    func path(in frame: CGRect) -> Path {
        var p = Path(); p.addRect(CGRect(origin: .zero, size: size)); p.addRect(rect); return p
    }
    var body: some View { self.fill(style: FillStyle(eoFill: true)) }
}
