import SwiftUI
import AppKit
import CoreImage

// MARK: - Editor Canvas

extension EditorView {

    var canvas: some View {
        ZStack(alignment: .topTrailing) {
            dominantBackgroundColor.frame(maxWidth: .infinity, maxHeight: .infinity)

            GeometryReader { geo in
                let imgSize = currentImage.size
                // BASE canvas size (without zoom) — coordinate system for annotations
                let fitScale = min(geo.size.width / max(imgSize.width, 1),
                                   geo.size.height / max(imgSize.height, 1),
                                   1.0)
                let baseDw = imgSize.width * fitScale, baseDh = imgSize.height * fitScale
                // ZOOMED rendering size
                let dw = baseDw * zoomLevel, dh = baseDh * zoomLevel
                let ox = (geo.size.width - dw) / 2
                let oy = (geo.size.height - dh) / 2

                // Background: visual shrink so canvas + padding fits in same area (computed from BASE size)
                let padPct = bgConfig.enabled ? bgConfig.padding / 100.0 : 0
                let bgShrink = bgConfig.enabled ? 1.0 / (1.0 + 2.0 * padPct) : 1.0
                let cornerPx = bgConfig.enabled
                    ? bgConfig.cornerRadius / 100.0 * min(baseDw * bgShrink, baseDh * bgShrink) / 2 : 0
                let shadowPx = bgConfig.enabled ? baseDw * (1 - bgShrink) / 2 : 0

                ZStack {
                    // Background gradient/color (fills dw x dh, visible around the shrunk canvas)
                    if bgConfig.enabled {
                        backgroundView(width: baseDw, height: baseDh)
                            .frame(width: dw, height: dh)
                            .scaleEffect(zoomLevel)
                            .allowsHitTesting(false)
                    }

                    // Inner canvas: dw x dh rendering size, annotations use baseDw x baseDh coords
                    ZStack(alignment: .topLeading) {
                        // Image
                        Image(nsImage: currentImage).resizable().aspectRatio(contentMode: .fit)
                            .frame(width: dw, height: dh)
                            .clipShape(bgConfig.enabled ? AnyShape(RoundedRectangle(cornerRadius: cornerPx * zoomLevel)) : AnyShape(Rectangle()))
                            .shadow(color: bgConfig.enabled && bgConfig.shadowEnabled
                                        ? .black.opacity(bgConfig.shadowOpacity) : .clear,
                                    radius: bgConfig.enabled ? shadowPx * zoomLevel * 0.5 : 0,
                                    y: bgConfig.enabled ? shadowPx * zoomLevel * 0.15 : 0)

                        // Annotations
                        ForEach(history.annotations) { ann in
                            if ann.id != editingTextId {
                                if ann.shape == .blur {
                                    BlurRegionView(annotation: ann, image: currentImage,
                                                   canvasSize: CGSize(width: baseDw, height: baseDh),
                                                   zoomLevel: zoomLevel)
                                } else {
                                    AnnotationView(annotation: ann,
                                                   canvasSize: CGSize(width: baseDw, height: baseDh),
                                                   zoomLevel: zoomLevel)
                                }
                            }
                        }.frame(width: dw, height: dh)

                        if let hId = hoveredId, !selectedIds.contains(hId),
                           let hAnn = history.annotations.first(where: { $0.id == hId }) {
                            HoverOverlay(annotation: hAnn, canvasSize: CGSize(width: baseDw, height: baseDh), zoomLevel: zoomLevel)
                                .frame(width: dw, height: dh)
                        }

                        if case .drawing(let ann) = interaction {
                            if ann.shape == .blur {
                                BlurRegionView(annotation: ann, image: currentImage,
                                               canvasSize: CGSize(width: baseDw, height: baseDh),
                                               zoomLevel: zoomLevel)
                                    .frame(width: dw, height: dh)
                            } else {
                                AnnotationView(annotation: ann,
                                               canvasSize: CGSize(width: baseDw, height: baseDh),
                                               zoomLevel: zoomLevel)
                                    .frame(width: dw, height: dh)
                            }
                        }
                        if case .freehand(let pts) = interaction, pts.count >= 2 {
                            FreehandPreview(points: pts, color: annotationColor, lineWidth: annotationLineWidth, zoomLevel: zoomLevel)
                                .frame(width: dw, height: dh)
                        }

                        if let editId = editingTextId,
                           let ann = history.annotations.first(where: { $0.id == editId }) {
                            TextEditingOverlay(
                                text: $editingText,
                                annotation: ann,
                                canvasSize: CGSize(width: baseDw, height: baseDh),
                                zoomLevel: zoomLevel,
                                onCommit: { commitTextEdit() }
                            )
                            .frame(width: dw, height: dh)
                        }

                        ForEach(selectedAnnotations, id: \.id) { sel in
                            if editingTextId != sel.id {
                                SelectionOverlay(annotation: sel,
                                                 canvasSize: CGSize(width: baseDw, height: baseDh),
                                                 zoomLevel: zoomLevel)
                                    .frame(width: dw, height: dh)
                            }
                        }

                        if selectedTool == "crop", let s = cropStart, let e = cropEnd {
                            let r = normalizedRect(from: s, to: e)
                            Color.black.opacity(0.4).frame(width: dw, height: dh)
                                .mask(CropMask(rect: r, size: CGSize(width: baseDw, height: baseDh), zoomLevel: zoomLevel))
                            Rectangle().stroke(Color.white, lineWidth: 2 / zoomLevel)
                                .frame(width: r.width * zoomLevel, height: r.height * zoomLevel)
                                .position(x: r.midX * zoomLevel, y: r.midY * zoomLevel)
                        }
                    }
                    .frame(width: dw, height: dh)
                    .scaleEffect(bgShrink)
                }
                .frame(width: dw, height: dh)
                .padding(40) // Extend hit area so handles outside canvas are clickable
                .contentShape(Rectangle())
                .position(x: ox + dw / 2 + panOffset.width, y: oy + dh / 2 + panOffset.height)
                .gesture(
                    DragGesture(minimumDistance: 1)
                        .onChanged { v in handleDrag(v, baseDw: baseDw, baseDh: baseDh, dw: dw, dh: dh, ox: ox, oy: oy, bgShrink: bgShrink) }
                        .onEnded { v in handleDragEnd(v, baseDw: baseDw, baseDh: baseDh) }
                )
                .onTapGesture { loc in handleTap(loc, baseDw: baseDw, baseDh: baseDh, dw: dw, dh: dh, ox: ox, oy: oy, bgShrink: bgShrink) }
                .onContinuousHover { phase in
                    switch phase {
                    case .active(let loc):
                        let pt = canvasPoint(loc, baseDw: baseDw, baseDh: baseDh, dw: dw, dh: dh, ox: ox, oy: oy, bgShrink: bgShrink)
                        updateCursor(at: pt)
                        hoveredId = history.annotations.last(where: { $0.hitTest(pt) })?.id
                    case .ended:
                        NSCursor.arrow.set()
                        hoveredId = nil
                    }
                }
                .onAppear {
                    canvasSize = CGSize(width: baseDw, height: baseDh)
                    setupScrollMonitors()
                }
                .onDisappear { removeScrollMonitors() }
            }

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
                    onChangeCornerRadius: { r in setAnnotationCornerRadius(r) },
                    onDeselect: { selectedIds = []; selectedTool = "cursor" },
                    onDelete: { deleteSelectedAnnotations() }
                )
                .padding(8)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity).layoutPriority(1)
    }

    // MARK: - Background

    @ViewBuilder
    func backgroundView(width: CGFloat, height: CGFloat) -> some View {
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

    func buildFinalImage() -> NSImage {
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

    func renderWithBackground(_ image: NSImage) -> NSImage {
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

    func normalizedRect(from s: CGPoint, to e: CGPoint) -> CGRect {
        CGRect(x: min(s.x, e.x), y: min(s.y, e.y), width: abs(e.x - s.x), height: abs(e.y - s.y))
    }
}
