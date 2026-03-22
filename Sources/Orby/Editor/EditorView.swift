import SwiftUI
import AppKit
import CoreImage

// MARK: - Custom rotate cursor

@MainActor let rotateCursor: NSCursor = {
    let size: CGFloat = 20
    let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .semibold)
    guard let symbol = NSImage(systemSymbolName: "arrow.trianglehead.clockwise.rotate.90",
                               accessibilityDescription: nil)?
            .withSymbolConfiguration(config) else {
        return NSCursor.arrow
    }

    let image = NSImage(size: NSSize(width: size, height: size), flipped: false) { _ in
        guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
        let symbolSize = symbol.size
        let x = (size - symbolSize.width) / 2
        let y = (size - symbolSize.height) / 2
        let drawRect = CGRect(x: x, y: y, width: symbolSize.width, height: symbolSize.height)

        let outline: CGFloat = 1.0
        let offsets: [(CGFloat, CGFloat)] = [
            (-outline, 0), (outline, 0), (0, -outline), (0, outline),
            (-outline, -outline), (outline, -outline), (-outline, outline), (outline, outline)
        ]
        symbol.lockFocus()
        let rep = NSBitmapImageRep(focusedViewRect: NSRect(origin: .zero, size: symbolSize))
        symbol.unlockFocus()

        if let rep = rep, let whiteImg = CIFilter(name: "CIColorMatrix", parameters: [
            kCIInputImageKey: CIImage(bitmapImageRep: rep)!,
            "inputRVector": CIVector(x: 0, y: 0, z: 0, w: 0),
            "inputGVector": CIVector(x: 0, y: 0, z: 0, w: 0),
            "inputBVector": CIVector(x: 0, y: 0, z: 0, w: 0),
            "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 1),
            "inputBiasVector": CIVector(x: 1, y: 1, z: 1, w: 0)
        ])?.outputImage {
            let ciCtx = CIContext()
            if let cg = ciCtx.createCGImage(whiteImg, from: whiteImg.extent) {
                for (dx, dy) in offsets {
                    ctx.saveGState()
                    ctx.translateBy(x: dx, y: dy)
                    ctx.draw(cg, in: drawRect)
                    ctx.restoreGState()
                }
            }
        }

        symbol.draw(in: drawRect, from: .zero, operation: .sourceOver, fraction: 1.0)
        return true
    }
    return NSCursor(image: image, hotSpot: NSPoint(x: size / 2, y: size / 2))
}()

// MARK: - Editor View

struct EditorView: View {
    let originalImage: NSImage
    let savePath: URL
    let onClose: () -> Void

    @State var currentImage: NSImage
    @State var imageUndoStack: [(NSImage, [Annotation])] = []
    @State var selectedTool: String? = "cursor"
    @StateObject var history = AnnotationHistory()

    // Selection & hover
    @State var selectedIds: Set<UUID> = []
    @State var hoveredId: UUID? = nil
    @State var interaction: CanvasInteraction = .none

    // Crop
    @State var cropStart: CGPoint? = nil
    @State var cropEnd: CGPoint? = nil
    @State var canvasSize: CGSize = .zero

    // Zoom & pan
    @State var zoomLevel: CGFloat = 1.0
    @State var panOffset: CGSize = .zero
    @State var scrollMonitor: Any? = nil
    @State var magnifyMonitor: Any? = nil

    // Text editing
    @State var editingTextId: UUID? = nil
    @State var editingText: String = ""

    // Copy/paste clipboard
    @State var clipboard: Annotation? = nil

    // Annotation defaults
    @State var annotationColor: Color = {
        if let hex = UserDefaults.standard.string(forKey: "lastAnnotationColor"),
           let c = Color.fromHex(hex) { return c }
        return .red
    }()
    @State var annotationLineWidth: CGFloat = 3
    @State var annotationFilled: Bool = false
    @State var annotationSolidFill: Bool = false
    @State var fontSize: CGFloat = 20
    @State var arrowStyle: ArrowStyle = .thin
    @State var textHasBackground: Bool = true
    @State var blurRadius: CGFloat = 10
    @State var blurStyle: BlurStyle = .gaussian

    // Numbered annotation counter
    @State var nextNumber: Int = 1

    // Background
    @State var bgConfig = BackgroundConfig()

    var selectedAnnotations: [Annotation] {
        history.annotations.filter { selectedIds.contains($0.id) }
    }

    var selectedAnnotation: Annotation? {
        selectedAnnotations.first
    }

    var activeShapeTool: AnnotationShape? {
        switch selectedTool {
        case "rect": .rect; case "circle": .circle
        case "line": .line; case "arrow": .arrow
        case "text": .text; case "draw": .freehand
        case "blur": .blur; case "numbered": .numbered
        default: nil
        }
    }

    var dominantBackgroundColor: Color {
        let nsColor = extractDominantColor(from: currentImage)
        return Color(nsColor: nsColor).opacity(0.95)
    }

    init(originalImage: NSImage, savePath: URL, onClose: @escaping () -> Void) {
        self.originalImage = originalImage
        self.savePath = savePath
        self.onClose = onClose
        self._currentImage = State(initialValue: originalImage)
    }

    let tools: [(icon: String, id: String, label: String, shortcut: String)] = [
        ("cursorarrow", "cursor", "Select", "V"),
        ("crop", "crop", "Crop", "C"),
        ("rectangle", "rect", "Rectangle", "R"),
        ("circle", "circle", "Ellipse", "O"),
        ("line.diagonal", "line", "Line", "L"),
        ("arrow.up.right", "arrow", "Arrow", "A"),
        ("character.textbox", "text", "Text", "T"),
        ("applepencil.gen1", "draw", "Draw", "D"),
        ("eye.slash", "blur", "Blur", "B"),
        ("number.circle", "numbered", "Number", "N"),
        ("photo.artframe", "background", "Background", "F"),
    ]

    var body: some View {
        ZStack(alignment: .top) {
            canvas.padding(.top, 38).clipped()
            toolbar.zIndex(1)
        }
        .ignoresSafeArea()
        .background(
            Group {
                Button("") { undoAction() }
                    .keyboardShortcut("z", modifiers: .command).hidden()
                Button("") { history.redo(); syncSelection() }
                    .keyboardShortcut("z", modifiers: [.command, .shift]).hidden()
                Button("") { deleteSelectedAnnotations() }
                    .keyboardShortcut(.delete, modifiers: []).hidden()
                if editingTextId == nil {
                    Button("") { moveSelectedAnnotations(dx: 0, dy: -1) }
                        .keyboardShortcut(.upArrow, modifiers: []).hidden()
                    Button("") { moveSelectedAnnotations(dx: 0, dy: 1) }
                        .keyboardShortcut(.downArrow, modifiers: []).hidden()
                    Button("") { moveSelectedAnnotations(dx: -1, dy: 0) }
                        .keyboardShortcut(.leftArrow, modifiers: []).hidden()
                    Button("") { moveSelectedAnnotations(dx: 1, dy: 0) }
                        .keyboardShortcut(.rightArrow, modifiers: []).hidden()
                }
                Button("") { selectTool("cursor") }.keyboardShortcut("v", modifiers: []).hidden()
                Button("") { selectTool("crop") }.keyboardShortcut("c", modifiers: []).hidden()
                Button("") { selectTool("rect") }.keyboardShortcut("r", modifiers: []).hidden()
                Button("") { selectTool("circle") }.keyboardShortcut("o", modifiers: []).hidden()
                Button("") { selectTool("line") }.keyboardShortcut("l", modifiers: []).hidden()
                Button("") { selectTool("arrow") }.keyboardShortcut("a", modifiers: []).hidden()
                Button("") { selectTool("text") }.keyboardShortcut("t", modifiers: []).hidden()
                Button("") { selectTool("draw") }.keyboardShortcut("d", modifiers: []).hidden()
                Button("") { selectTool("blur") }.keyboardShortcut("b", modifiers: []).hidden()
                Button("") { selectTool("numbered") }.keyboardShortcut("n", modifiers: []).hidden()
                Button("") { selectTool("background") }.keyboardShortcut("f", modifiers: []).hidden()
                Button("") { selectTool(nil) }.keyboardShortcut(.escape, modifiers: []).hidden()
                Button("") { zoomIn() }.keyboardShortcut("+", modifiers: .command).hidden()
                Button("") { zoomIn() }.keyboardShortcut("=", modifiers: .command).hidden()
                Button("") { zoomOut() }.keyboardShortcut("-", modifiers: .command).hidden()
                Button("") { zoomReset() }.keyboardShortcut("0", modifiers: .command).hidden()
                Button("") { copySelectedAnnotation() }.keyboardShortcut("c", modifiers: .command).hidden()
                Button("") { pasteAnnotation() }.keyboardShortcut("v", modifiers: .command).hidden()
                Button("") { quickSave() }.keyboardShortcut("s", modifiers: .command).hidden()
            }
            .frame(width: 0, height: 0)
        )
    }
}
