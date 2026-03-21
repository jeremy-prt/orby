import SwiftUI
import AppKit

let brandPurple = Color(red: 0x9F / 255.0, green: 0x01 / 255.0, blue: 0xA0 / 255.0)

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
