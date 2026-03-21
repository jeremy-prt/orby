import SwiftUI

struct CaptureTabView: View {
    @AppStorage("previewPosition") private var position = "bottomLeft"
    @AppStorage("dismissDelay") private var dismissDelay = 5.0
    @AppStorage("closeAfterAction") private var closeAfterAction = true
    @AppStorage("multiPreview") private var multiPreview = true
    @AppStorage("afterCaptureShowPreview") private var afterCaptureShowPreview = true
    @AppStorage("afterCaptureCopyClipboard") private var afterCaptureCopyClipboard = true
    @AppStorage("afterCaptureSave") private var afterCaptureSave = false
    @AppStorage("afterCaptureOpenEditor") private var afterCaptureOpenEditor = false
    @AppStorage("exportRetina") private var exportRetina = true

    var body: some View {
        let en = L10n.lang == "en"
        Form {
            // Actions after capture — first, because it determines what's shown below
            Section(en ? "After capture" : "Après la capture") {
                Toggle(en ? "Show preview" : "Afficher la preview", isOn: $afterCaptureShowPreview)
                Toggle(en ? "Copy to clipboard" : "Copier dans le presse-papier", isOn: $afterCaptureCopyClipboard)
                Toggle(en ? "Save to disk" : "Sauvegarder sur le disque", isOn: $afterCaptureSave)
                Toggle(en ? "Open editor" : "Ouvrir l'éditeur", isOn: $afterCaptureOpenEditor)

                Text(en
                     ? "Actions performed automatically after each capture"
                     : "Actions effectuées automatiquement après chaque capture")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Section(en ? "Resolution" : "Résolution") {
                VStack(alignment: .leading, spacing: 4) {
                    Picker(en ? "Export quality" : "Qualité d'export", selection: $exportRetina) {
                        Text("Retina (2x)").tag(true)
                        Text("Standard (1x)").tag(false)
                    }
                    .pickerStyle(.segmented)
                    Text(exportRetina
                         ? (en ? "Full Retina resolution — best quality, larger files" : "Résolution Retina complète — meilleure qualité, fichiers plus lourds")
                         : (en ? "Standard resolution — smaller files" : "Résolution standard — fichiers plus légers"))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            if afterCaptureShowPreview {
                Section(en ? "Preview" : "Prévisualisation") {
                    // Position
                    VStack(alignment: .leading, spacing: 6) {
                        Text(L10n.previewPosition)
                            .font(.callout)
                        HStack(spacing: 8) {
                            ForEach(ScreenPosition.allCases, id: \.rawValue) { pos in
                                Button {
                                    position = pos.rawValue
                                } label: {
                                    VStack(spacing: 4) {
                                        Image(systemName: pos.icon)
                                            .font(.system(size: 16))
                                        Text(pos.label)
                                            .font(.caption2)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(position == pos.rawValue ? brandPurple.opacity(0.15) : Color.clear)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(position == pos.rawValue ? brandPurple : Color.secondary.opacity(0.3), lineWidth: 1)
                                    )
                                }
                                .buttonStyle(.plain)
                                .foregroundStyle(position == pos.rawValue ? .primary : .secondary)
                            }
                        }
                    }

                    // Stack
                    VStack(alignment: .leading, spacing: 2) {
                        Toggle(
                            en ? "Stack multiple previews" : "Empiler les prévisualisations",
                            isOn: $multiPreview
                        )
                        Text(en
                             ? "Multiple captures stack on screen. Otherwise, the previous one closes."
                             : "Les captures s'empilent à l'écran. Sinon, la précédente se ferme.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    // Auto-close delay
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(en ? "Auto-close delay" : "Fermeture automatique")
                            Spacer()
                            Text("\(Int(dismissDelay))s")
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                        Slider(value: $dismissDelay, in: 3...60, step: 1)
                            .controlSize(.small)
                        Text(en
                             ? "Time before the preview disappears automatically"
                             : "Durée avant que la preview disparaisse automatiquement")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    // Close after action
                    VStack(alignment: .leading, spacing: 2) {
                        Toggle(L10n.closeAfterAction, isOn: $closeAfterAction)
                        Text(en
                             ? "Close the preview after clicking Copy or Save"
                             : "Ferme la preview après avoir cliqué Copy ou Save")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .formStyle(.grouped)
    }
}
