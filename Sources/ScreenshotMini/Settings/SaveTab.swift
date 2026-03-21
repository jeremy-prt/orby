import SwiftUI

struct SaveTabView: View {
    @AppStorage("savePath") private var savePath = ""
    @AppStorage("imageFormat") private var imageFormat = "png"

    private var resolvedSavePath: String {
        savePath.isEmpty
            ? FileManager.default.homeDirectoryForCurrentUser.appending(path: "Desktop").path
            : savePath
    }

    var body: some View {
        Form {
            Section(L10n.imageFormat) {
                VStack(alignment: .leading, spacing: 8) {
                    Picker(L10n.format, selection: $imageFormat) {
                        ForEach(ImageFormat.allCases, id: \.rawValue) { fmt in
                            Text(fmt.label).tag(fmt.rawValue)
                        }
                    }
                    .pickerStyle(.segmented)

                    if let fmt = ImageFormat(rawValue: imageFormat) {
                        Text(fmt.description)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section(L10n.destinationFolder) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        HStack(spacing: 4) {
                            Image(systemName: "folder")
                                .foregroundStyle(.secondary)
                            Text(resolvedSavePath)
                                .font(.callout)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                        Spacer()
                        Button(L10n.choose) {
                            pickSaveFolder()
                        }
                        .controlSize(.small)
                    }
                    if !savePath.isEmpty {
                        Button(L10n.resetToDesktop) {
                            savePath = ""
                        }
                        .controlSize(.small)
                        .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .formStyle(.grouped)
    }

    private func pickSaveFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = L10n.lang == "en" ? "Choose" : "Choisir"
        panel.message = L10n.chooseFolder

        if panel.runModal() == .OK, let url = panel.url {
            savePath = url.path
        }
    }
}
