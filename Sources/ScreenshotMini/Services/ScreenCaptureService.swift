import AppKit
import Vision

@MainActor
class ScreenCaptureService {

    func captureFullScreen() async {
        await capture(arguments: ["-x"])
    }

    func captureArea() async {
        await capture(arguments: ["-x", "-s"])
    }

    func captureWindow() async {
        await capture(arguments: ["-x", "-w"])
    }

    func captureOCR() async {
        // Capture area silently
        let tempURL = FileManager.default.temporaryDirectory.appending(path: "ocr_\(UUID().uuidString).png")
        let args = ["-x", "-s", tempURL.path]

        let nsImage: NSImage? = await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
                process.arguments = args

                do {
                    try process.run()
                    process.waitUntilExit()
                    guard process.terminationStatus == 0 else {
                        continuation.resume(returning: nil)
                        return
                    }
                    let image = NSImage(contentsOf: tempURL)
                    try? FileManager.default.removeItem(at: tempURL)
                    continuation.resume(returning: image)
                } catch {
                    continuation.resume(returning: nil)
                }
            }
        }

        guard let nsImage, let cgImage = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return }

        // OCR via Vision
        let ocrLang = UserDefaults.standard.string(forKey: "ocrLanguage") ?? "fr"
        let languages: [String] = ocrLang == "en" ? ["en-US"] : ["fr-FR"]

        let text: String? = await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: nil)
                    return
                }
                let lines = observations.compactMap { $0.topCandidates(1).first?.string }
                let result = lines.joined(separator: "\n")
                continuation.resume(returning: result.isEmpty ? nil : result)
            }
            request.recognitionLevel = .accurate
            request.recognitionLanguages = languages
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(returning: nil)
            }
        }

        if let text {
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(text, forType: .string)
            let flat = text.replacingOccurrences(of: "\n", with: " ")
            let truncated = flat.count > 50 ? String(flat.prefix(50)) + "..." : flat
            ToastManager.shared.show(
                message: L10n.lang == "en" ? "Text copied!" : "Texte copié !",
                preview: truncated
            )
        } else {
            ToastManager.shared.show(message: L10n.lang == "en" ? "No text found" : "Aucun texte trouvé")
        }
    }

    private func capture(arguments baseArgs: [String]) async {
        let tempURL = FileManager.default.temporaryDirectory.appending(path: "screenshot_\(UUID().uuidString).png")
        let args = baseArgs + [tempURL.path]

        let nsImage: NSImage? = await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
                process.arguments = args

                do {
                    try process.run()
                    process.waitUntilExit()

                    guard process.terminationStatus == 0 else {
                        continuation.resume(returning: nil)
                        return
                    }
                    let image = NSImage(contentsOf: tempURL)
                    try? FileManager.default.removeItem(at: tempURL)
                    continuation.resume(returning: image)
                } catch {
                    continuation.resume(returning: nil)
                }
            }
        }

        guard let nsImage else { return }

        playCaptureSound()

        // Determine capture type from arguments
        let captureType: String
        if baseArgs.contains("-w") { captureType = "window" }
        else if baseArgs.contains("-s") { captureType = "area" }
        else { captureType = "fullscreen" }

        let defaults = UserDefaults.standard

        // Copy to clipboard
        if defaults.object(forKey: "afterCaptureCopyClipboard") as? Bool ?? true {
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.writeObjects([nsImage])
        }

        // Save to disk
        var savedURL: URL? = nil
        if defaults.bool(forKey: "afterCaptureSave") {
            savedURL = saveToDisk(image: nsImage)
        }

        // Record in history
        HistoryManager.shared.add(image: nsImage, captureType: captureType, savedPath: savedURL)

        // Open editor
        if defaults.bool(forKey: "afterCaptureOpenEditor") {
            let savePath = self.savePath
            EditorWindow.shared.open(image: nsImage, savePath: savePath)
            return // don't show preview if editor opens
        }

        // Show preview
        if defaults.object(forKey: "afterCaptureShowPreview") as? Bool ?? true {
            // Close existing previews if multi-preview is off
            if !(defaults.object(forKey: "multiPreview") as? Bool ?? true) {
                ThumbnailPanel.shared.dismissAll()
            }
            ThumbnailPanel.shared.show(image: nsImage)
        }
    }

    private var savePath: URL {
        let path = UserDefaults.standard.string(forKey: "savePath") ?? ""
        if path.isEmpty {
            return FileManager.default.homeDirectoryForCurrentUser.appending(path: "Desktop")
        }
        return URL(fileURLWithPath: path)
    }

    @discardableResult
    private func saveToDisk(image: NSImage) -> URL? {
        guard let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff) else { return nil }

        let format = UserDefaults.standard.string(forKey: "imageFormat") ?? "png"
        let fileType: NSBitmapImageRep.FileType
        let ext: String
        switch format {
        case "jpeg": fileType = .jpeg; ext = "jpg"
        case "tiff": fileType = .tiff; ext = "tiff"
        default: fileType = .png; ext = "png"
        }
        let properties: [NSBitmapImageRep.PropertyKey: Any] = fileType == .jpeg ? [.compressionFactor: 0.9] : [:]
        guard let data = bitmap.representation(using: fileType, properties: properties) else { return nil }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let filename = "Screenshot_\(formatter.string(from: Date())).\(ext)"
        let url = savePath.appending(path: filename)
        try? data.write(to: url)
        return url
    }

    private func playCaptureSound() {
        guard UserDefaults.standard.bool(forKey: "playSound") else { return }
        let path = "/System/Library/Components/CoreAudio.component/Contents/SharedSupport/SystemSounds/system/Screen Capture.aif"
        NSSound(contentsOfFile: path, byReference: true)?.play()
    }
}
