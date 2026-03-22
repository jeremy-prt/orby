import SwiftUI
import AppKit

// MARK: - Editor Toolbar

extension EditorView {

    var toolbar: some View {
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
        .background(Color(nsColor: .windowBackgroundColor))
    }
}
