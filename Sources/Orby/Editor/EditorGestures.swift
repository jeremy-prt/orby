import SwiftUI
import AppKit

// MARK: - Editor Gestures

extension EditorView {

    func canvasPoint(_ location: CGPoint, baseDw: CGFloat, baseDh: CGFloat, dw: CGFloat, dh: CGFloat, ox: CGFloat, oy: CGFloat, bgShrink: CGFloat = 1.0) -> CGPoint {
        // Convert screen coords (GeometryReader space) to canvas frame space (dw x dh)
        let canvasX = location.x - ox - panOffset.width
        let canvasY = location.y - oy - panOffset.height

        // Undo bgShrink centering (scaleEffect is centered on the dw x dh frame)
        let contentX = dw / 2 + (canvasX - dw / 2) / bgShrink
        let contentY = dh / 2 + (canvasY - dh / 2) / bgShrink

        // Convert zoomed space back to base annotation space
        let x = contentX / zoomLevel
        let y = contentY / zoomLevel

        // Allow margin outside canvas so handles near edges are reachable
        let margin: CGFloat = 50
        return CGPoint(x: max(-margin, min(x, baseDw + margin)), y: max(-margin, min(y, baseDh + margin)))
    }

    func handleDrag(_ value: DragGesture.Value, baseDw: CGFloat, baseDh: CGFloat, dw: CGFloat, dh: CGFloat, ox: CGFloat, oy: CGFloat, bgShrink: CGFloat = 1.0) {
        let start = canvasPoint(value.startLocation, baseDw: baseDw, baseDh: baseDh, dw: dw, dh: dh, ox: ox, oy: oy, bgShrink: bgShrink)
        let current = canvasPoint(value.location, baseDw: baseDw, baseDh: baseDh, dw: dw, dh: dh, ox: ox, oy: oy, bgShrink: bgShrink)
        canvasSize = CGSize(width: baseDw, height: baseDh)

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

    func handleDragEnd(_ value: DragGesture.Value, baseDw: CGFloat, baseDh: CGFloat) {
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

    func handleTap(_ location: CGPoint, baseDw: CGFloat, baseDh: CGFloat, dw: CGFloat, dh: CGFloat, ox: CGFloat, oy: CGFloat, bgShrink: CGFloat = 1.0) {
        let pt = canvasPoint(location, baseDw: baseDw, baseDh: baseDh, dw: dw, dh: dh, ox: ox, oy: oy, bgShrink: bgShrink)

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

    func updateCursor(at point: CGPoint) {
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
}
