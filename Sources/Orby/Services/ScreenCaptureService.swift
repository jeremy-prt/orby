import AppKit
import os
import Vision

let ocrLog = Logger(subsystem: "com.local.Orby", category: "ocr")

/// Date du dernier echec de .accurate. Quand le Neural Engine est en defaut, il le reste :
/// inutile de refaire patienter l'utilisateur a chaque capture.
private let accurateFailure = OSAllocatedUnfairLock<Date?>(initialState: nil)

/// Distingue une capture sans texte d'une reconnaissance qui a echoue : l'utilisateur doit
/// savoir s'il faut recadrer ou si Vision est indisponible.
enum OCROutcome {
    case text(String)
    /// Texte obtenu par le mode rapide, donc incomplet : l'utilisateur doit le savoir.
    case partial(String)
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

        let outcome = await Self.recognizeText(in: cgImage, language: ocrLang)
        ocrLog.info("OCR en \(Date().timeIntervalSince(started), format: .fixed(precision: 2), privacy: .public)s")

        switch outcome {
        case .text(let text):
            copyToPasteboard(text)
            ToastManager.shared.show(
                title: L10n.tr4("Text copied!", "Texte copié !", "¡Texto copiado!", "Text kopiert!"),
                subtitle: preview(of: text)
            )
        case .partial(let text):
            copyToPasteboard(text)
            ToastManager.shared.show(
                title: L10n.tr4("Partial text copied", "Texte partiel copié",
                                "Texto parcial copiado", "Teilweiser Text kopiert"),
                subtitle: preview(of: text)
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

    private func copyToPasteboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    private func preview(of text: String) -> String {
        let flat = text.replacingOccurrences(of: "\n", with: " ")
        return flat.count > 50 ? String(flat.prefix(50)) + "..." : flat
    }

    private nonisolated static func visionLanguage(for setting: String) -> String {
        switch setting {
        case "en": return "en-US"
        case "es": return "es-ES"
        case "de": return "de-DE"
        default: return "fr-FR"
        }
    }

    /// Reconnaissance de texte, volontairement hors du MainActor.
    /// L'ancienne implementation utilisait VNRecognizeTextRequest dans un withCheckedContinuation :
    /// depuis macOS 26 cette API appelle son completion handler *puis* relance l'erreur, ce qui
    /// resumait la continuation deux fois (SWIFT TASK CONTINUATION MISUSE) et gelait le main thread.
    private nonisolated static func recognizeText(in cgImage: CGImage, language: String) async -> OCROutcome {
        let identifier = visionLanguage(for: language)

        // Mode rapide demande explicitement : .fast n'emprunte jamais le Neural Engine, donc il
        // repond toujours en quelques centaines de millisecondes, au prix d'une partie du texte.
        if UserDefaults.standard.bool(forKey: "ocrFastMode") {
            guard let text = await recognizeFast(cgImage, identifier) else { return .failed }
            return .text(text)
        }

        // .accurate a echoue recemment : le Neural Engine ne se repare pas tout seul en quelques
        // minutes, on ne refait pas patienter l'utilisateur pour rien.
        let lastFailure = accurateFailure.withLock { $0 }
        if let lastFailure, Date().timeIntervalSince(lastFailure) < 600 {
            guard let text = await recognizeFast(cgImage, identifier) else { return .failed }
            return .partial(text)
        }

        // Sinon les deux reconnaissances partent ensemble.
        //
        // .accurate est la bonne : sur une machine saine elle repond en moins d'une seconde et
        // rend tout le texte. Mais elle passe par le Neural Engine, et quand celui-ci est en
        // defaut (erreur e5rt 13, « recompilation necessaire », constatee sur macOS 27) elle
        // tourne plusieurs minutes sans jamais aboutir. On lance donc .fast en parallele plutot
        // qu'apres coup, pour qu'elle soit deja prete si .accurate se fait attendre.
        async let accurate = recognize(cgImage, identifier, level: .accurate, timeout: .seconds(2.5))
        async let fast = recognizeFast(cgImage, identifier)

        let outcome = await accurate
        guard case .failed = outcome else {
            _ = await fast   // consomme la tache concurrente
            accurateFailure.withLock { $0 = nil }
            return outcome
        }

        accurateFailure.withLock { $0 = Date() }
        ocrLog.info("OCR: .accurate indisponible, mode rapide pour les 10 prochaines minutes")
        guard let partial = await fast else { return .failed }
        return .partial(partial)
    }

    /// Volontairement sur l'ancienne API : le mode rapide de `RecognizeTextRequest` ne rend
    /// aucune observation sur macOS 26+, celui de `VNRecognizeTextRequest` en rend. Unifier les
    /// deux chemins sur l'API moderne casserait donc le repli.
    private nonisolated static func recognizeFast(_ cgImage: CGImage, _ identifier: String) async -> String? {
        await withCheckedContinuation { continuation in
            // perform() est synchrone : on l'appelle sur une file de fond, sans completion
            // handler, ce qui garantit une reprise unique de la continuation.
            DispatchQueue.global(qos: .userInitiated).async {
                let request = VNRecognizeTextRequest()
                request.recognitionLevel = .fast
                request.recognitionLanguages = [identifier]
                request.usesLanguageCorrection = true
                do {
                    try VNImageRequestHandler(cgImage: cgImage, options: [:]).perform([request])
                    let lines = (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }
                    let result = lines.joined(separator: "\n")
                    continuation.resume(returning: result.isEmpty ? nil : result)
                } catch {
                    ocrLog.error("Mode rapide en echec: \(error.localizedDescription, privacy: .public)")
                    continuation.resume(returning: nil)
                }
            }
        }
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
