import SwiftUI

// MARK: - Screen position

enum ScreenPosition: String, CaseIterable {
    case bottomLeft = "bottomLeft"
    case bottomRight = "bottomRight"
    case topLeft = "topLeft"
    case topRight = "topRight"

    var label: String {
        let en = L10n.lang == "en"
        switch self {
        case .bottomLeft: return en ? "Bottom left" : "Bas gauche"
        case .bottomRight: return en ? "Bottom right" : "Bas droite"
        case .topLeft: return en ? "Top left" : "Haut gauche"
        case .topRight: return en ? "Top right" : "Haut droite"
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
    case png, jpeg, tiff

    var label: String {
        switch self {
        case .png: "PNG"
        case .jpeg: "JPEG"
        case .tiff: "TIFF"
        }
    }

    var description: String {
        let en = L10n.lang == "en"
        switch self {
        case .png: return en ? "Lossless, transparent" : "Sans perte, transparent"
        case .jpeg: return en ? "Compressed, lighter" : "Compressé, plus léger"
        case .tiff: return en ? "Lossless, high quality" : "Sans perte, haute qualité"
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
        case .about: L10n.lang == "en" ? "About" : "À propos"
        }
    }
}
