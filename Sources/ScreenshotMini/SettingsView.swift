import SwiftUI
import ServiceManagement

struct SettingsView: View {
    var body: some View {
        Form {
            Section("Raccourci") {
                HotkeySettingView()
            }

            Section("General") {
                LaunchAtLoginToggle()
            }
        }
        .formStyle(.grouped)
        .frame(width: 360)
        .fixedSize(horizontal: false, vertical: true)
        .onAppear {
            DispatchQueue.main.async {
                NSApp.activate(ignoringOtherApps: true)
                if let window = NSApp.windows.last(where: { $0.isVisible && $0.canBecomeKey }) {
                    window.makeKeyAndOrderFront(nil)
                    window.orderFrontRegardless()
                }
            }
        }
    }
}

struct HotkeySettingView: View {
    @ObservedObject private var manager = HotkeyManager.shared

    var body: some View {
        HStack {
            Text("Capture d'ecran")
            Spacer()
            HStack(spacing: 8) {
                Button {
                    if manager.isRecording {
                        manager.stopRecording()
                    } else {
                        manager.startRecording()
                    }
                } label: {
                    Group {
                        if manager.isRecording {
                            Text("Appuyez...")
                                .foregroundStyle(.orange)
                        } else if let combo = manager.currentHotkey {
                            Text(combo.displayString)
                                .foregroundStyle(.primary)
                        } else {
                            Text("Definir")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .font(.system(.callout, design: .rounded))
                    .frame(minWidth: 60)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(.quaternary, in: Capsule())
                }
                .buttonStyle(.plain)

                if manager.currentHotkey != nil {
                    Button {
                        manager.clearHotkey()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

struct LaunchAtLoginToggle: View {
    @StateObject private var model = LaunchAtLoginModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Toggle("Lancer au demarrage", isOn: Binding(
                get: { model.isEnabled },
                set: { model.setEnabled($0) }
            ))
            .disabled(!model.isSupported)

            if let message = model.message {
                Text(message)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

@MainActor
final class LaunchAtLoginModel: ObservableObject {
    @Published private(set) var isEnabled = false
    @Published private(set) var isSupported: Bool
    @Published private(set) var message: String?

    init() {
        let appURL = Bundle.main.bundleURL.resolvingSymlinksInPath().standardizedFileURL
        let appPath = appURL.path
        let appDirs = [
            URL(fileURLWithPath: "/Applications", isDirectory: true),
            FileManager.default.homeDirectoryForCurrentUser.appending(path: "Applications", directoryHint: .isDirectory)
        ]
        isSupported = appDirs.contains { dir in
            let dirPath = dir.resolvingSymlinksInPath().standardizedFileURL.path
            return appPath == dirPath || appPath.hasPrefix(dirPath + "/")
        }

        guard isSupported else {
            message = "Installez l'app dans /Applications pour activer cette option"
            return
        }
        isEnabled = SMAppService.mainApp.status == .enabled
    }

    func setEnabled(_ enabled: Bool) {
        guard isSupported else { return }
        do {
            if enabled { try SMAppService.mainApp.register() }
            else { try SMAppService.mainApp.unregister() }
            isEnabled = enabled
            message = nil
        } catch {
            isEnabled = SMAppService.mainApp.status == .enabled
            message = "Impossible de modifier le reglage"
        }
    }
}
