import SwiftUI

// MARK: - Screen position

enum ScreenPosition: String, CaseIterable {
    case bottomLeft = "bottomLeft"
    case bottomRight = "bottomRight"
    case topLeft = "topLeft"
    case topRight = "topRight"

    var label: String {
        switch self {
        case .bottomLeft: return L10n.tr4("Bottom left", "Bas gauche", "Abajo izquierda", "Unten links")
        case .bottomRight: return L10n.tr4("Bottom right", "Bas droite", "Abajo derecha", "Unten rechts")
        case .topLeft: return L10n.tr4("Top left", "Haut gauche", "Arriba izquierda", "Oben links")
        case .topRight: return L10n.tr4("Top right", "Haut droite", "Arriba derecha", "Oben rechts")
        }
    }

    var icon: String {
        switch self {
        case .bottomLeft: "arrow.down.left"
        case .bottomRight: "arrow.down.right"
        case .topLeft: "arrow.up.left"
        case .topRight: "arrow.up.right"
        }
    }
}

// MARK: - Image format

enum ImageFormat: String, CaseIterable {
    case png, jpeg, webp, tiff

    var label: String {
        switch self {
        case .png: "PNG"
        case .jpeg: "JPEG"
        case .webp: "WebP"
        case .tiff: "TIFF"
        }
    }

    var description: String {
        switch self {
        case .png: return L10n.tr4("Lossless, transparent", "Sans perte, transparent", "Sin pérdida, transparente", "Verlustfrei, transparent")
        case .jpeg: return L10n.tr4("Compressed, lighter", "Compressé, plus léger", "Comprimido, más ligero", "Komprimiert, leichter")
        case .webp: return L10n.tr4("Modern, lightweight", "Moderne, léger", "Moderno, ligero", "Modern, leicht")
        case .tiff: return L10n.tr4("Lossless, high quality", "Sans perte, haute qualité", "Sin pérdida, alta calidad", "Verlustfrei, hohe Qualität")
        }
    }
}

// MARK: - Settings Tabs

enum SettingsTab: String, CaseIterable {
    case general, raccourcis, capture, sauvegarde, about

    var icon: String {
        switch self {
        case .general: "gearshape"
        case .raccourcis: "keyboard"
        case .capture: "camera.viewfinder"
        case .sauvegarde: "folder"
        case .about: "info.circle"
        }
    }

    var label: String {
        switch self {
        case .general: L10n.settingsGeneral
        case .raccourcis: L10n.shortcut
        case .capture: L10n.settingsCapture
        case .sauvegarde: L10n.settingsSave
        case .about: L10n.tr4("About", "À propos", "Acerca de", "Über")
        }
    }
}
