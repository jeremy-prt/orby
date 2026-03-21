import SwiftUI

struct HistoryView: View {
    @ObservedObject private var manager = HistoryManager.shared
    private let en = L10n.lang == "en"

    private let columns = [GridItem(.adaptive(minimum: 160, maximum: 210), spacing: 12)]

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("\(manager.entries.count)/12")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.tertiary)
                Spacer()
                Text(en ? "Capture History" : "Historique des captures")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Text("\(manager.entries.count)/12")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.clear) // invisible spacer for centering
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 4)

            if manager.entries.isEmpty {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 32))
                        .foregroundStyle(.tertiary)
                    Text(en ? "No captures yet" : "Aucune capture")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
                Spacer()
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(manager.entries) { entry in
                            HistoryCell(entry: entry, manager: manager)
                        }
                    }
                    .padding(12)
                }
            }
        }
        .frame(minWidth: 400, minHeight: 320)
    }
}

// MARK: - History Cell (ThumbnailView style)

private struct HistoryCell: View {
    let entry: HistoryEntry
    let manager: HistoryManager
    private let en = L10n.lang == "en"

    @State private var isHovered = false
    @State private var showCopied = false

    private let cellW: CGFloat = 180
    private let cellH: CGFloat = 120

    var body: some View {
        ZStack {
            // Thumbnail image
            if let thumb = manager.thumbnailImage(for: entry) {
                Image(nsImage: thumb)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: cellW, height: cellH)
                    .clipped()
                    .blur(radius: isHovered ? 8 : 0)
                    .brightness(isHovered ? -0.08 : 0)
            } else {
                Color(nsColor: .controlBackgroundColor)
            }

            if isHovered {
                // Glass overlay
                RoundedRectangle(cornerRadius: 10)
                    .fill(.ultraThinMaterial.opacity(0.4))
                    .transition(.opacity)

                // Edit button (center)
                Button {
                    openInEditor()
                } label: {
                    Text("Edit")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.black.opacity(0.8))
                        .frame(width: 70, height: 24)
                        .background(Capsule().fill(.white.opacity(0.85)))
                }
                .buttonStyle(.plain)
                .transition(.opacity.combined(with: .scale(scale: 0.92)))

                // Corner buttons
                VStack {
                    HStack {
                        Spacer()
                        // Delete (top-right)
                        Button { manager.delete(entry) } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.black.opacity(0.7))
                                .frame(width: 20, height: 20)
                                .background(Circle().fill(.white.opacity(0.85)))
                        }
                        .buttonStyle(.plain)
                    }
                    Spacer()
                    HStack {
                        // Copy (bottom-left)
                        Button {
                            copyToClipboard()
                            withAnimation(.easeInOut(duration: 0.2)) { showCopied = true }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                withAnimation { showCopied = false }
                            }
                        } label: {
                            Image(systemName: showCopied ? "checkmark" : "doc.on.doc.fill")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.black.opacity(0.7))
                                .frame(width: 20, height: 20)
                                .background(Circle().fill(.white.opacity(0.85)))
                        }
                        .buttonStyle(.plain)

                        Spacer()

                        // Save (bottom-right)
                        Button { saveToDesktop() } label: {
                            Image(systemName: "square.and.arrow.down.fill")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.black.opacity(0.7))
                                .frame(width: 20, height: 20)
                                .background(Circle().fill(.white.opacity(0.85)))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(5)
                .transition(.opacity)

                // Date label (bottom center, behind buttons)
                VStack {
                    Spacer()
                    Text(relativeDate(entry.date))
                        .font(.system(size: 9))
                        .foregroundStyle(.white.opacity(0.8))
                        .padding(.bottom, 2)
                }
                .allowsHitTesting(false)
            }
        }
        .frame(width: cellW, height: cellH)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
        .animation(.easeInOut(duration: 0.25), value: isHovered)
        .onHover { isHovered = $0 }
    }

    // MARK: - Actions

    private func openInEditor() {
        guard let image = manager.fullImage(for: entry) ?? manager.thumbnailImage(for: entry) else { return }
        let savePath: URL
        if let path = entry.savedPath {
            savePath = URL(fileURLWithPath: path).deletingLastPathComponent()
        } else {
            savePath = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Desktop")
        }
        EditorWindow.shared.open(image: image, savePath: savePath)
    }

    private func copyToClipboard() {
        guard let image = manager.fullImage(for: entry) ?? manager.thumbnailImage(for: entry) else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.writeObjects([image])
    }

    private func saveToDesktop() {
        guard let image = manager.fullImage(for: entry) else { return }
        let savePath = UserDefaults.standard.string(forKey: "savePath") ?? ""
        let dir = savePath.isEmpty
            ? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Desktop")
            : URL(fileURLWithPath: savePath)
        saveImage(image, to: dir)
    }

    private func relativeDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        formatter.locale = Locale(identifier: en ? "en" : "fr")
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
