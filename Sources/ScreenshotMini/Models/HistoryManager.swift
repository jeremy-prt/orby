import AppKit

// MARK: - History Entry

struct HistoryEntry: Codable, Identifiable {
    let id: UUID
    let date: Date
    let captureType: String  // fullscreen, area, window
    var savedPath: String?   // path to saved file (if saved)
    let thumbnailFilename: String
    let width: Int
    let height: Int
}

// MARK: - History Manager

@MainActor
class HistoryManager: ObservableObject {
    static let shared = HistoryManager()

    @Published var entries: [HistoryEntry] = []

    private let maxEntries = 12
    private let historyDir: URL
    private let thumbDir: URL
    private let fullDir: URL
    private let jsonURL: URL

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("ScreenshotMini", isDirectory: true)
        historyDir = appSupport.appendingPathComponent("history", isDirectory: true)
        thumbDir = historyDir.appendingPathComponent("thumbnails", isDirectory: true)
        fullDir = historyDir.appendingPathComponent("full", isDirectory: true)
        jsonURL = historyDir.appendingPathComponent("history.json")

        // Clean history on every app launch
        try? FileManager.default.removeItem(at: historyDir)
        try? FileManager.default.createDirectory(at: thumbDir, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(at: fullDir, withIntermediateDirectories: true)
    }

    // MARK: - Add capture to history

    func add(image: NSImage, captureType: String, savedPath: URL? = nil) {
        let entry = HistoryEntry(
            id: UUID(),
            date: Date(),
            captureType: captureType,
            savedPath: savedPath?.path,
            thumbnailFilename: "\(UUID().uuidString).jpg",
            width: Int(image.size.width),
            height: Int(image.size.height)
        )

        // Generate thumbnail (200px wide)
        let thumbURL = thumbDir.appendingPathComponent(entry.thumbnailFilename)
        saveThumbnail(image: image, to: thumbURL, maxWidth: 200)

        // Save full image as PNG
        let fullURL = fullDir.appendingPathComponent("\(entry.id.uuidString).png")
        if let tiff = image.tiffRepresentation,
           let bitmap = NSBitmapImageRep(data: tiff),
           let png = bitmap.representation(using: .png, properties: [:]) {
            try? png.write(to: fullURL)
        }

        entries.insert(entry, at: 0)

        // Enforce max entries
        while entries.count > maxEntries {
            let removed = entries.removeLast()
            try? FileManager.default.removeItem(at: thumbnailURL(for: removed))
            try? FileManager.default.removeItem(at: fullDir.appendingPathComponent("\(removed.id.uuidString).png"))
        }
        save()
    }

    func thumbnailURL(for entry: HistoryEntry) -> URL {
        thumbDir.appendingPathComponent(entry.thumbnailFilename)
    }

    func thumbnailImage(for entry: HistoryEntry) -> NSImage? {
        NSImage(contentsOf: thumbnailURL(for: entry))
    }

    /// Load full image from history cache, or savedPath fallback
    func fullImage(for entry: HistoryEntry) -> NSImage? {
        let fullURL = fullDir.appendingPathComponent("\(entry.id.uuidString).png")
        if let img = NSImage(contentsOf: fullURL) { return img }
        if let path = entry.savedPath { return NSImage(contentsOfFile: path) }
        return nil
    }

    func delete(_ entry: HistoryEntry) {
        entries.removeAll { $0.id == entry.id }
        try? FileManager.default.removeItem(at: thumbnailURL(for: entry))
        try? FileManager.default.removeItem(at: fullDir.appendingPathComponent("\(entry.id.uuidString).png"))
        save()
    }

    func deleteAll() {
        for entry in entries {
            try? FileManager.default.removeItem(at: thumbnailURL(for: entry))
            try? FileManager.default.removeItem(at: fullDir.appendingPathComponent("\(entry.id.uuidString).png"))
        }
        entries.removeAll()
        save()
    }

    // MARK: - Persistence

    private func save() {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        try? data.write(to: jsonURL)
    }

    private func load() {
        guard let data = try? Data(contentsOf: jsonURL),
              let decoded = try? JSONDecoder().decode([HistoryEntry].self, from: data) else { return }
        entries = decoded
    }

    private func cleanup() {
        guard entries.count > maxEntries else { return }
        let removed = entries[maxEntries...]
        for entry in removed {
            try? FileManager.default.removeItem(at: thumbnailURL(for: entry))
        }
        entries = Array(entries.prefix(maxEntries))
        save()
    }

    // MARK: - Thumbnail generation

    private func saveThumbnail(image: NSImage, to url: URL, maxWidth: CGFloat) {
        let aspect = image.size.height / max(image.size.width, 1)
        let thumbW = min(maxWidth, image.size.width)
        let thumbH = thumbW * aspect
        let thumbSize = NSSize(width: thumbW, height: thumbH)

        let thumb = NSImage(size: thumbSize, flipped: false) { bounds in
            image.draw(in: bounds, from: NSRect(origin: .zero, size: image.size),
                       operation: .sourceOver, fraction: 1.0)
            return true
        }

        guard let tiff = thumb.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let jpeg = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.7]) else { return }
        try? jpeg.write(to: url)
    }
}
