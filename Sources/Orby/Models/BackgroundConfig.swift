import SwiftUI

// MARK: - Background type

enum BackgroundType: Equatable {
    case gradient(Int)
    case solid(Color)
}

// MARK: - Background configuration

struct BackgroundConfig: Equatable {
    var enabled: Bool = false
    var type: BackgroundType = .gradient(0)
    var padding: CGFloat = 15       // percentage of image width (0-50%)
    var cornerRadius: CGFloat = 5   // percentage (0-100%, 100% = half of shorter side)
    var shadowEnabled: Bool = true
    var shadowRadius: CGFloat = 20
    var shadowOpacity: Double = 0.3
}

// MARK: - Gradient presets

struct GradientPreset: Identifiable {
    let id: Int
    let colors: [Color]
    let startPoint: UnitPoint
    let endPoint: UnitPoint
}

let gradientPresets: [GradientPreset] = [
    // Purples & blues
    GradientPreset(id: 0,  colors: [Color(h: 0x667eea), Color(h: 0x764ba2)], startPoint: .topLeading, endPoint: .bottomTrailing),
    GradientPreset(id: 1,  colors: [Color(h: 0xa18cd1), Color(h: 0xfbc2eb)], startPoint: .top, endPoint: .bottom),
    GradientPreset(id: 2,  colors: [Color(h: 0xe0c3fc), Color(h: 0x8ec5fc)], startPoint: .top, endPoint: .bottom),
    // Warm
    GradientPreset(id: 3,  colors: [Color(h: 0xf093fb), Color(h: 0xf5576c)], startPoint: .topLeading, endPoint: .bottomTrailing),
    GradientPreset(id: 4,  colors: [Color(h: 0xfa709a), Color(h: 0xfee140)], startPoint: .topLeading, endPoint: .bottomTrailing),
    GradientPreset(id: 5,  colors: [Color(h: 0xff9a9e), Color(h: 0xfecfef)], startPoint: .top, endPoint: .bottom),
    // Cool
    GradientPreset(id: 6,  colors: [Color(h: 0x4facfe), Color(h: 0x00f2fe)], startPoint: .top, endPoint: .bottom),
    GradientPreset(id: 7,  colors: [Color(h: 0x43e97b), Color(h: 0x38f9d7)], startPoint: .topLeading, endPoint: .bottomTrailing),
    GradientPreset(id: 8,  colors: [Color(h: 0xfccb90), Color(h: 0xd57eeb)], startPoint: .topLeading, endPoint: .bottomTrailing),
    // Dark
    GradientPreset(id: 9,  colors: [Color(h: 0x1a1a2e), Color(h: 0x16213e), Color(h: 0x0f3460)], startPoint: .topLeading, endPoint: .bottomTrailing),
    GradientPreset(id: 10, colors: [Color(h: 0x0c0c0c), Color(h: 0x1a1a2e)], startPoint: .top, endPoint: .bottom),
    GradientPreset(id: 11, colors: [Color(h: 0x232526), Color(h: 0x414345)], startPoint: .top, endPoint: .bottom),
    // Light
    GradientPreset(id: 12, colors: [Color(h: 0xf5f7fa), Color(h: 0xc3cfe2)], startPoint: .top, endPoint: .bottom),
    GradientPreset(id: 13, colors: [Color(h: 0xfdfcfb), Color(h: 0xe2d1c3)], startPoint: .top, endPoint: .bottom),
    // Extra
    GradientPreset(id: 14, colors: [Color(h: 0x6a11cb), Color(h: 0x2575fc)], startPoint: .topLeading, endPoint: .bottomTrailing),
    GradientPreset(id: 15, colors: [Color(h: 0xf7971e), Color(h: 0xffd200)], startPoint: .topLeading, endPoint: .bottomTrailing),
    GradientPreset(id: 16, colors: [Color(h: 0x00c6ff), Color(h: 0x0072ff)], startPoint: .top, endPoint: .bottom),
    GradientPreset(id: 17, colors: [Color(h: 0x11998e), Color(h: 0x38ef7d)], startPoint: .topLeading, endPoint: .bottomTrailing),
]

// MARK: - Solid color presets (vibrant)

let solidColorPresets: [Color] = [
    .white, .black,
    Color(h: 0xe74c3c), Color(h: 0xe91e63), Color(h: 0x9b59b6),
    Color(h: 0x3498db), Color(h: 0x00bcd4), Color(h: 0x2ecc71),
    Color(h: 0xf39c12), Color(h: 0xff6b35), Color(h: 0x1abc9c),
    Color(h: 0x34495e),
]

// MARK: - Color from hex int

extension Color {
    init(h hex: Int) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0
        )
    }
}
