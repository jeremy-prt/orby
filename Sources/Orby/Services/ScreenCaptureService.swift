import AppKit
import CoreText
import OSLog
import Vision

let ocrLog = Logger(subsystem: "com.local.Orby", category: "ocr")

/// Distingue une capture sans texte d'une reconnaissance qui a echoue : l'utilisateur doit
/// savoir s'il faut recadrer ou si Vision est indisponible.
enum OCROutcome {
    case text(String)
    case empty
    case failed
}

@MainActor
class ScreenCaptureService {

    func captureFullScreen() async {
        await capture(arguments: ["-x"])
    }

    func captureArea() async {
        await capture(arguments: ["-x", "-s"])
    }

    func captureWindow() async {
        await capture(arguments: ["-x", "-w", "-o"])
    }

    func captureOCR() async {
        // Capture area silently
        let tempURL = FileManager.default.temporaryDirectory.appending(path: "ocr_\(UUID().uuidString).png")
        let args = ["-x", "-s", tempURL.path]
        ocrLog.info("captureOCR: lancement screencapture vers \(tempURL.path, privacy: .public)")

        // On decode le PNG en memoire avant de supprimer le fichier : NSImage(contentsOf:) est
        // paresseux et rendrait une image sans pixels une fois le temporaire efface, ce que Vision
        // signale par un CRImageReaderError apres une vingtaine de secondes.
        let cgImage: CGImage? = await withCheckedContinuation { continuation in
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
                    let data = try? Data(contentsOf: tempURL)
                    try? FileManager.default.removeItem(at: tempURL)
                    guard let data,
                          let source = CGImageSourceCreateWithData(data as CFData, nil),
                          let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
                        ocrLog.error("captureOCR: PNG illisible (\(data?.count ?? -1, privacy: .public) octets)")
                        continuation.resume(returning: nil)
                        return
                    }
                    continuation.resume(returning: image)
                } catch {
                    ocrLog.error("screencapture a echoue: \(error.localizedDescription, privacy: .public)")
                    continuation.resume(returning: nil)
                }
            }
        }

        guard let cgImage else { return }

        // OCR via Vision, execute hors du main thread
        let ocrLang = UserDefaults.standard.string(forKey: "ocrLanguage") ?? "fr"
        let started = Date()

        // Vision peut mettre jusqu'a une minute a recompiler son modele apres une mise a jour
        // de macOS : sans ce toast, l'app parait simplement figee.
        let pending = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            ToastManager.shared.show(
                title: L10n.tr4("Reading text...", "Lecture du texte...", "Leyendo texto...", "Text wird gelesen..."),
                icon: "text.viewfinder",
                autoDismiss: false
            )
        }

        let outcome = await Self.recognizeText(in: cgImage, language: ocrLang)
        pending.cancel()
        ocrLog.info("OCR en \(Date().timeIntervalSince(started), format: .fixed(precision: 2), privacy: .public)s")

        switch outcome {
        case .text(let text):
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(text, forType: .string)
            let flat = text.replacingOccurrences(of: "\n", with: " ")
            let truncated = flat.count > 50 ? String(flat.prefix(50)) + "..." : flat
            ToastManager.shared.show(
                title: L10n.tr4("Text copied!", "Texte copié !", "¡Texto copiado!", "Text kopiert!"),
                subtitle: truncated
            )
        case .empty:
            ToastManager.shared.show(
                title: L10n.tr4("No text found", "Aucun texte trouvé", "No se encontró texto", "Kein Text gefunden"),
                icon: "text.viewfinder"
            )
        case .failed:
            ToastManager.shared.show(
                title: L10n.tr4("Text recognition unavailable", "Reconnaissance indisponible",
                                "Reconocimiento no disponible", "Texterkennung nicht verfügbar"),
                icon: "exclamationmark.triangle.fill"
            )
        }
    }

    private nonisolated static func visionLanguage(for setting: String) -> String {
        switch setting {
        case "en": return "en-US"
        case "es": return "es-ES"
        case "de": return "de-DE"
        default: return "fr-FR"
        }
    }

    /// Le premier appel a Vision recharge son modele de reconnaissance. C'est immediat sur une
    /// machine saine, mais cela peut prendre une minute quand le cache du Neural Engine n'est pas
    /// conservé (disque sature, erreurs e5rt). On paie ce cout une fois au lancement, en tache de
    /// fond, plutot que sur le premier raccourci de l'utilisateur.
    nonisolated static func warmUpOCR() {
        Task.detached(priority: .utility) {
            let language = visionLanguage(for: UserDefaults.standard.string(forKey: "ocrLanguage") ?? "fr")
            guard let sample = warmUpImage() else { return }
            let started = Date()
            let outcome = await recognize(sample, language, level: .accurate, timeout: .seconds(180))
            if case .text = outcome {
                ocrLog.info("prechauffage OCR reussi en \(Date().timeIntervalSince(started), format: .fixed(precision: 2), privacy: .public)s")
            } else {
                ocrLog.error("prechauffage OCR echoue apres \(Date().timeIntervalSince(started), format: .fixed(precision: 2), privacy: .public)s")
            }
        }
    }

    /// Vision rejette une image sans texte (CRImageReaderError) : la mire de chauffe en contient.
    private nonisolated static func warmUpImage() -> CGImage? {
        let width = 240, height = 80
        guard let context = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ) else { return nil }
        context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        let sample = NSAttributedString(string: "Orby 123", attributes: [
            .font: NSFont.systemFont(ofSize: 36),
            .foregroundColor: NSColor.black
        ])
        context.textPosition = CGPoint(x: 16, y: 24)
        CTLineDraw(CTLineCreateWithAttributedString(sample), context)
        return context.makeImage()
    }

    /// Reconnaissance de texte, volontairement hors du MainActor.
    /// L'ancienne implementation utilisait VNRecognizeTextRequest dans un withCheckedContinuation :
    /// depuis macOS 26 cette API appelle son completion handler *puis* relance l'erreur, ce qui
    /// resumait la continuation deux fois (SWIFT TASK CONTINUATION MISUSE) et gelait le main thread.
    private nonisolated static func recognizeText(in cgImage: CGImage, language: String) async -> OCROutcome {
        let identifier = visionLanguage(for: language)

        // Uniquement .accurate : mesure faite, .fast ne rend que 7 % du texte sur une capture
        // reelle (68 caracteres contre 926). Mieux vaut echouer franchement que coller un texte
        // tronque a l'insu de l'utilisateur. Le delai n'est la que pour ne jamais rester bloque.
        return await recognize(cgImage, identifier, level: .accurate, timeout: .seconds(120))
    }

    private nonisolated static func recognize(
        _ cgImage: CGImage,
        _ identifier: String,
        level: RecognizeTextRequest.RecognitionLevel,
        timeout: Duration
    ) async -> OCROutcome {
        await withTaskGroup(of: OCROutcome.self) { group in
            group.addTask {
                var request = RecognizeTextRequest()
                request.recognitionLevel = level
                request.recognitionLanguages = [Locale.Language(identifier: identifier)]
                request.usesLanguageCorrection = true
                do {
                    let observations = try await request.perform(on: cgImage)
                    let result = observations
                        .compactMap { $0.topCandidates(1).first?.string }
                        .joined(separator: "\n")
                    return result.isEmpty ? .empty : .text(result)
                } catch {
                    ocrLog.error("Vision a echoue: \(error.localizedDescription, privacy: .public)")
                    return .failed
                }
            }
            group.addTask {
                try? await Task.sleep(for: timeout)
                ocrLog.error("Vision n'a pas repondu en \(timeout.components.seconds, privacy: .public)s")
                return .failed
            }
            let first = await group.next() ?? .failed
            group.cancelAll()
            return first
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
                    // Charger les octets avant de supprimer : NSImage(contentsOf:) decode
                    // paresseusement et perdrait son contenu avec le fichier temporaire.
                    let image = (try? Data(contentsOf: tempURL)).flatMap(NSImage.init(data:))
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
