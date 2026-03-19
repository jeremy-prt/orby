import Carbon
import AppKit

@MainActor
class HotkeyManager: ObservableObject {
    @Published var currentHotkey: HotkeyCombo? {
        didSet {
            save()
            registerHotkey()
        }
    }
    @Published var isRecording = false

    var onTrigger: (() -> Void)?

    private var hotkeyRef: EventHotKeyRef?
    private var monitor: Any?

    static let shared = HotkeyManager()

    init() {
        load()
    }

    func registerHotkey() {
        unregisterHotkey()
        guard let combo = currentHotkey else { return }

        let hotKeyID = EventHotKeyID(signature: OSType(0x53534D49), id: 1) // "SSMI"
        let status = RegisterEventHotKey(
            UInt32(combo.carbonKeyCode),
            UInt32(combo.carbonModifiers),
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotkeyRef
        )

        if status == noErr {
            installHandler()
        }
    }

    private func unregisterHotkey() {
        if let ref = hotkeyRef {
            UnregisterEventHotKey(ref)
            hotkeyRef = nil
        }
    }

    private func installHandler() {
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, event, _ -> OSStatus in
            MainActor.assumeIsolated {
                HotkeyManager.shared.onTrigger?()
            }
            return noErr
        }, 1, &eventType, nil, nil)
    }

    func startRecording() {
        isRecording = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            let keyCode = Int(event.keyCode)
            let modifiers = event.modifierFlags.intersection([.command, .option, .control, .shift])
            MainActor.assumeIsolated {
                guard let self, self.isRecording else { return }
                guard !modifiers.isEmpty else { return }

                self.currentHotkey = HotkeyCombo(keyCode: keyCode, modifiers: modifiers)
                self.isRecording = false
                if let m = self.monitor {
                    NSEvent.removeMonitor(m)
                    self.monitor = nil
                }
            }
            return nil
        }
    }

    func stopRecording() {
        isRecording = false
        if let m = monitor {
            NSEvent.removeMonitor(m)
            monitor = nil
        }
    }

    func clearHotkey() {
        unregisterHotkey()
        currentHotkey = nil
    }

    private func save() {
        if let combo = currentHotkey {
            UserDefaults.standard.set(combo.keyCode, forKey: "hotkeyKeyCode")
            UserDefaults.standard.set(combo.modifiers.rawValue, forKey: "hotkeyModifiers")
        } else {
            UserDefaults.standard.removeObject(forKey: "hotkeyKeyCode")
            UserDefaults.standard.removeObject(forKey: "hotkeyModifiers")
        }
    }

    private func load() {
        let keyCode = UserDefaults.standard.integer(forKey: "hotkeyKeyCode")
        let rawMods = UserDefaults.standard.integer(forKey: "hotkeyModifiers")
        if rawMods != 0 {
            currentHotkey = HotkeyCombo(keyCode: keyCode, modifiers: NSEvent.ModifierFlags(rawValue: UInt(rawMods)))
        }
    }
}

struct HotkeyCombo: Equatable {
    let keyCode: Int
    let modifiers: NSEvent.ModifierFlags

    var displayString: String {
        var parts: [String] = []
        if modifiers.contains(.control) { parts.append("⌃") }
        if modifiers.contains(.option) { parts.append("⌥") }
        if modifiers.contains(.shift) { parts.append("⇧") }
        if modifiers.contains(.command) { parts.append("⌘") }
        parts.append(keyName)
        return parts.joined()
    }

    private var keyName: String {
        let mapping: [Int: String] = [
            0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X",
            8: "C", 9: "V", 11: "B", 12: "Q", 13: "W", 14: "E", 15: "R",
            16: "Y", 17: "T", 18: "1", 19: "2", 20: "3", 21: "4", 22: "6",
            23: "5", 24: "=", 25: "9", 26: "7", 27: "-", 28: "8", 29: "0",
            30: "]", 31: "O", 32: "U", 33: "[", 34: "I", 35: "P", 37: "L",
            38: "J", 39: "'", 40: "K", 41: ";", 42: "\\", 43: ",", 44: "/",
            45: "N", 46: "M", 47: ".", 49: "Space", 50: "`",
            96: "F5", 97: "F6", 98: "F7", 99: "F3", 100: "F8",
            101: "F9", 109: "F10", 111: "F12", 103: "F11",
            118: "F4", 120: "F2", 122: "F1",
        ]
        return mapping[keyCode] ?? "?"
    }

    var carbonKeyCode: Int { keyCode }

    var carbonModifiers: Int {
        var mods = 0
        if modifiers.contains(.command) { mods |= cmdKey }
        if modifiers.contains(.option) { mods |= optionKey }
        if modifiers.contains(.control) { mods |= controlKey }
        if modifiers.contains(.shift) { mods |= shiftKey }
        return mods
    }
}
