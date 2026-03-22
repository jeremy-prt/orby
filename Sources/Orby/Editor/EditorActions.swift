import SwiftUI
import AppKit
import CoreImage

// MARK: - Editor Actions

extension EditorView {

    func applyCrop() {
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

    func selectTool(_ tool: String?) {
        if editingTextId != nil { commitTextIfNeeded() }
        if tool == selectedTool { selectedTool = nil } else { selectedTool = tool }
        selectedIds = []; cropStart = nil; cropEnd = nil; interaction = .none
    }

    func cancelTool() {
        commitTextIfNeeded()
        selectedTool = nil; cropStart = nil; cropEnd = nil; interaction = .none
    }

    func zoomIn() {
        withAnimation(.easeOut(duration: 0.15)) {
            zoomLevel = min(10, zoomLevel * 1.25)
            clampPan()
        }
    }

    func zoomOut() {
        withAnimation(.easeOut(duration: 0.15)) {
            zoomLevel = max(1.0, zoomLevel / 1.25)
            clampPan()
        }
    }

    func zoomReset() {
        withAnimation(.easeOut(duration: 0.2)) { zoomLevel = 1.0; panOffset = .zero }
    }

    /// Clamp pan offset so the image edges don't go past the viewport center
    func clampPan() {
        if zoomLevel <= 1.0 {
            panOffset = .zero
            return
        }
        let maxPanX = canvasSize.width * (zoomLevel - 1) / 2
        let maxPanY = canvasSize.height * (zoomLevel - 1) / 2
        panOffset.width = max(-maxPanX, min(maxPanX, panOffset.width))
        panOffset.height = max(-maxPanY, min(maxPanY, panOffset.height))
    }

    func setupScrollMonitors() {
        scrollMonitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { event in
            if event.modifierFlags.contains(.command) {
                let oldZoom = zoomLevel
                let factor = 1.0 + event.scrollingDeltaY * 0.01
                let newZoom = max(1.0, min(10, zoomLevel * factor))
                zoomLevel = newZoom
                zoomTowardsCursor(event: event, oldZoom: oldZoom, newZoom: newZoom)
                clampPan()
            } else if zoomLevel > 1.01 {
                panOffset.width += event.scrollingDeltaX
                panOffset.height += event.scrollingDeltaY
                clampPan()
            }
            return event
        }
        magnifyMonitor = NSEvent.addLocalMonitorForEvents(matching: .magnify) { event in
            let oldZoom = zoomLevel
            let factor = 1.0 + event.magnification
            let newZoom = max(1.0, min(10, zoomLevel * factor))
            zoomLevel = newZoom
            zoomTowardsCursor(event: event, oldZoom: oldZoom, newZoom: newZoom)
            clampPan()
            return event
        }
    }

    /// Adjust panOffset so the image point under the cursor stays under the cursor after zoom.
    /// Algorithm: convert cursor to image-space before zoom, then adjust pan so that point stays at same screen position.
    func zoomTowardsCursor(event: NSEvent, oldZoom: CGFloat, newZoom: CGFloat) {
        guard oldZoom != newZoom, let window = event.window else { return }
        let contentH = window.contentView?.bounds.height ?? 0
        let contentW = window.contentView?.bounds.width ?? 0
        let baseDw = canvasSize.width, baseDh = canvasSize.height
        guard baseDw > 0 && baseDh > 0 else { return }

        // Convert cursor from AppKit window coords (Y-up) to viewport coords (Y-down, below 38pt toolbar)
        let cursorX = event.locationInWindow.x
        let cursorY = (contentH - 38) - event.locationInWindow.y
        let vpW = contentW
        let vpH = contentH - 38

        // Step 1: image origin BEFORE zoom (where image top-left is in viewport)
        let oldOx = (vpW - baseDw * oldZoom) / 2 + panOffset.width
        let oldOy = (vpH - baseDh * oldZoom) / 2 + panOffset.height

        // Step 2: image point under cursor (in base/image coordinates)
        let imgPtX = (cursorX - oldOx) / oldZoom
        let imgPtY = (cursorY - oldOy) / oldZoom

        // Step 3: where that image point would end up with new zoom (keeping current panOffset)
        let newOx = (vpW - baseDw * newZoom) / 2 + panOffset.width
        let newOy = (vpH - baseDh * newZoom) / 2 + panOffset.height
        let newScreenX = newOx + imgPtX * newZoom
        let newScreenY = newOy + imgPtY * newZoom

        // Step 4: adjust pan so the image point stays under cursor
        panOffset.width += cursorX - newScreenX
        panOffset.height += cursorY - newScreenY
    }

    func removeScrollMonitors() {
        if let m = scrollMonitor { NSEvent.removeMonitor(m); scrollMonitor = nil }
        if let m = magnifyMonitor { NSEvent.removeMonitor(m); magnifyMonitor = nil }
    }

    func undoAction() {
        if history.canUndo {
            history.undo(); syncSelection()
        } else if let (prevImage, prevAnnotations) = imageUndoStack.popLast() {
            currentImage = prevImage
            history.annotations = prevAnnotations
            syncSelection()
        }
    }

    func deleteSelectedAnnotations() {
        guard !selectedIds.isEmpty else { return }
        history.save()
        history.annotations.removeAll { selectedIds.contains($0.id) }
        selectedIds = []
    }

    func copySelectedAnnotation() {
        guard let ann = selectedAnnotation else { return }
        clipboard = ann
    }

    func pasteAnnotation() {
        guard let source = clipboard else { return }
        let pasted = source.duplicate(offset: CGSize(width: 20, height: 20))
        history.save()
        history.annotations.append(pasted)
        selectedIds = [pasted.id]
        // Update clipboard to the pasted copy so successive pastes cascade
        clipboard = pasted
    }

    func moveSelectedAnnotations(dx: CGFloat, dy: CGFloat) {
        guard !selectedIds.isEmpty else { return }
        history.save()
        for id in selectedIds {
            if let idx = history.annotations.firstIndex(where: { $0.id == id }) {
                history.annotations[idx].move(by: CGSize(width: dx, height: dy))
            }
        }
    }

    func syncSelection() {
        selectedIds = selectedIds.filter { id in
            history.annotations.contains(where: { $0.id == id })
        }
    }

    var showPropertiesToolbar: Bool {
        if !selectedIds.isEmpty { return true }
        if let tool = selectedTool, tool != "crop" && tool != "cursor" && tool != "background" { return true }
        return false
    }

    var propertiesToolbarAnnotation: Annotation {
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

    func commitTextIfNeeded() {
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

    func commitTextEdit() {
        commitTextIfNeeded()
        selectedTool = nil
    }

    func setAnnotationColor(_ color: Color) {
        annotationColor = color
        UserDefaults.standard.set(color.toHex(), forKey: "lastAnnotationColor")
        guard let id = selectedIds.first, let idx = history.annotations.firstIndex(where: { $0.id == id }) else { return }
        history.save()
        history.annotations[idx].color = color
    }

    func setAnnotationLineWidth(_ width: CGFloat) {
        annotationLineWidth = width
        guard let id = selectedIds.first, let idx = history.annotations.firstIndex(where: { $0.id == id }) else { return }
        history.save()
        history.annotations[idx].lineWidth = width
    }

    func setAnnotationFillMode(_ mode: FillMode) {
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

    func setAnnotationFontSize(_ size: CGFloat) {
        fontSize = size
        guard let id = selectedIds.first, let idx = history.annotations.firstIndex(where: { $0.id == id }) else { return }
        history.save()
        history.annotations[idx].fontSize = size
    }

    func setAnnotationArrowStyle(_ style: ArrowStyle) {
        arrowStyle = style
        guard let id = selectedIds.first, let idx = history.annotations.firstIndex(where: { $0.id == id }) else { return }
        history.save()
        history.annotations[idx].arrowStyle = style
    }

    func setAnnotationTextBackground(_ value: Bool) {
        textHasBackground = value
        guard let id = selectedIds.first, let idx = history.annotations.firstIndex(where: { $0.id == id }) else { return }
        history.save()
        history.annotations[idx].textHasBackground = value
    }

    func setAnnotationBlurRadius(_ radius: CGFloat) {
        blurRadius = radius
        guard let id = selectedIds.first, let idx = history.annotations.firstIndex(where: { $0.id == id }) else { return }
        history.save()
        history.annotations[idx].blurRadius = radius
    }

    func setAnnotationBlurStyle(_ style: BlurStyle) {
        blurStyle = style
        guard let id = selectedIds.first, let idx = history.annotations.firstIndex(where: { $0.id == id }) else { return }
        history.save()
        history.annotations[idx].blurStyle = style
    }

    func setAnnotationCornerRadius(_ radius: CGFloat) {
        guard let id = selectedIds.first, let idx = history.annotations.firstIndex(where: { $0.id == id }) else { return }
        history.save()
        history.annotations[idx].cornerRadius = radius
    }

    /// Extract the dominant color from the image by sampling the 4 corners and averaging them.
    /// Falls back to controlBackgroundColor if unable to extract.
    func extractDominantColor(from image: NSImage) -> NSColor {
        guard let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff) else {
            return NSColor.controlBackgroundColor
        }

        let w = bitmap.pixelsWide, h = bitmap.pixelsHigh
        guard w > 0 && h > 0 else {
            return NSColor.controlBackgroundColor
        }

        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0
        let points = [(0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1)]

        for (px, py) in points {
            guard let color = bitmap.colorAt(x: px, y: py)?
                .usingColorSpace(.deviceRGB) else { continue }
            r += color.redComponent
            g += color.greenComponent
            b += color.blueComponent
        }

        let n = CGFloat(points.count)
        return NSColor(red: r / n, green: g / n, blue: b / n, alpha: 1.0)
    }

    func quickSave() {
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
