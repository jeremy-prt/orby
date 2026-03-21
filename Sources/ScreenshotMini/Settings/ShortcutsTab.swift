import SwiftUI

struct ShortcutsTabView: View {
    var body: some View {
        Form {
            Section(L10n.lang == "en" ? "Capture" : "Capture") {
                HotkeySettingRow(slot: .fullscreen, label: L10n.lang == "en" ? "Full screen" : "Plein écran")
                HotkeySettingRow(slot: .area, label: L10n.lang == "en" ? "Area capture" : "Capture de zone")
                HotkeySettingRow(slot: .window, label: L10n.lang == "en" ? "Window capture" : "Capture de fenêtre")
                HotkeySettingRow(slot: .ocr, label: L10n.lang == "en" ? "Text capture" : "Capture texte")
            }
            Section(L10n.lang == "en" ? "General" : "Général") {
                HotkeySettingRow(slot: .history, label: L10n.lang == "en" ? "History" : "Historique")
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Hotkey Setting Row

struct HotkeySettingRow: View {
    let slot: HotkeySlot
    let label: String
    @ObservedObject private var manager = HotkeyManager.shared

    private var isRecordingThis: Bool {
        manager.isRecording && manager.recordingSlot == slot
    }

    private var combo: HotkeyCombo? {
        manager.combo(for: slot)
    }

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            HStack(spacing: 8) {
                Button {
                    if isRecordingThis {
                        manager.stopRecording()
                    } else {
                        manager.startRecording(slot: slot)
                    }
                } label: {
                    Group {
                        if isRecordingThis {
                            Text(L10n.pressKey)
                                .foregroundStyle(.orange)
                        } else if let combo {
                            Text(combo.displayString)
                                .foregroundStyle(.primary)
                        } else {
                            Text(L10n.setKey)
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

                if combo != nil {
                    Button {
                        manager.clearHotkey(slot)
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
