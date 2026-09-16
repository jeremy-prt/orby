import SwiftUI

struct GeneralTabView: View {
    @AppStorage("appLanguage") private var appLanguage = "fr"
    @AppStorage("ocrLanguage") private var ocrLanguage = "fr"
    @AppStorage("ocrFastMode") private var ocrFastMode = false
    @AppStorage("showMenuBarIcon") private var showMenuBarIcon = true
    @AppStorage("playSound") private var playSound = true
    @AppStorage("appTheme") private var appTheme = "system"

    var body: some View {
        Form {
            Section(L10n.tr4("Appearance", "Apparence", "Apariencia", "Erscheinungsbild")) {
                Picker(L10n.tr4("Theme", "Thème", "Tema", "Design"), selection: $appTheme) {
                    Text(L10n.tr4("System", "Système", "Sistema", "System")).tag("system")
                    Text(L10n.tr4("Light", "Clair", "Claro", "Hell")).tag("light")
                    Text(L10n.tr4("Dark", "Sombre", "Oscuro", "Dunkel")).tag("dark")
                }
                .pickerStyle(.segmented)
                .onChange(of: appTheme) { _, newValue in
                    applyTheme(newValue)
                }
            }

            Section(L10n.tr4("Menu bar", "Barre des menus", "Barra de menús", "Menüleiste")) {
                Toggle(
                    L10n.tr4("Show icon in menu bar", "Afficher l'icône dans la barre des menus", "Mostrar icono en la barra de menús", "Symbol in der Menüleiste anzeigen"),
                    isOn: $showMenuBarIcon
                )
                if !showMenuBarIcon {
                    Text(L10n.tr4(
                         "Use your keyboard shortcuts to capture. Right-click the app in the Dock or relaunch to access settings.",
                         "Utilisez vos raccourcis clavier pour capturer. Clic droit sur l'app dans le Dock ou relancez pour accéder aux réglages.",
                         "Usa tus atajos de teclado para capturar. Haz clic derecho en la app en el Dock o reinicia para acceder a los ajustes.",
                         "Verwenden Sie Ihre Tastaturkürzel zum Erfassen. Klicken Sie mit der rechten Maustaste auf die App im Dock oder starten Sie neu, um auf Einstellungen zuzugreifen."))
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
            }

            Section(L10n.startup) {
                LaunchAtLoginToggle()
            }

            Section(L10n.tr4("Sound", "Son", "Sonido", "Ton")) {
                Toggle(
                    L10n.tr4("Play sound on capture", "Jouer un son à la capture", "Reproducir sonido al capturar", "Ton bei Aufnahme abspielen"),
                    isOn: $playSound
                )
            }

            Section(L10n.language) {
                Picker(L10n.interfaceLanguage, selection: $appLanguage) {
                    Text("Français").tag("fr")
                    Text("English").tag("en")
                    Text("Español").tag("es")
                    Text("Deutsch").tag("de")
                }
                .pickerStyle(.menu)

                Toggle(L10n.tr4("Fast mode", "Mode rapide", "Modo rápido", "Schnellmodus"),
                       isOn: $ocrFastMode)
                Text(L10n.tr4("Instant, but recognizes less text on dense screenshots.",
                              "Instantané, mais reconnaît moins de texte sur les captures denses.",
                              "Instantáneo, pero reconoce menos texto en capturas densas.",
                              "Sofort, erkennt aber weniger Text bei dichten Aufnahmen."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section(L10n.tr4("Text recognition (OCR)", "Reconnaissance de texte (OCR)", "Reconocimiento de texto (OCR)", "Texterkennung (OCR)")) {
                Picker(L10n.tr4("Language", "Langue", "Idioma", "Sprache"), selection: $ocrLanguage) {
                    Text("Français").tag("fr")
                    Text("English").tag("en")
                    Text("Español").tag("es")
                    Text("Deutsch").tag("de")
                }
                .pickerStyle(.menu)
            }
        }
        .formStyle(.grouped)
    }
}
