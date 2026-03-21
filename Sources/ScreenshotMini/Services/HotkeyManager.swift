import Carbon
import AppKit

enum HotkeySlot: String, CaseIterable {
    case fullscreen = "fullscreen"
    case area = "area"
    case window = "window"
    case ocr = "ocr"
    case history = "history"

    var signature: OSType {
        switch self {
        case .fullscreen: OSType(0x53534D31)
        case .area: OSType(0x53534D32)
        case .window: OSType(0x53534D34)
        case .ocr: OSType(0x53534D33)
        case .history: OSType(0x53534D35)
        }
    }

    var id: UInt32 {
        switch self {
        case .fullscreen: 1
        case .area: 2
        case .window: 4
        case .ocr: 3
        case .history: 5
        }
    }

    var keyCodeKey: String { "hotkeyKeyCode_\(rawValue)" }
    var modifiersKey: String { "hotkeyModifiers_\(rawValue)" }
}

@MainActor
class HotkeyManager: ObservableObject {
    @Published var fullscreenHotkey: HotkeyCombo? {
        didSet { save(.fullscreen); registerHotkey(.fullscreen) }
    }
    @Published var areaHotkey: HotkeyCombo? {
        didSet { save(.area); registerHotkey(.area) }
    }
    @Published var windowHotkey: HotkeyCombo? {
        didSet { save(.window); registerHotkey(.window) }
    }
    @Published var ocrHotkey: HotkeyCombo? {
        didSet { save(.ocr); registerHotkey(.ocr) }
    }
    @Published var historyHotkey: HotkeyCombo? {
        didSet { save(.history); registerHotkey(.history) }
    }
    @Published var isRecording = false
    @Published var recordingSlot: HotkeySlot?

    var onFullscreen: (() -> Void)?
    var onArea: (() -> Void)?
    var onWindow: (() -> Void)?
    var onOCR: (() -> Void)?
    var onHistory: (() -> Void)?

    private var hotkeyRefs: [HotkeySlot: EventHotKeyRef] = [:]
    private var monitor: Any?
    private var handlerInstalled = false

    static let shared = HotkeyManager()

    init() {
        load(.fullscreen)
        load(.area)
        load(.window)
        load(.ocr)
        load(.history)
    }

    func combo(for slot: HotkeySlot) -> HotkeyCombo? {
        switch slot {
        case .fullscreen: fullscreenHotkey
        case .area: areaHotkey
        case .window: windowHotkey
        case .ocr: ocrHotkey
        case .history: historyHotkey
        }
    }

    private func setCombo(_ combo: HotkeyCombo?, for slot: HotkeySlot) {
        switch slot {
        case .fullscreen: fullscreenHotkey = combo
        case .area: areaHotkey = combo
        case .window: windowHotkey = combo
        case .ocr: ocrHotkey = combo
        case .history: historyHotkey = combo
        }
    }

    func registerHotkey(_ slot: HotkeySlot) {
        unregisterHotkey(slot)
        guard let combo = combo(for: slot) else { return }

        let hotKeyID = EventHotKeyID(signature: slot.signature, id: slot.id)
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(
            UInt32(combo.carbonKeyCode),
            UInt32(combo.carbonModifiers),
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &ref
        )

        if status == noErr, let ref {
            hotkeyRefs[slot] = ref
            installHandler()
        }
    }

    private func unregisterHotkey(_ slot: HotkeySlot) {
        if let ref = hotkeyRefs[slot] {
            UnregisterEventHotKey(ref)
            hotkeyRefs[slot] = nil
        }
    }

    private func installHandler() {
        guard !handlerInstalled else { return }
        handlerInstalled = true

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, event, _ -> OSStatus in
            var hotKeyID = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject),
                              EventParamType(typeEventHotKeyID), nil,
                              MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID)

            MainActor.assumeIsolated {
                let mgr = HotkeyManager.shared
                switch hotKeyID.id {
                case 1: mgr.onFullscreen?()
                case 2: mgr.onArea?()
                case 3: mgr.onOCR?()
                case 4: mgr.onWindow?()
                case 5: mgr.onHistory?()
                default: break
                }
            }
            return noErr
        }, 1, &eventType, nil, nil)
    }

    func startRecording(slot: HotkeySlot) {
        isRecording = true
        recordingSlot = slot
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            let keyCode = Int(event.keyCode)
            let modifiers = event.modifierFlags.intersection([.command, .option, .control, .shift])
            MainActor.assumeIsolated {
                guard let self, self.isRecording, let slot = self.recordingSlot else { return }
                guard !modifiers.isEmpty else { return }

                self.setCombo(HotkeyCombo(keyCode: keyCode, modifiers: modifiers), for: slot)
                self.isRecording = false
                self.recordingSlot = nil
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
        recordingSlot = nil
        if let m = monitor {
            NSEvent.removeMonitor(m)
            monitor = nil
        }
    }

    func clearHotkey(_ slot: HotkeySlot) {
        unregisterHotkey(slot)
        setCombo(nil, for: slot)
    }

    private func save(_ slot: HotkeySlot) {
        if let combo = combo(for: slot) {
            UserDefaults.standard.set(combo.keyCode, forKey: slot.keyCodeKey)
            UserDefaults.standard.set(combo.modifiers.rawValue, forKey: slot.modifiersKey)
        } else {
            UserDefaults.standard.removeObject(forKey: slot.keyCodeKey)
            UserDefaults.standard.removeObject(forKey: slot.modifiersKey)
        }
    }

    private func load(_ slot: HotkeySlot) {
        // Migration: old keys → fullscreen slot
        if slot == .fullscreen {
            let oldKeyCode = UserDefaults.standard.integer(forKey: "hotkeyKeyCode")
            let oldMods = UserDefaults.standard.integer(forKey: "hotkeyModifiers")
            if oldMods != 0 && UserDefaults.standard.integer(forKey: slot.modifiersKey) == 0 {
                UserDefaults.standard.set(oldKeyCode, forKey: slot.keyCodeKey)
                UserDefaults.standard.set(oldMods, forKey: slot.modifiersKey)
                UserDefaults.standard.removeObject(forKey: "hotkeyKeyCode")
                UserDefaults.standard.removeObject(forKey: "hotkeyModifiers")
            }
        }

        let keyCode = UserDefaults.standard.integer(forKey: slot.keyCodeKey)
        let rawMods = UserDefaults.standard.integer(forKey: slot.modifiersKey)
        if rawMods != 0 {
            let combo = HotkeyCombo(keyCode: keyCode, modifiers: NSEvent.ModifierFlags(rawValue: UInt(rawMods)))
            switch slot {
            case .fullscreen: fullscreenHotkey = combo
            case .area: areaHotkey = combo
            case .window: windowHotkey = combo
            case .ocr: ocrHotkey = combo
            case .history: historyHotkey = combo
            }
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
        // Special keys that don't depend on keyboard layout
        let specialKeys: [Int: String] = [
            49: "Space", 50: "`",
            96: "F5", 97: "F6", 98: "F7", 99: "F3", 100: "F8",
            101: "F9", 109: "F10", 111: "F12", 103: "F11",
            118: "F4", 120: "F2", 122: "F1",
            36: "↩", 48: "⇥", 51: "⌫", 53: "⎋",
            123: "←", 124: "→", 125: "↓", 126: "↑",
        ]
        if let special = specialKeys[keyCode] { return special }

        // Use UCKeyTranslate to get the actual character for the current keyboard layout
        guard let inputSource = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue(),
              let layoutDataRef = TISGetInputSourceProperty(inputSource, kTISPropertyUnicodeKeyLayoutData) else {
            return "?"
        }
        let layoutData = unsafeBitCast(layoutDataRef, to: CFData.self) as Data
        var deadKeyState: UInt32 = 0
        var chars = [UniChar](repeating: 0, count: 4)
        var length: Int = 0

        layoutData.withUnsafeBytes { rawBuffer in
            guard let ptr = rawBuffer.baseAddress?.assumingMemoryBound(to: UCKeyboardLayout.self) else { return }
            UCKeyTranslate(
                ptr,
                UInt16(keyCode),
                UInt16(kUCKeyActionDisplay),
                0, // no modifiers for display
                UInt32(LMGetKbdType()),
                UInt32(kUCKeyTranslateNoDeadKeysBit),
                &deadKeyState,
                chars.count,
                &length,
                &chars
            )
        }

        if length > 0 {
            return String(utf16CodeUnits: chars, count: length).uppercased()
        }
        return "?"
    }

    /// Single character for NSMenuItem keyEquivalent (layout-aware)
    var keyCharacter: String {
        // Special keys
        let specialKeys: [Int: String] = [
            49: " ", 36: "\r", 48: "\t",
            96: "\u{F708}", 97: "\u{F709}", 98: "\u{F70A}", 99: "\u{F706}",
            100: "\u{F70B}", 101: "\u{F70C}", 109: "\u{F70D}", 111: "\u{F70F}",
            103: "\u{F70E}", 118: "\u{F707}", 120: "\u{F705}", 122: "\u{F704}",
        ]
        if let special = specialKeys[keyCode] { return special }

        guard let inputSource = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue(),
              let layoutDataRef = TISGetInputSourceProperty(inputSource, kTISPropertyUnicodeKeyLayoutData) else {
            return ""
        }
        let layoutData = unsafeBitCast(layoutDataRef, to: CFData.self) as Data
        var deadKeyState: UInt32 = 0
        var chars = [UniChar](repeating: 0, count: 4)
        var length: Int = 0

        layoutData.withUnsafeBytes { rawBuffer in
            guard let ptr = rawBuffer.baseAddress?.assumingMemoryBound(to: UCKeyboardLayout.self) else { return }
            UCKeyTranslate(
                ptr,
                UInt16(keyCode),
                UInt16(kUCKeyActionDisplay),
                0,
                UInt32(LMGetKbdType()),
                UInt32(kUCKeyTranslateNoDeadKeysBit),
                &deadKeyState,
                chars.count,
                &length,
                &chars
            )
        }

        if length > 0 {
            return String(utf16CodeUnits: chars, count: length).lowercased()
        }
        return ""
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
