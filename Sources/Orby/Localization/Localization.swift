import Foundation

/// Simple in-app localization based on UserDefaults "appLanguage" key
enum L10n {
    static var lang: String {
        UserDefaults.standard.string(forKey: "appLanguage") ?? "fr"
    }

    // MARK: - Preview tooltips
    static var tooltipCopy: String { lang == "en" ? "Copy to clipboard" : "Copier dans le presse-papier" }
    static var tooltipSave: String { lang == "en" ? "Save to disk" : "Sauvegarder sur le disque" }
    static var tooltipPin: String { lang == "en" ? "Pin" : "Épingler" }
    static var tooltipUnpin: String { lang == "en" ? "Unpin" : "Désépingler" }
    static var tooltipClose: String { lang == "en" ? "Close" : "Fermer" }
    static var tooltipEdit: String { lang == "en" ? "Annotate" : "Annoter" }

    // MARK: - Menu
    static var menuCapture: String { lang == "en" ? "Capture" : "Capturer" }
    static var menuSettings: String { lang == "en" ? "Settings" : "Réglages" }
    static var menuQuit: String { lang == "en" ? "Quit" : "Quitter" }

    // MARK: - Settings
    static var settingsGeneral: String { lang == "en" ? "General" : "Général" }
    static var settingsCapture: String { lang == "en" ? "Capture" : "Capture" }
    static var settingsSave: String { lang == "en" ? "Save" : "Sauvegarde" }

    static var shortcut: String { lang == "en" ? "Shortcut" : "Raccourci" }
    static var screenshot: String { lang == "en" ? "Screenshot" : "Capture d'écran" }
    static var startup: String { lang == "en" ? "Startup" : "Démarrage" }
    static var launchAtLogin: String { lang == "en" ? "Launch at login" : "Lancer au démarrage" }
    static var language: String { lang == "en" ? "Language" : "Langue" }
    static var interfaceLanguage: String { lang == "en" ? "Interface language" : "Langue de l'interface" }

    static var previewPosition: String { lang == "en" ? "Preview position" : "Position de la prévisualisation" }
    static var autoDismiss: String { lang == "en" ? "Auto close" : "Fermeture automatique" }
    static var delay: String { lang == "en" ? "Delay" : "Délai" }
    static var autoDismissDescription: String { lang == "en" ? "Time before the preview disappears" : "Durée avant que la prévisualisation disparaisse" }
    static var afterAction: String { lang == "en" ? "After action" : "Après une action" }
    static var closeAfterAction: String { lang == "en" ? "Close after Copy / Save" : "Fermer après Copy / Save" }
    static var closeAfterActionDescription: String { lang == "en" ? "Automatically close the preview after copying or saving" : "Ferme automatiquement la prévisualisation après avoir copié ou sauvegardé" }

    static var imageFormat: String { lang == "en" ? "Image format" : "Format d'image" }
    static var format: String { lang == "en" ? "Format" : "Format" }
    static var destinationFolder: String { lang == "en" ? "Destination folder" : "Dossier de destination" }
    static var choose: String { lang == "en" ? "Choose..." : "Choisir..." }
    static var resetToDesktop: String { lang == "en" ? "Reset to Desktop" : "Remettre Bureau par défaut" }
    static var chooseFolder: String { lang == "en" ? "Choose save folder" : "Choisir le dossier de sauvegarde des captures" }

    // MARK: - Editor toolbar
    static var editorCopy: String { lang == "en" ? "Copy" : "Copier" }
    static var editorSave: String { lang == "en" ? "Save" : "Sauvegarder" }
    static var editorApply: String { lang == "en" ? "Apply" : "Appliquer" }

    static var pressKey: String { lang == "en" ? "Press..." : "Appuyez..." }
    static var setKey: String { lang == "en" ? "Set" : "Définir" }
    static var installInApps: String { lang == "en" ? "Install the app in /Applications to enable this option" : "Installez l'app dans /Applications pour activer cette option" }
    static var cannotModify: String { lang == "en" ? "Cannot modify setting" : "Impossible de modifier le réglage" }
}
