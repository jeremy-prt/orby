import SwiftUI
import AppKit
import CoreImage

// MARK: - Custom rotate cursor

@MainActor private let rotateCursor: NSCursor = {
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

        // White outline: draw the symbol slightly offset in 8 directions
        let outline: CGFloat = 1.0
        let offsets: [(CGFloat, CGFloat)] = [
            (-outline, 0), (outline, 0), (0, -outline), (0, outline),
            (-outline, -outline), (outline, -outline), (-outline, outline), (outline, outline)
        ]
        symbol.lockFocus()
        let rep = NSBitmapImageRep(focusedViewRect: NSRect(origin: .zero, size: symbolSize))
        symbol.unlockFocus()

        // Tint white for outline
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

        // Draw black symbol on top
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

    @State private var currentImage: NSImage
    @State private var imageUndoStack: [(NSImage, [Annotation])] = []
    @State private var selectedTool: String? = "cursor"
    @StateObject private var history = AnnotationHistory()

    // Selection & hover
    @State private var selectedIds: Set<UUID> = []
    @State private var hoveredId: UUID? = nil
    @State private var interaction: CanvasInteraction = .none

    // Crop
    @State private var cropStart: CGPoint? = nil
    @State private var cropEnd: CGPoint? = nil
    @State private var canvasSize: CGSize = .zero

    // Zoom & pan
    @State private var zoomLevel: CGFloat = 1.0
    @State private var panOffset: CGSize = .zero
    @State private var scrollMonitor: Any? = nil
    @State private var magnifyMonitor: Any? = nil

    // Text editing
    @State private var editingTextId: UUID? = nil
    @State private var editingText: String = ""

    // Copy/paste clipboard
    @State private var clipboard: Annotation? = nil

    // Annotation defaults
    @State private var annotationColor: Color = {
        if let hex = UserDefaults.standard.string(forKey: "lastAnnotationColor"),
           let c = Color.fromHex(hex) { return c }
        return .red
    }()
    @State private var annotationLineWidth: CGFloat = 3
    @State private var annotationFilled: Bool = false
    @State private var annotationSolidFill: Bool = false
    @State private var fontSize: CGFloat = 20
    @State private var arrowStyle: ArrowStyle = .thin
    @State private var textHasBackground: Bool = true
    @State private var blurRadius: CGFloat = 10
    @State private var blurStyle: BlurStyle = .gaussian

    // Numbered annotation counter
    @State private var nextNumber: Int = 1

    // Background
    @State private var bgConfig = BackgroundConfig()

    private var selectedAnnotations: [Annotation] {
        history.annotations.filter { selectedIds.contains($0.id) }
    }

    private var selectedAnnotation: Annotation? {
        selectedAnnotations.first
    }

    private var activeShapeTool: AnnotationShape? {
        switch selectedTool {
        case "rect": .rect; case "circle": .circle
        case "line": .line; case "arrow": .arrow
        case "text": .text; case "draw": .freehand
        case "blur": .blur; case "numbered": .numbered
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
        ("eye.slash", "blur", "Blur", "B"),
        ("number.circle", "numbered", "Number", "N"),
        ("photo.artframe", "background", "Background", "F"),
    ]

    var body: some View {
        ZStack(alignment: .top) {
            canvas.padding(.top, 38)
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
                Button("") { if editingTextId == nil { moveSelectedAnnotations(dx: 0, dy: -1) } }
                    .keyboardShortcut(.upArrow, modifiers: []).hidden()
                Button("") { if editingTextId == nil { moveSelectedAnnotations(dx: 0, dy: 1) } }
                    .keyboardShortcut(.downArrow, modifiers: []).hidden()
                Button("") { if editingTextId == nil { moveSelectedAnnotations(dx: -1, dy: 0) } }
                    .keyboardShortcut(.leftArrow, modifiers: []).hidden()
                Button("") { if editingTextId == nil { moveSelectedAnnotations(dx: 1, dy: 0) } }
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
                Button("") { selectTool("blur") }.keyboardShortcut("b", modifiers: []).hidden()
                Button("") { selectTool("numbered") }.keyboardShortcut("n", modifiers: []).hidden()
                Button("") { selectTool("background") }.keyboardShortcut("f", modifiers: []).hidden()
                Button("") { selectTool(nil) }.keyboardShortcut(.escape, modifiers: []).hidden()
                // Zoom
                Button("") { zoomIn() }.keyboardShortcut("+", modifiers: .command).hidden()
                Button("") { zoomIn() }.keyboardShortcut("=", modifiers: .command).hidden()
                Button("") { zoomOut() }.keyboardShortcut("-", modifiers: .command).hidden()
                Button("") { zoomReset() }.keyboardShortcut("0", modifiers: .command).hidden()
                // Copy/Paste annotations
                Button("") { copySelectedAnnotation() }.keyboardShortcut("c", modifiers: .command).hidden()
                Button("") { pasteAnnotation() }.keyboardShortcut("v", modifiers: .command).hidden()
                // Save (⌘S) — save without closing
                Button("") { quickSave() }.keyboardShortcut("s", modifiers: .command).hidden()
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

            Divider().frame(height: 18).padding(.horizontal, 4)
            DragMeButton(image: currentImage)
                .frame(width: 28, height: 28)
                .background(NativeTooltip(tooltip: "Drag to export"))

            Spacer()

            // Undo/Redo
            ToolbarButton(icon: "arrow.uturn.backward", label: "Undo", shortcut: "⌘Z", isActive: false) {
                undoAction()
            }
            ToolbarButton(icon: "arrow.uturn.forward", label: "Redo", shortcut: "⌘⇧Z", isActive: false) {
                history.redo(); syncSelection()
            }

            Divider().frame(height: 18).padding(.horizontal, 2)

            // Zoom
            Button { zoomOut() } label: {
                Image(systemName: "minus.magnifyingglass").font(.system(size: 12))
                    .frame(width: 24, height: 28)
            }.buttonStyle(.plain).toolbarHover().background(NativeTooltip(tooltip: "Zoom out (⌘-)"))

            Button { zoomReset() } label: {
                Text("\(Int(zoomLevel * 100))%")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .frame(minWidth: 36, minHeight: 28)
            }.buttonStyle(.plain).toolbarHover().background(NativeTooltip(tooltip: "Reset zoom (⌘0)"))

            Button { zoomIn() } label: {
                Image(systemName: "plus.magnifyingglass").font(.system(size: 12))
                    .frame(width: 24, height: 28)
            }.buttonStyle(.plain).toolbarHover().background(NativeTooltip(tooltip: "Zoom in (⌘+)"))

            Divider().frame(height: 18).padding(.horizontal, 2)

            // Copy
            Button {
                var img = buildFinalImage()
                if !UserDefaults.standard.bool(forKey: "exportRetina") { img = normalizeImageDPI(img) }
                NSPasteboard.general.clearContents()
                NSPasteboard.general.writeObjects([img])
                let en = L10n.lang == "en"
                ToastManager.shared.show(
                    title: en ? "Copied!" : "Copié !",
                    subtitle: en ? "Image copied to clipboard" : "Image copiée dans le presse-papier"
                )
                onClose()
            } label: {
                Image(systemName: "doc.on.doc").font(.system(size: 13)).frame(width: 28, height: 28)
            }.buttonStyle(.plain).toolbarHover().help(L10n.editorCopy)

            // Share
            ShareButton {
                var img = buildFinalImage()
                if !UserDefaults.standard.bool(forKey: "exportRetina") { img = normalizeImageDPI(img) }
                return img
            }

            // Save
            Button {
                let img = buildFinalImage()
                saveImage(img, to: savePath)
                onClose()
            } label: {
                Text(L10n.editorSave).font(.system(size: 12, weight: .semibold)).foregroundStyle(.white)
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
                // STABLE dw/dh — never affected by background toggle
                let fitScale = min(geo.size.width / max(imgSize.width, 1),
                                   geo.size.height / max(imgSize.height, 1))
                let dw = imgSize.width * fitScale, dh = imgSize.height * fitScale
                let ox = (geo.size.width - dw) / 2
                let oy = (geo.size.height - dh) / 2

                // Background: visual shrink so canvas + padding fits in same area
                let padPct = bgConfig.enabled ? bgConfig.padding / 100.0 : 0
                let bgShrink = bgConfig.enabled ? 1.0 / (1.0 + 2.0 * padPct) : 1.0
                let cornerPx = bgConfig.enabled
                    ? bgConfig.cornerRadius / 100.0 * min(dw * bgShrink, dh * bgShrink) / 2 : 0
                let shadowPx = bgConfig.enabled ? dw * (1 - bgShrink) / 2 : 0

                ZStack {
                    // Background gradient/color (fills dw x dh, visible around the shrunk canvas)
                    if bgConfig.enabled {
                        backgroundView(width: dw, height: dh)
                            .frame(width: dw, height: dh)
                            .allowsHitTesting(false)
                    }

                    // Inner canvas: dw x dh coordinate space, visually shrunk when bg on
                    ZStack(alignment: .topLeading) {
                        Image(nsImage: currentImage).resizable().aspectRatio(contentMode: .fit)
                            .frame(width: dw, height: dh)

                        ForEach(history.annotations) { ann in
                            if ann.id != editingTextId {
                                if ann.shape == .blur {
                                    BlurRegionView(annotation: ann, image: currentImage,
                                                   canvasSize: CGSize(width: dw, height: dh))
                                } else {
                                    AnnotationView(annotation: ann,
                                                   canvasSize: CGSize(width: dw, height: dh))
                                }
                            }
                        }.frame(width: dw, height: dh)

                        if let hId = hoveredId, !selectedIds.contains(hId),
                           let hAnn = history.annotations.first(where: { $0.id == hId }) {
                            HoverOverlay(annotation: hAnn, canvasSize: CGSize(width: dw, height: dh))
                                .frame(width: dw, height: dh)
                        }

                        if case .drawing(let ann) = interaction {
                            if ann.shape == .blur {
                                BlurRegionView(annotation: ann, image: currentImage,
                                               canvasSize: CGSize(width: dw, height: dh))
                                    .frame(width: dw, height: dh)
                            } else {
                                AnnotationView(annotation: ann,
                                               canvasSize: CGSize(width: dw, height: dh))
                                    .frame(width: dw, height: dh)
                            }
                        }
                        if case .freehand(let pts) = interaction, pts.count >= 2 {
                            FreehandPreview(points: pts, color: annotationColor, lineWidth: annotationLineWidth)
                                .frame(width: dw, height: dh)
                        }

                        if let editId = editingTextId,
                           let ann = history.annotations.first(where: { $0.id == editId }) {
                            TextEditingOverlay(
                                text: $editingText,
                                annotation: ann,
                                canvasSize: CGSize(width: dw, height: dh),
                                onCommit: { commitTextEdit() }
                            )
                            .frame(width: dw, height: dh)
                        }

                        ForEach(selectedAnnotations, id: \.id) { sel in
                            if editingTextId != sel.id {
                                SelectionOverlay(annotation: sel,
                                                 canvasSize: CGSize(width: dw, height: dh))
                                    .frame(width: dw, height: dh)
                            }
                        }

                        if selectedTool == "crop", let s = cropStart, let e = cropEnd {
                            let r = normalizedRect(from: s, to: e)
                            Color.black.opacity(0.4).frame(width: dw, height: dh)
                                .mask(CropMask(rect: r, size: CGSize(width: dw, height: dh)))
                            Rectangle().stroke(Color.white, lineWidth: 2)
                                .frame(width: r.width, height: r.height).position(x: r.midX, y: r.midY)
                        }
                    }
                    .frame(width: dw, height: dh)
                    .clipShape(bgConfig.enabled ? AnyShape(RoundedRectangle(cornerRadius: cornerPx)) : AnyShape(Rectangle()))
                    .shadow(color: bgConfig.enabled && bgConfig.shadowEnabled
                                ? .black.opacity(bgConfig.shadowOpacity) : .clear,
                            radius: bgConfig.enabled ? shadowPx * 0.5 : 0,
                            y: bgConfig.enabled ? shadowPx * 0.15 : 0)
                    .scaleEffect(bgShrink)
                }
                .frame(width: dw, height: dh)
                .contentShape(Rectangle())
                .scaleEffect(zoomLevel)
                .offset(x: ox + panOffset.width, y: oy + panOffset.height)
                .gesture(
                    DragGesture(minimumDistance: 1)
                        .onChanged { v in handleDrag(v, dw: dw, dh: dh, ox: ox, oy: oy, bgShrink: bgShrink) }
                        .onEnded { v in handleDragEnd(v, dw: dw, dh: dh, ox: ox, oy: oy) }
                )
                .onTapGesture { loc in handleTap(loc, dw: dw, dh: dh, ox: ox, oy: oy, bgShrink: bgShrink) }
                .onContinuousHover { phase in
                    switch phase {
                    case .active(let loc):
                        let pt = canvasPoint(loc, dw: dw, dh: dh, ox: ox, oy: oy, bgShrink: bgShrink)
                        updateCursor(at: pt)
                        hoveredId = history.annotations.last(where: { $0.hitTest(pt) })?.id
                    case .ended:
                        NSCursor.arrow.set()
                        hoveredId = nil
                    }
                }
                .onAppear {
                    canvasSize = CGSize(width: dw, height: dh)
                    setupScrollMonitors()
                }
                .onDisappear { removeScrollMonitors() }
            }
            .clipped()

            // Crop toolbar (top-right)
            if selectedTool == "crop" && cropStart != nil && cropEnd != nil {
                CropToolbar(
                    onApply: { applyCrop() },
                    onCancel: { cancelTool() }
                )
                .padding(8)
            }

            // Background panel (top-right)
            if selectedTool == "background" {
                BackgroundPanel(config: $bgConfig, onClose: { selectedTool = nil })
                    .padding(8)
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
                    onChangeTextBackground: { v in setAnnotationTextBackground(v); textHasBackground = v },
                    onChangeBlurRadius: { r in setAnnotationBlurRadius(r); blurRadius = r },
                    onChangeBlurStyle: { s in setAnnotationBlurStyle(s); blurStyle = s },
                    onDeselect: { selectedIds = []; selectedTool = "cursor" },
                    onDelete: { deleteSelectedAnnotations() }
                )
                .padding(8)
            }
        }
        .clipped()
        .frame(maxWidth: .infinity, maxHeight: .infinity).layoutPriority(1)
    }

    // MARK: - Gesture handling

    private func canvasPoint(_ location: CGPoint, dw: CGFloat, dh: CGFloat, ox: CGFloat, oy: CGFloat, bgShrink: CGFloat = 1.0) -> CGPoint {
        // Combined effective zoom = zoomLevel (user zoom) * bgShrink (background visual scale)
        // The outer ZStack is dw x dh, canvas inside is scaled by bgShrink from center
        let ez = zoomLevel * bgShrink
        let x = (location.x - ox - panOffset.width) / ez + (dw - dw / ez) / 2
        let y = (location.y - oy - panOffset.height) / ez + (dh - dh / ez) / 2
        return CGPoint(x: max(0, min(x, dw)), y: max(0, min(y, dh)))
    }

    private func handleDrag(_ value: DragGesture.Value, dw: CGFloat, dh: CGFloat, ox: CGFloat, oy: CGFloat, bgShrink: CGFloat = 1.0) {
        let start = canvasPoint(value.startLocation, dw: dw, dh: dh, ox: ox, oy: oy, bgShrink: bgShrink)
        let current = canvasPoint(value.location, dw: dw, dh: dh, ox: ox, oy: oy, bgShrink: bgShrink)
        canvasSize = CGSize(width: dw, height: dh)

        // Determine interaction on first move
        if case .none = interaction {
            if selectedTool == "crop" {
                cropStart = start; cropEnd = current; return
            }

            // Priority 1: Resize/rotation handle of selected annotation (only first selected)
            if let firstSelectedId = selectedIds.first,
               let ann = history.annotations.first(where: { $0.id == firstSelectedId }),
               let handle = ann.handleAt(start) {
                history.save()
                if handle == .rotating {
                    interaction = .rotating(firstSelectedId)
                } else {
                    interaction = .resizing(firstSelectedId, handle)
                }
            }
            // Priority 2: Move selected annotations if clicking on one of them
            else if let hit = history.annotations.last(where: { selectedIds.contains($0.id) && $0.hitTest(start) }) {
                history.save()
                // Option-drag: duplicate all selected annotations and move the copies
                if NSEvent.modifierFlags.contains(.option) {
                    let copies = selectedIds.compactMap { id in
                        history.annotations.first(where: { $0.id == id })?.duplicate()
                    }
                    for copy in copies {
                        history.annotations.append(copy)
                    }
                    selectedIds = Set(copies.map(\.id))
                    interaction = .movingMultiple(selectedIds, start)
                } else {
                    interaction = .movingMultiple(selectedIds, start)
                }
            }
            // Priority 3: Select + move another annotation if clicking on it (no tool required)
            else if let hit = history.annotations.last(where: { $0.hitTest(start) }),
                    activeShapeTool == nil {
                history.save()
                // Modifier: add/remove from selection
                let hasShiftOrCmd = NSEvent.modifierFlags.contains(.shift) || NSEvent.modifierFlags.contains(.command)
                if hasShiftOrCmd {
                    if selectedIds.contains(hit.id) {
                        selectedIds.remove(hit.id)
                    } else {
                        selectedIds.insert(hit.id)
                    }
                } else {
                    selectedIds = [hit.id]
                }

                // Option-drag: duplicate all selected annotations and move the copies
                if NSEvent.modifierFlags.contains(.option) {
                    let copies = selectedIds.compactMap { id in
                        history.annotations.first(where: { $0.id == id })?.duplicate()
                    }
                    for copy in copies {
                        history.annotations.append(copy)
                    }
                    selectedIds = Set(copies.map(\.id))
                    interaction = .movingMultiple(selectedIds, start)
                } else {
                    interaction = .movingMultiple(selectedIds, start)
                }
            }
            // Priority 4: Draw new shape if tool is active
            else if selectedTool == "draw" {
                selectedIds = []
                commitTextIfNeeded()
                interaction = .freehand([start, current])
            }
            else if let shape = activeShapeTool, shape != .text {
                selectedIds = []
                commitTextIfNeeded()
                interaction = .drawing(Annotation(shape: shape, start: start, end: current,
                                                  color: annotationColor, lineWidth: annotationLineWidth,
                                                  filled: annotationFilled, solidFill: annotationSolidFill,
                                                  arrowStyle: shape == .arrow ? arrowStyle : .thin,
                                                  blurRadius: blurRadius, blurStyle: blurStyle))
            }
            // Priority 5: Deselect if clicking on nothing
            else {
                selectedIds = []
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
        case .movingMultiple(let ids, let lastPt):
            let dx = current.x - lastPt.x, dy = current.y - lastPt.y
            for id in ids {
                if let idx = history.annotations.firstIndex(where: { $0.id == id }) {
                    history.annotations[idx].move(by: CGSize(width: dx, height: dy))
                }
            }
            interaction = .movingMultiple(ids, current)
        case .resizing(let id, let handle):
            if let idx = history.annotations.firstIndex(where: { $0.id == id }) {
                history.annotations[idx].resize(handle: handle, to: current)
            }
        case .rotating(let id):
            if let idx = history.annotations.firstIndex(where: { $0.id == id }) {
                let center = history.annotations[idx].boundingRect
                let cx = center.midX, cy = center.midY
                let angle = atan2(current.x - cx, -(current.y - cy))
                history.annotations[idx].rotation = angle * 180 / .pi
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
                selectedIds = [ann.id]
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
                selectedIds = [ann.id]
            }
        case .moving, .movingMultiple, .resizing, .rotating:
            break
        case .none:
            break
        }
        interaction = .none
    }

    private func handleTap(_ location: CGPoint, dw: CGFloat, dh: CGFloat, ox: CGFloat, oy: CGFloat, bgShrink: CGFloat = 1.0) {
        let pt = canvasPoint(location, dw: dw, dh: dh, ox: ox, oy: oy, bgShrink: bgShrink)

        // Text tool: if already editing, commit and switch to select
        if selectedTool == "text" && editingTextId != nil {
            commitTextIfNeeded()
            selectedTool = "cursor"
            // Check if we clicked on an annotation
            if let hit = history.annotations.last(where: { $0.hitTest(pt) }) {
                selectedIds = [hit.id]
            } else {
                selectedIds = []
            }
            return
        }

        // Text tool: click to place new text
        if selectedTool == "text" {
            let ann = Annotation(shape: .text, start: pt, end: pt,
                                 color: annotationColor, fontSize: fontSize,
                                 textHasBackground: textHasBackground)
            history.save()
            history.annotations.append(ann)
            selectedIds = [ann.id]
            editingTextId = ann.id
            editingText = ""
            return
        }

        // Numbered tool: click to place numbered circle
        if selectedTool == "numbered" {
            let size: CGFloat = fontSize * 1.6
            let ann = Annotation(shape: .numbered, start: pt,
                                 end: CGPoint(x: pt.x + size, y: pt.y + size),
                                 color: annotationColor,
                                 text: "\(nextNumber)", fontSize: fontSize)
            history.save()
            history.annotations.append(ann)
            selectedIds = [ann.id]
            nextNumber += 1
            return
        }

        commitTextIfNeeded()

        // Try to select an annotation under the click
        if let hit = history.annotations.last(where: { $0.hitTest(pt) }) {
            // If clicking on an already-selected text → enter edit mode
            if selectedIds.contains(hit.id) && hit.shape == .text && editingTextId == nil {
                editingTextId = hit.id
                editingText = hit.text
                return
            }

            // Modifier: add/remove from selection
            let hasShiftOrCmd = NSEvent.modifierFlags.contains(.shift) || NSEvent.modifierFlags.contains(.command)
            if hasShiftOrCmd {
                if selectedIds.contains(hit.id) {
                    selectedIds.remove(hit.id)
                } else {
                    selectedIds.insert(hit.id)
                }
            } else {
                selectedIds = [hit.id]
            }
            selectedTool = "cursor"
        } else if selectedTool != "crop" {
            // Clicked on empty space → switch to cursor tool
            selectedIds = []
            selectedTool = "cursor"
        }
    }

    // MARK: - Helpers

    private func normalizedRect(from s: CGPoint, to e: CGPoint) -> CGRect {
        CGRect(x: min(s.x, e.x), y: min(s.y, e.y), width: abs(e.x - s.x), height: abs(e.y - s.y))
    }

    // MARK: - Background

    @ViewBuilder
    private func backgroundView(width: CGFloat, height: CGFloat) -> some View {
        switch bgConfig.type {
        case .gradient(let idx):
            let preset = gradientPresets[min(idx, gradientPresets.count - 1)]
            LinearGradient(colors: preset.colors,
                           startPoint: preset.startPoint, endPoint: preset.endPoint)
                .frame(width: width, height: height)
        case .solid(let color):
            color.frame(width: width, height: height)
        }
    }

    private func buildFinalImage() -> NSImage {
        print("[BuildFinal] canvasSize=\(canvasSize) imageSize=\(currentImage.size) bgEnabled=\(bgConfig.enabled)")
        var img = flattenAnnotations(history.annotations, onto: currentImage, canvasSize: canvasSize)
        print("[BuildFinal] after flatten: \(img.size)")
        if bgConfig.enabled {
            print("[BuildFinal] padding=\(bgConfig.padding)% cornerRadius=\(bgConfig.cornerRadius)%")
            img = renderWithBackground(img)
            print("[BuildFinal] after background: \(img.size)")
        }
        return img
    }

    private func renderWithBackground(_ image: NSImage) -> NSImage {
        let imgPts = image.size
        guard imgPts.width > 0 && imgPts.height > 0 else { return image }

        let padPct = bgConfig.padding / 100.0
        let pad = imgPts.width * padPct
        let radius = bgConfig.cornerRadius / 100.0 * min(imgPts.width, imgPts.height) / 2
        let totalW = imgPts.width + pad * 2
        let totalH = imgPts.height + pad * 2
        guard totalW > 1 && totalH > 1 else { return image }

        // NSImage(size:flipped:drawingHandler:) — Apple's recommended approach
        // flipped: false = standard AppKit coordinates (Y-up), handles Retina automatically
        return NSImage(size: NSSize(width: totalW, height: totalH), flipped: false) { bounds in
            // 1. Background
            switch self.bgConfig.type {
            case .gradient(let idx):
                let preset = gradientPresets[min(idx, gradientPresets.count - 1)]
                if let gradient = NSGradient(colors: preset.colors.map { NSColor($0) }) {
                    gradient.draw(in: bounds, angle: -45)
                }
            case .solid(let color):
                NSColor(color).setFill()
                bounds.fill()
            }

            // 2. Shadow
            let imgRect = NSRect(x: pad, y: pad, width: imgPts.width, height: imgPts.height)
            let rrPath = NSBezierPath(roundedRect: imgRect, xRadius: radius, yRadius: radius)

            if self.bgConfig.shadowEnabled {
                NSGraphicsContext.saveGraphicsState()
                let shadow = NSShadow()
                shadow.shadowColor = NSColor.black.withAlphaComponent(0.3)
                shadow.shadowBlurRadius = pad * 0.3
                shadow.shadowOffset = NSSize(width: 0, height: -(pad * 0.08))
                shadow.set()
                NSColor.white.setFill()
                rrPath.fill()
                NSGraphicsContext.restoreGraphicsState()
            }

            // 3. Rounded screenshot
            NSGraphicsContext.saveGraphicsState()
            rrPath.addClip()
            image.draw(in: imgRect, from: NSRect(origin: .zero, size: imgPts),
                       operation: .sourceOver, fraction: 1.0)
            NSGraphicsContext.restoreGraphicsState()

            return true
        }
    }

    private func applyCrop() {
        guard let s = cropStart, let e = cropEnd else { return }
        let rect = normalizedRect(from: s, to: e)
        guard rect.width > 5 && rect.height > 5 else { return }
        // Save full state for undo (image + annotations + their undo stacks)
        imageUndoStack.append((currentImage, history.annotations))
        if !history.annotations.isEmpty {
            currentImage = flattenAnnotations(history.annotations, onto: currentImage, canvasSize: canvasSize)
            history.annotations.removeAll()
        }
        currentImage = cropImage(currentImage, to: rect, canvasSize: canvasSize)
        // Clear annotation history — crop is a destructive operation, undo goes through imageUndoStack
        history.clearStacks()
        cropStart = nil; cropEnd = nil; interaction = .none
    }

    private func selectTool(_ tool: String?) {
        if editingTextId != nil { commitTextIfNeeded() }
        if tool == selectedTool { selectedTool = nil } else { selectedTool = tool }
        selectedIds = []; cropStart = nil; cropEnd = nil; interaction = .none
    }

    private func cancelTool() {
        commitTextIfNeeded()
        selectedTool = nil; cropStart = nil; cropEnd = nil; interaction = .none
    }

    private func zoomIn() {
        withAnimation(.easeOut(duration: 0.15)) {
            zoomLevel = min(10, zoomLevel * 1.25)
            clampPan()
        }
    }

    private func zoomOut() {
        withAnimation(.easeOut(duration: 0.15)) {
            zoomLevel = max(1.0, zoomLevel / 1.25)
            clampPan()
        }
    }

    private func zoomReset() {
        withAnimation(.easeOut(duration: 0.2)) { zoomLevel = 1.0; panOffset = .zero }
    }

    /// Clamp pan offset so the image edges don't go past the viewport center
    private func clampPan() {
        if zoomLevel <= 1.0 {
            panOffset = .zero
            return
        }
        let maxPanX = canvasSize.width * (zoomLevel - 1) / 2
        let maxPanY = canvasSize.height * (zoomLevel - 1) / 2
        panOffset.width = max(-maxPanX, min(maxPanX, panOffset.width))
        panOffset.height = max(-maxPanY, min(maxPanY, panOffset.height))
    }

    private func setupScrollMonitors() {
        scrollMonitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { event in
            if event.modifierFlags.contains(.command) {
                let factor = 1.0 + event.scrollingDeltaY * 0.01
                zoomLevel = max(1.0, min(10, zoomLevel * factor))
                clampPan()
            } else if zoomLevel > 1.01 {
                panOffset.width += event.scrollingDeltaX
                panOffset.height += event.scrollingDeltaY
                clampPan()
            }
            return event
        }
        magnifyMonitor = NSEvent.addLocalMonitorForEvents(matching: .magnify) { event in
            let factor = 1.0 + event.magnification
            zoomLevel = max(1.0, min(10, zoomLevel * factor))
            clampPan()
            return event
        }
    }

    private func removeScrollMonitors() {
        if let m = scrollMonitor { NSEvent.removeMonitor(m); scrollMonitor = nil }
        if let m = magnifyMonitor { NSEvent.removeMonitor(m); magnifyMonitor = nil }
    }

    private func undoAction() {
        if history.canUndo {
            history.undo(); syncSelection()
        } else if let (prevImage, prevAnnotations) = imageUndoStack.popLast() {
            currentImage = prevImage
            history.annotations = prevAnnotations
            syncSelection()
        }
    }

    private func deleteSelectedAnnotations() {
        guard !selectedIds.isEmpty else { return }
        history.save()
        history.annotations.removeAll { selectedIds.contains($0.id) }
        selectedIds = []
    }

    private func copySelectedAnnotation() {
        guard let ann = selectedAnnotation else { return }
        clipboard = ann
    }

    private func pasteAnnotation() {
        guard let source = clipboard else { return }
        let pasted = source.duplicate(offset: CGSize(width: 20, height: 20))
        history.save()
        history.annotations.append(pasted)
        selectedIds = [pasted.id]
        // Update clipboard to the pasted copy so successive pastes cascade
        clipboard = pasted
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

        // Check resize/rotation handles on first selected annotation
        if let firstSelectedId = selectedIds.first,
           let ann = history.annotations.first(where: { $0.id == firstSelectedId }),
           let handle = ann.handleAt(point) {
            if handle == .rotating {
                rotateCursor.set()
            } else {
                NSCursor.crosshair.set()
            }
            return
        }

        // Check if hovering over any annotation
        if history.annotations.contains(where: { $0.hitTest(point) }) {
            NSCursor.openHand.set()
            return
        }

        NSCursor.arrow.set()
    }

    private func moveSelectedAnnotations(dx: CGFloat, dy: CGFloat) {
        guard !selectedIds.isEmpty else { return }
        history.save()
        for id in selectedIds {
            if let idx = history.annotations.firstIndex(where: { $0.id == id }) {
                history.annotations[idx].move(by: CGSize(width: dx, height: dy))
            }
        }
    }

    private func syncSelection() {
        selectedIds = selectedIds.filter { id in
            history.annotations.contains(where: { $0.id == id })
        }
    }

    private var showPropertiesToolbar: Bool {
        if !selectedIds.isEmpty { return true }
        if let tool = selectedTool, tool != "crop" && tool != "cursor" && tool != "background" { return true }
        return false
    }

    private var propertiesToolbarAnnotation: Annotation {
        if let sel = selectedAnnotation { return sel }
        // Build a dummy annotation from current defaults for toolbar display
        let shape: AnnotationShape = switch selectedTool {
            case "rect": .rect; case "circle": .circle
            case "line": .line; case "arrow": .arrow
            case "text": .text; case "draw": .freehand
            case "blur": .blur
            default: .rect
        }
        return Annotation(shape: shape, start: .zero, end: .zero,
                          color: annotationColor, lineWidth: annotationLineWidth,
                          filled: annotationFilled, solidFill: annotationSolidFill,
                          fontSize: fontSize, arrowStyle: arrowStyle,
                          textHasBackground: textHasBackground,
                          blurRadius: blurRadius, blurStyle: blurStyle)
    }

    private func commitTextIfNeeded() {
        guard let id = editingTextId else { return }
        if editingText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            history.annotations.removeAll { $0.id == id }
            selectedIds = []
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

    private func setAnnotationColor(_ color: Color) {
        annotationColor = color
        UserDefaults.standard.set(color.toHex(), forKey: "lastAnnotationColor")
        guard let id = selectedIds.first, let idx = history.annotations.firstIndex(where: { $0.id == id }) else { return }
        history.save()
        history.annotations[idx].color = color
    }

    private func setAnnotationLineWidth(_ width: CGFloat) {
        annotationLineWidth = width
        guard let id = selectedIds.first, let idx = history.annotations.firstIndex(where: { $0.id == id }) else { return }
        history.save()
        history.annotations[idx].lineWidth = width
    }

    private func setAnnotationFillMode(_ mode: FillMode) {
        switch mode {
        case .outline:
            annotationFilled = false; annotationSolidFill = false
        case .semiFilled:
            annotationFilled = true; annotationSolidFill = false
        case .solidFilled:
            annotationFilled = true; annotationSolidFill = true
        }
        guard let id = selectedIds.first, let idx = history.annotations.firstIndex(where: { $0.id == id }) else { return }
        history.save()
        history.annotations[idx].filled = annotationFilled
        history.annotations[idx].solidFill = annotationSolidFill
    }

    private func setAnnotationFontSize(_ size: CGFloat) {
        fontSize = size
        guard let id = selectedIds.first, let idx = history.annotations.firstIndex(where: { $0.id == id }) else { return }
        history.save()
        history.annotations[idx].fontSize = size
    }

    private func setAnnotationArrowStyle(_ style: ArrowStyle) {
        arrowStyle = style
        guard let id = selectedIds.first, let idx = history.annotations.firstIndex(where: { $0.id == id }) else { return }
        history.save()
        history.annotations[idx].arrowStyle = style
    }

    private func setAnnotationTextBackground(_ value: Bool) {
        textHasBackground = value
        guard let id = selectedIds.first, let idx = history.annotations.firstIndex(where: { $0.id == id }) else { return }
        history.save()
        history.annotations[idx].textHasBackground = value
    }

    private func setAnnotationBlurRadius(_ radius: CGFloat) {
        blurRadius = radius
        guard let id = selectedIds.first, let idx = history.annotations.firstIndex(where: { $0.id == id }) else { return }
        history.save()
        history.annotations[idx].blurRadius = radius
    }

    private func setAnnotationBlurStyle(_ style: BlurStyle) {
        blurStyle = style
        guard let id = selectedIds.first, let idx = history.annotations.firstIndex(where: { $0.id == id }) else { return }
        history.save()
        history.annotations[idx].blurStyle = style
    }

    private func quickSave() {
        var img = buildFinalImage()
        if !UserDefaults.standard.bool(forKey: "exportRetina") { img = normalizeImageDPI(img) }

        let format = UserDefaults.standard.string(forKey: "imageFormat") ?? "png"
        let ext: String
        let fileType: NSBitmapImageRep.FileType
        switch format {
        case "jpeg": ext = "jpg"; fileType = .jpeg
        case "tiff": ext = "tiff"; fileType = .tiff
        default: ext = "png"; fileType = .png
        }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.init(filenameExtension: ext)!]
        let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        panel.nameFieldStringValue = "Screenshot_\(df.string(from: Date())).\(ext)"
        panel.canCreateDirectories = true

        guard panel.runModal() == .OK, let url = panel.url else { return }

        guard let tiff = img.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let data = bitmap.representation(using: fileType,
                  properties: fileType == .jpeg ? [.compressionFactor: 0.9] : [:]) else { return }
        try? data.write(to: url)

        let en = L10n.lang == "en"
        ToastManager.shared.show(
            title: en ? "Saved!" : "Sauvegardé !",
            subtitle: url.lastPathComponent
        )
    }

}
