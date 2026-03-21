import SwiftUI
import AppKit

struct ShareButton: View {
    let imageProvider: () -> NSImage
    @State private var anchorView = NSView()

    var body: some View {
        Button {
            share()
        } label: {
            Image(systemName: "square.and.arrow.up")
                .font(.system(size: 13))
                .frame(width: 28, height: 28)
        }
        .buttonStyle(.plain)
        .help(L10n.lang == "en" ? "Share" : "Partager")
        .background(ShareAnchor(nsView: anchorView))
    }

    private func share() {
        let image = imageProvider()

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("Screenshot_Share_\(UUID().uuidString).png")
        guard let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let png = bitmap.representation(using: .png, properties: [:]) else { return }
        try? png.write(to: tempURL)

        let picker = NSSharingServicePicker(items: [tempURL])
        picker.show(relativeTo: anchorView.bounds, of: anchorView, preferredEdge: .minY)
    }
}

// Invisible NSView anchored to the button's position
private struct ShareAnchor: NSViewRepresentable {
    let nsView: NSView

    func makeNSView(context: Context) -> NSView {
        nsView.frame = CGRect(x: 0, y: 0, width: 1, height: 1)
        return nsView
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}
