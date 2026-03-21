import SwiftUI
import AppKit

// MARK: - Editor View

struct EditorView: View {
    let originalImage: NSImage
    let savePath: URL
    let onClose: () -> Void

    @State private var currentImage: NSImage
    @State private var selectedTool: String? = "cursor"
    @StateObject private var history = AnnotationHistory()

    // Selection & hover
    @State private var selectedId: UUID? = nil
    @State private var hoveredId: UUID? = nil
    @State private var interaction: CanvasInteraction = .none

    // Crop
    @State private var cropStart: CGPoint? = nil
    @State private var cropEnd: CGPoint? = nil
    @State private var canvasSize: CGSize = .zero

    // Text editing
    @State private var editingTextId: UUID? = nil
    @State private var editingText: String = ""

    // Annotation defaults
    @State private var annotationColor: Color = .red
    @State private var annotationLineWidth: CGFloat = 3
    @State private var annotationFilled: Bool = false
    @State private var fontSize: CGFloat = 20
    @State private var arrowStyle: ArrowStyle = .thin

    private var selectedAnnotation: Annotation? {
        guard let id = selectedId else { return nil }
        return history.annotations.first { $0.id == id }
    }

    private var activeShapeTool: AnnotationShape? {
        switch selectedTool {
        case "rect": .rect; case "circle": .circle
        case "line": .line; case "arrow": .arrow
        case "text": .text; case "draw": .freehand
        default: nil
        }
    }

    init(originalImage: NSImage, savePath: URL, onClose: @escaping () -> Void) {
        self.originalImage = originalImage
        self.savePath = savePath
        self.onClose = onClose
        self._currentImage = State(initialValue: originalImage)
    }

    private let tools: [(icon: String, id: String, label: String, shortcut: String)] = [
        ("cursorarrow", "cursor", "Select", "V"),
        ("crop", "crop", "Crop", "C"),
        ("rectangle", "rect", "Rectangle", "R"),
        ("circle", "circle", "Ellipse", "O"),
        ("line.diagonal", "line", "Line", "L"),
        ("arrow.up.right", "arrow", "Arrow", "A"),
        ("character.textbox", "text", "Text", "T"),
        ("applepencil.gen1", "draw", "Draw", "D"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            canvas
        }
        .ignoresSafeArea()
        .background(
            Group {
                Button("") { history.undo(); syncSelection() }
                    .keyboardShortcut("z", modifiers: .command).hidden()
                Button("") { history.redo(); syncSelection() }
                    .keyboardShortcut("z", modifiers: [.command, .shift]).hidden()
                Button("") { deleteSelected() }
                    .keyboardShortcut(.delete, modifiers: []).hidden()
                Button("") { moveSelected(dx: 0, dy: -1) }
                    .keyboardShortcut(.upArrow, modifiers: []).hidden()
                Button("") { moveSelected(dx: 0, dy: 1) }
                    .keyboardShortcut(.downArrow, modifiers: []).hidden()
                Button("") { moveSelected(dx: -1, dy: 0) }
                    .keyboardShortcut(.leftArrow, modifiers: []).hidden()
                Button("") { moveSelected(dx: 1, dy: 0) }
                    .keyboardShortcut(.rightArrow, modifiers: []).hidden()
                // Tool shortcuts
                Button("") { selectTool("cursor") }.keyboardShortcut("v", modifiers: []).hidden()
                Button("") { selectTool("crop") }.keyboardShortcut("c", modifiers: []).hidden()
                Button("") { selectTool("rect") }.keyboardShortcut("r", modifiers: []).hidden()
                Button("") { selectTool("circle") }.keyboardShortcut("o", modifiers: []).hidden()
                Button("") { selectTool("line") }.keyboardShortcut("l", modifiers: []).hidden()
                Button("") { selectTool("arrow") }.keyboardShortcut("a", modifiers: []).hidden()
                Button("") { selectTool("text") }.keyboardShortcut("t", modifiers: []).hidden()
                Button("") { selectTool("draw") }.keyboardShortcut("d", modifiers: []).hidden()
                Button("") { selectTool(nil) }.keyboardShortcut(.escape, modifiers: []).hidden()
            }
            .frame(width: 0, height: 0)
        )
    }

    // MARK: - Toolbar (in titlebar)

    private var toolbar: some View {
        HStack(spacing: 2) {
            // Left padding for traffic light buttons
            Color.clear.frame(width: 70, height: 1)

            // Tools
            ForEach(tools, id: \.id) { tool in
                ToolbarButton(
                    icon: tool.icon,
                    label: tool.label,
                    shortcut: tool.shortcut,
                    isActive: selectedTool == tool.id
                ) {
                    selectTool(selectedTool == tool.id ? nil : tool.id)
                }
            }

            // Crop confirm
            if selectedTool == "crop" && cropStart != nil && cropEnd != nil {
                Divider().frame(height: 20).padding(.horizontal, 4)
                ToolbarButton(icon: "checkmark", label: "Apply", shortcut: "↩", isActive: false) { applyCrop() }
                ToolbarButton(icon: "xmark", label: "Cancel", shortcut: "Esc", isActive: false) { cancelTool() }
            }

            Divider().frame(height: 18).padding(.horizontal, 4)
            DragMeButton(image: currentImage)

            Spacer()

            // Undo/Redo
            ToolbarButton(icon: "arrow.uturn.backward", label: "Undo", shortcut: "⌘Z", isActive: false) {
                history.undo(); syncSelection()
            }
            ToolbarButton(icon: "arrow.uturn.forward", label: "Redo", shortcut: "⌘⇧Z", isActive: false) {
                history.redo(); syncSelection()
            }

            // Copy
            Button {
                let img = flattenAnnotations(history.annotations, onto: currentImage, canvasSize: canvasSize)
                NSPasteboard.general.clearContents()
                NSPasteboard.general.writeObjects([img])
                ToastManager.shared.show(message: L10n.lang == "en" ? "Copied!" : "Copié !")
            } label: {
                Image(systemName: "doc.on.doc").font(.system(size: 13)).frame(width: 28, height: 28)
            }.buttonStyle(.plain).help("Copy")

            // Save
            Button {
                let img = flattenAnnotations(history.annotations, onto: currentImage, canvasSize: canvasSize)
                saveImage(img, to: savePath)
                onClose()
            } label: {
                Text("Save").font(.system(size: 12, weight: .semibold)).foregroundStyle(.white)
                    .padding(.horizontal, 14).padding(.vertical, 5)
                    .background(RoundedRectangle(cornerRadius: 6).fill(brandPurple))
            }.buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
        .frame(height: 38)
    }

    // MARK: - Canvas

    private var canvas: some View {
        ZStack(alignment: .topTrailing) {
            Color(nsColor: .controlBackgroundColor).frame(maxWidth: .infinity, maxHeight: .infinity)

            GeometryReader { geo in
                let imgSize = currentImage.size
                let scale = min(geo.size.width / max(imgSize.width, 1), geo.size.height / max(imgSize.height, 1))
                let dw = imgSize.width * scale, dh = imgSize.height * scale
                let ox = (geo.size.width - dw) / 2, oy = (geo.size.height - dh) / 2

                ZStack(alignment: .topLeading) {
                    Image(nsImage: currentImage).resizable().aspectRatio(contentMode: .fit)
                        .frame(width: dw, height: dh)

                    // Annotations
                    ForEach(history.annotations) { ann in
                        AnnotationView(annotation: ann)
                    }.frame(width: dw, height: dh)

                    // Hover highlight
                    if let hId = hoveredId, hId != selectedId,
                       let hAnn = history.annotations.first(where: { $0.id == hId }) {
                        HoverOverlay(annotation: hAnn).frame(width: dw, height: dh)
                    }

                    // Drawing in progress
                    if case .drawing(let ann) = interaction {
                        AnnotationView(annotation: ann).frame(width: dw, height: dh)
                    }
                    if case .freehand(let pts) = interaction, pts.count >= 2 {
                        FreehandPreview(points: pts, color: annotationColor, lineWidth: annotationLineWidth)
                            .frame(width: dw, height: dh)
                    }

                    // Text editing overlay
                    if let editId = editingTextId,
                       let ann = history.annotations.first(where: { $0.id == editId }) {
                        TextEditingOverlay(
                            text: $editingText,
                            position: ann.start,
                            fontSize: ann.fontSize,
                            color: ann.color,
                            onCommit: { commitTextEdit() }
                        )
                        .frame(width: dw, height: dh)
                    }

                    // Selection
                    if let sel = selectedAnnotation, editingTextId != sel.id {
                        SelectionOverlay(annotation: sel).frame(width: dw, height: dh)
                    }

                    // Crop
                    if selectedTool == "crop", let s = cropStart, let e = cropEnd {
                        let r = normalizedRect(from: s, to: e)
                        Color.black.opacity(0.4).frame(width: dw, height: dh)
                            .mask(CropMask(rect: r, size: CGSize(width: dw, height: dh)))
                        Rectangle().stroke(Color.white, lineWidth: 2)
                            .frame(width: r.width, height: r.height).position(x: r.midX, y: r.midY)
                    }
                }
                .frame(width: dw, height: dh)
                .offset(x: ox, y: oy)
                .gesture(
                    DragGesture(minimumDistance: 1)
                        .onChanged { v in handleDrag(v, dw: dw, dh: dh, ox: ox, oy: oy) }
                        .onEnded { v in handleDragEnd(v, dw: dw, dh: dh, ox: ox, oy: oy) }
                )
                .onTapGesture { loc in handleTap(loc, dw: dw, dh: dh, ox: ox, oy: oy) }
                .onContinuousHover { phase in
                    switch phase {
                    case .active(let loc):
                        let pt = canvasPoint(loc, dw: dw, dh: dh, ox: ox, oy: oy)
                        updateCursor(at: pt)
                        hoveredId = history.annotations.last(where: { $0.hitTest(pt) })?.id
                    case .ended:
                        NSCursor.arrow.set()
                        hoveredId = nil
                    }
                }
                .onAppear { canvasSize = CGSize(width: dw, height: dh) }
            }

            // Annotation properties toolbar (top-right)
            if showPropertiesToolbar {
                AnnotationToolbar(
                    annotation: propertiesToolbarAnnotation,
                    onChangeColor: { c in setAnnotationColor(c); annotationColor = c },
                    onChangeLineWidth: { w in setAnnotationLineWidth(w); annotationLineWidth = w },
                    onChangeFillMode: { m in setAnnotationFillMode(m) },
                    onChangeFontSize: { s in setAnnotationFontSize(s); fontSize = s },
                    onChangeArrowStyle: { s in setAnnotationArrowStyle(s); arrowStyle = s },
                    onDeselect: { selectedId = nil; selectedTool = nil },
                    onDelete: { deleteSelected() }
                )
                .padding(8)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity).layoutPriority(1)
    }

    // MARK: - Gesture handling

    private func canvasPoint(_ location: CGPoint, dw: CGFloat, dh: CGFloat, ox: CGFloat, oy: CGFloat) -> CGPoint {
        CGPoint(x: max(0, min(location.x - ox, dw)), y: max(0, min(location.y - oy, dh)))
    }

    private func handleDrag(_ value: DragGesture.Value, dw: CGFloat, dh: CGFloat, ox: CGFloat, oy: CGFloat) {
        let start = canvasPoint(value.startLocation, dw: dw, dh: dh, ox: ox, oy: oy)
        let current = canvasPoint(value.location, dw: dw, dh: dh, ox: ox, oy: oy)
        canvasSize = CGSize(width: dw, height: dh)

        // Determine interaction on first move
        if case .none = interaction {
            if selectedTool == "crop" {
                cropStart = start; cropEnd = current; return
            }

            // Priority 1: Resize handle of selected annotation
            if let id = selectedId,
               let ann = history.annotations.first(where: { $0.id == id }),
               let handle = ann.handleAt(start) {
                history.save()
                interaction = .resizing(id, handle)
            }
            // Priority 2: Move the selected annotation if clicking on it
            else if let id = selectedId,
                    let ann = history.annotations.first(where: { $0.id == id }),
                    ann.hitTest(start) {
                history.save()
                interaction = .moving(id, start)
            }
            // Priority 3: Select + move another annotation if clicking on it (no tool required)
            else if let hit = history.annotations.last(where: { $0.hitTest(start) }),
                    activeShapeTool == nil {
                selectedId = hit.id
                history.save()
                interaction = .moving(hit.id, start)
            }
            // Priority 4: Draw new shape if tool is active
            else if selectedTool == "draw" {
                selectedId = nil
                commitTextIfNeeded()
                interaction = .freehand([start, current])
            }
            else if let shape = activeShapeTool, shape != .text {
                selectedId = nil
                commitTextIfNeeded()
                interaction = .drawing(Annotation(shape: shape, start: start, end: current,
                                                  color: annotationColor, lineWidth: annotationLineWidth, filled: annotationFilled,
                                                  arrowStyle: shape == .arrow ? arrowStyle : .thin))
            }
            // Priority 5: Deselect if clicking on nothing
            else {
                selectedId = nil
            }
        }

        // Continue interaction
        switch interaction {
        case .drawing(var ann):
            ann.end = current
            interaction = .drawing(ann)
        case .freehand(var pts):
            pts.append(current)
            interaction = .freehand(pts)
        case .moving(let id, let lastPt):
            if let idx = history.annotations.firstIndex(where: { $0.id == id }) {
                let dx = current.x - lastPt.x, dy = current.y - lastPt.y
                history.annotations[idx].move(by: CGSize(width: dx, height: dy))
                interaction = .moving(id, current)
            }
        case .resizing(let id, let handle):
            if let idx = history.annotations.firstIndex(where: { $0.id == id }) {
                history.annotations[idx].resize(handle: handle, to: current)
            }
        case .none:
            if selectedTool == "crop" { cropEnd = current }
        }
    }

    private func handleDragEnd(_ value: DragGesture.Value, dw: CGFloat, dh: CGFloat, ox: CGFloat, oy: CGFloat) {
        switch interaction {
        case .drawing(let ann):
            let dist = hypot(abs(ann.end.x - ann.start.x), abs(ann.end.y - ann.start.y))
            if dist > 5 {
                history.save()
                history.annotations.append(ann)
                selectedId = ann.id
            }
        case .freehand(let pts):
            if pts.count >= 3 {
                let xs = pts.map(\.x), ys = pts.map(\.y)
                let ann = Annotation(shape: .freehand,
                                     start: CGPoint(x: xs.min()!, y: ys.min()!),
                                     end: CGPoint(x: xs.max()!, y: ys.max()!),
                                     color: annotationColor, lineWidth: annotationLineWidth,
                                     points: pts)
                history.save()
                history.annotations.append(ann)
                selectedId = ann.id
            }
        case .moving, .resizing:
            break
        case .none:
            break
        }
        interaction = .none
    }

    private func handleTap(_ location: CGPoint, dw: CGFloat, dh: CGFloat, ox: CGFloat, oy: CGFloat) {
        let pt = canvasPoint(location, dw: dw, dh: dh, ox: ox, oy: oy)

        // Text tool: click to place text
        if selectedTool == "text" {
            commitTextIfNeeded()
            let ann = Annotation(shape: .text, start: pt, end: pt,
                                 color: annotationColor, fontSize: fontSize)
            history.save()
            history.annotations.append(ann)
            selectedId = ann.id
            editingTextId = ann.id
            editingText = ""
            return
        }

        // Double-click on text annotation to re-edit
        if let hit = history.annotations.last(where: { $0.hitTest(pt) }),
           hit.shape == .text, editingTextId == nil {
            selectedId = hit.id
            editingTextId = hit.id
            editingText = hit.text
            return
        }

        commitTextIfNeeded()

        if activeShapeTool == nil && selectedTool != "crop" {
            if let hit = history.annotations.last(where: { $0.hitTest(pt) }) {
                selectedId = hit.id
            } else {
                selectedId = nil
            }
        }
    }

    // MARK: - Helpers

    private func normalizedRect(from s: CGPoint, to e: CGPoint) -> CGRect {
        CGRect(x: min(s.x, e.x), y: min(s.y, e.y), width: abs(e.x - s.x), height: abs(e.y - s.y))
    }

    private func applyCrop() {
        guard let s = cropStart, let e = cropEnd else { return }
        let rect = normalizedRect(from: s, to: e)
        guard rect.width > 5 && rect.height > 5 else { return }
        if !history.annotations.isEmpty {
            currentImage = flattenAnnotations(history.annotations, onto: currentImage, canvasSize: canvasSize)
            history.annotations.removeAll()
        }
        currentImage = cropImage(currentImage, to: rect, canvasSize: canvasSize)
        cancelTool()
    }

    private func selectTool(_ tool: String?) {
        if editingTextId != nil { commitTextIfNeeded() }
        if tool == selectedTool { selectedTool = nil } else { selectedTool = tool }
        selectedId = nil; cropStart = nil; cropEnd = nil; interaction = .none
    }

    private func cancelTool() {
        commitTextIfNeeded()
        selectedTool = nil; cropStart = nil; cropEnd = nil; interaction = .none
    }

    private func deleteSelected() {
        guard let id = selectedId else { return }
        history.save()
        history.annotations.removeAll { $0.id == id }
        selectedId = nil
    }

    private func updateCursor(at point: CGPoint) {
        if selectedTool == "text" {
            NSCursor.iBeam.set()
            return
        }
        // If a tool is active, use crosshair
        if activeShapeTool != nil || selectedTool == "crop" {
            NSCursor.crosshair.set()
            return
        }

        // Check resize handles on selected annotation
        if let id = selectedId,
           let ann = history.annotations.first(where: { $0.id == id }),
           ann.handleAt(point) != nil {
            NSCursor.crosshair.set() // resize cursor
            return
        }

        // Check if hovering over any annotation
        if history.annotations.contains(where: { $0.hitTest(point) }) {
            NSCursor.openHand.set()
            return
        }

        NSCursor.arrow.set()
    }

    private func moveSelected(dx: CGFloat, dy: CGFloat) {
        guard let id = selectedId,
              let idx = history.annotations.firstIndex(where: { $0.id == id }) else { return }
        history.save()
        history.annotations[idx].move(by: CGSize(width: dx, height: dy))
    }

    private func syncSelection() {
        if let id = selectedId, !history.annotations.contains(where: { $0.id == id }) {
            selectedId = nil
        }
    }

    private var shouldShowFill: Bool {
        if let sel = selectedAnnotation { return sel.shape == .rect || sel.shape == .circle }
        return selectedTool == "rect" || selectedTool == "circle"
    }

    private var isFilled: Bool { selectedAnnotation?.filled ?? annotationFilled }

    private var showPropertiesToolbar: Bool {
        if selectedId != nil { return true }
        if let tool = selectedTool, tool != "crop" && tool != "cursor" { return true }
        return false
    }

    private var propertiesToolbarAnnotation: Annotation {
        if let sel = selectedAnnotation { return sel }
        // Build a dummy annotation from current defaults for toolbar display
        let shape: AnnotationShape = switch selectedTool {
            case "rect": .rect; case "circle": .circle
            case "line": .line; case "arrow": .arrow
            case "text": .text; case "draw": .freehand
            default: .rect
        }
        return Annotation(shape: shape, start: .zero, end: .zero,
                          color: annotationColor, lineWidth: annotationLineWidth,
                          fontSize: fontSize, arrowStyle: arrowStyle)
    }

    private var isTextContext: Bool {
        if let sel = selectedAnnotation { return sel.shape == .text }
        return selectedTool == "text"
    }

    private func commitTextIfNeeded() {
        guard let id = editingTextId else { return }
        if editingText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            history.annotations.removeAll { $0.id == id }
            selectedId = nil
        } else if let idx = history.annotations.firstIndex(where: { $0.id == id }) {
            history.annotations[idx].text = editingText
        }
        editingTextId = nil
        editingText = ""
    }

    private func commitTextEdit() {
        commitTextIfNeeded()
        selectedTool = nil
    }

    private func adjustFontSize(_ delta: CGFloat) {
        if let id = selectedId, let idx = history.annotations.firstIndex(where: { $0.id == id }) {
            history.save()
            history.annotations[idx].fontSize = max(8, min(120, history.annotations[idx].fontSize + delta))
        } else {
            fontSize = max(8, min(120, fontSize + delta))
        }
    }

    private func setAnnotationColor(_ color: Color) {
        annotationColor = color
        guard let id = selectedId, let idx = history.annotations.firstIndex(where: { $0.id == id }) else { return }
        history.save()
        history.annotations[idx].color = color
    }

    private func setAnnotationLineWidth(_ width: CGFloat) {
        annotationLineWidth = width
        guard let id = selectedId, let idx = history.annotations.firstIndex(where: { $0.id == id }) else { return }
        history.save()
        history.annotations[idx].lineWidth = width
    }

    private func setAnnotationFillMode(_ mode: FillMode) {
        guard let id = selectedId, let idx = history.annotations.firstIndex(where: { $0.id == id }) else { return }
        history.save()
        switch mode {
        case .outline:
            history.annotations[idx].filled = false
            history.annotations[idx].solidFill = false
        case .semiFilled:
            history.annotations[idx].filled = true
            history.annotations[idx].solidFill = false
        case .solidFilled:
            history.annotations[idx].filled = true
            history.annotations[idx].solidFill = true
        }
    }

    private func setAnnotationFontSize(_ size: CGFloat) {
        fontSize = size
        guard let id = selectedId, let idx = history.annotations.firstIndex(where: { $0.id == id }) else { return }
        history.save()
        history.annotations[idx].fontSize = size
    }

    private func setAnnotationArrowStyle(_ style: ArrowStyle) {
        arrowStyle = style
        guard let id = selectedId, let idx = history.annotations.firstIndex(where: { $0.id == id }) else { return }
        history.save()
        history.annotations[idx].arrowStyle = style
    }

    private func adjustLineWidth(_ delta: CGFloat) {
        if let id = selectedId, let idx = history.annotations.firstIndex(where: { $0.id == id }) {
            history.save()
            history.annotations[idx].lineWidth = max(1, min(20, history.annotations[idx].lineWidth + delta))
        } else {
            annotationLineWidth = max(1, min(20, annotationLineWidth + delta))
        }
    }

    private func toggleFill() {
        if let id = selectedId, let idx = history.annotations.firstIndex(where: { $0.id == id }) {
            history.save()
            history.annotations[idx].filled.toggle()
        } else {
            annotationFilled.toggle()
        }
    }
}
