import SwiftUI

struct GeneralTabView: View {
    @AppStorage("appLanguage") private var appLanguage = "fr"
    @AppStorage("ocrLanguage") private var ocrLanguage = "fr"
    @AppStorage("showMenuBarIcon") private var showMenuBarIcon = true
    @AppStorage("playSound") private var playSound = true
    @AppStorage("appTheme") private var appTheme = "system"

    var body: some View {
        Form {
            Section(L10n.lang == "en" ? "Appearance" : "Apparence") {
                Picker(L10n.lang == "en" ? "Theme" : "Thème", selection: $appTheme) {
                    Text(L10n.lang == "en" ? "System" : "Système").tag("system")
                    Text(L10n.lang == "en" ? "Light" : "Clair").tag("light")
                    Text(L10n.lang == "en" ? "Dark" : "Sombre").tag("dark")
                }
                .pickerStyle(.segmented)
                .onChange(of: appTheme) { _, newValue in
                    applyTheme(newValue)
                }
            }

            Section(L10n.lang == "en" ? "Menu bar" : "Barre des menus") {
                Toggle(
                    L10n.lang == "en" ? "Show icon in menu bar" : "Afficher l'icône dans la barre des menus",
                    isOn: $showMenuBarIcon
                )
                if !showMenuBarIcon {
                    Text(L10n.lang == "en"
                         ? "Use your keyboard shortcuts to capture. Right-click the app in the Dock or relaunch to access settings."
                         : "Utilisez vos raccourcis clavier pour capturer. Clic droit sur l'app dans le Dock ou relancez pour accéder aux réglages.")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
            }

            Section(L10n.startup) {
                LaunchAtLoginToggle()
            }

            Section(L10n.lang == "en" ? "Sound" : "Son") {
                Toggle(
                    L10n.lang == "en" ? "Play sound on capture" : "Jouer un son à la capture",
                    isOn: $playSound
                )
            }

            Section(L10n.language) {
                Picker(L10n.interfaceLanguage, selection: $appLanguage) {
                    Text("French").tag("fr")
                    Text("English").tag("en")
                }
                .pickerStyle(.segmented)
            }

            Section(L10n.lang == "en" ? "Text recognition (OCR)" : "Reconnaissance de texte (OCR)") {
                Picker(L10n.lang == "en" ? "Language" : "Langue", selection: $ocrLanguage) {
                    Text("French").tag("fr")
                    Text("English").tag("en")
                }
                .pickerStyle(.segmented)
            }
        }
        .formStyle(.grouped)
    }
}
