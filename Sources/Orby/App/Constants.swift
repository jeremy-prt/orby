import SwiftUI
import AppKit

// MARK: - Brand colors

let brandPurple = Color(red: 0x9F / 255.0, green: 0x01 / 255.0, blue: 0xA0 / 255.0)
let brandPurpleNS = NSColor(red: 0x9F / 255.0, green: 0x01 / 255.0, blue: 0xA0 / 255.0, alpha: 1)

// MARK: - Theme

func applyTheme(_ theme: String) {
    switch theme {
    case "light": NSApp.appearance = NSAppearance(named: .aqua)
    case "dark": NSApp.appearance = NSAppearance(named: .darkAqua)
    default: NSApp.appearance = nil // system
    }
}

// MARK: - Color hex conversion

extension Color {
    func toHex() -> String? {
        guard let c = NSColor(self).usingColorSpace(.deviceRGB) else { return nil }
        return String(format: "#%02X%02X%02X",
                      Int(c.redComponent * 255),
                      Int(c.greenComponent * 255),
                      Int(c.blueComponent * 255))
    }

    static func fromHex(_ hex: String) -> Color? {
        var h = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if h.hasPrefix("#") { h.removeFirst() }
        guard h.count == 6, let val = UInt64(h, radix: 16) else { return nil }
        return Color(
            red: Double((val >> 16) & 0xFF) / 255,
            green: Double((val >> 8) & 0xFF) / 255,
            blue: Double(val & 0xFF) / 255
        )
    }
}
