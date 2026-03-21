import SwiftUI

struct BackgroundPanel: View {
    @Binding var config: BackgroundConfig
    let onClose: () -> Void

    private let en = L10n.lang == "en"
    @State private var bgTab: Int = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Text(en ? "Background" : "Arrière-plan")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Toggle("", isOn: $config.enabled)
                    .toggleStyle(.switch)
                    .controlSize(.mini)
                    .tint(brandPurple)
            }

            Divider()

            // Options (visible but greyed out when off)
            VStack(alignment: .leading, spacing: 12) {
                tabSelector
                backgroundGrid
                Divider()
                sliders
                Divider()
                shadowToggle
            }
            .opacity(config.enabled ? 1 : 0.4)
            .allowsHitTesting(config.enabled)
        }
        .padding(14)
        .frame(width: 250)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(nsColor: .windowBackgroundColor))
                .shadow(color: .black.opacity(0.15), radius: 8, y: 2)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray.opacity(0.2), lineWidth: 0.5))
        )
    }

    // MARK: - Tab selector

    private var tabSelector: some View {
        HStack(spacing: 0) {
            tabButton(en ? "Gradient" : "Dégradé", tab: 0)
            tabButton(en ? "Solid" : "Uni", tab: 1)
        }
        .background(RoundedRectangle(cornerRadius: 6).fill(Color.gray.opacity(0.1)))
    }

    private func tabButton(_ label: String, tab: Int) -> some View {
        Text(label)
            .font(.system(size: 10, weight: bgTab == tab ? .semibold : .regular))
            .foregroundStyle(bgTab == tab ? .white : .primary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 5)
            .contentShape(Rectangle())
            .background(RoundedRectangle(cornerRadius: 5).fill(bgTab == tab ? brandPurple : Color.clear))
            .onTapGesture { bgTab = tab }
    }

    // MARK: - Background grid

    @ViewBuilder
    private var backgroundGrid: some View {
        if bgTab == 0 {
            gradientGrid
        } else {
            solidGrid
        }
    }

    private var gradientGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.fixed(34), spacing: 5), count: 6), spacing: 5) {
            ForEach(gradientPresets) { preset in
                let isSelected: Bool = {
                    if case .gradient(let idx) = config.type { return idx == preset.id }
                    return false
                }()
                RoundedRectangle(cornerRadius: 8)
                    .fill(LinearGradient(colors: preset.colors,
                                         startPoint: preset.startPoint, endPoint: preset.endPoint))
                    .frame(width: 34, height: 34)
                    .overlay(RoundedRectangle(cornerRadius: 8)
                        .stroke(isSelected ? brandPurple : Color.clear, lineWidth: 2.5))
                    .onTapGesture {
                        config.type = .gradient(preset.id)
                        config.enabled = true
                    }
            }
        }
    }

    private var solidGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.fixed(34), spacing: 5), count: 6), spacing: 5) {
            ForEach(Array(solidColorPresets.enumerated()), id: \.offset) { _, color in
                let isSelected: Bool = {
                    if case .solid(let c) = config.type { return c == color }
                    return false
                }()
                Circle()
                    .fill(color)
                    .frame(width: 30, height: 30)
                    .overlay(Circle().stroke(Color.gray.opacity(0.2), lineWidth: 0.5))
                    .overlay(Circle().stroke(isSelected ? brandPurple : Color.clear, lineWidth: 2.5))
                    .onTapGesture {
                        config.type = .solid(color)
                        config.enabled = true
                    }
            }
            // Custom color picker (circle)
            ZStack {
                Circle()
                    .fill(AngularGradient(colors: [.red, .yellow, .green, .cyan, .blue, .purple, .red],
                                          center: .center))
                    .frame(width: 30, height: 30)
                ColorPicker("", selection: Binding(
                    get: {
                        if case .solid(let c) = config.type { return c }
                        return .blue
                    },
                    set: { config.type = .solid($0); config.enabled = true }
                ))
                .labelsHidden()
                .opacity(0.015)  // nearly invisible but clickable
            }
            .frame(width: 30, height: 30)
        }
    }

    // MARK: - Sliders

    private var sliders: some View {
        VStack(spacing: 10) {
            sliderRow(label: en ? "Spacing" : "Espacement", value: $config.padding,
                      range: 0...50, display: "\(Int(config.padding))%")
            sliderRow(label: en ? "Rounded corners" : "Coins arrondis", value: $config.cornerRadius,
                      range: 0...100, display: "\(Int(config.cornerRadius))%")
        }
    }

    private func sliderRow(label: String, value: Binding<CGFloat>, range: ClosedRange<CGFloat>, display: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(label).font(.system(size: 11)).foregroundStyle(.secondary)
                Spacer()
                Text(display).font(.system(size: 10, design: .monospaced)).foregroundStyle(.tertiary)
            }
            Slider(value: value, in: range)
                .controlSize(.mini)
                .tint(brandPurple)
        }
    }

    // MARK: - Shadow

    private var shadowToggle: some View {
        HStack {
            Text(en ? "Shadow" : "Ombre")
                .font(.system(size: 11)).foregroundStyle(.secondary)
            Spacer()
            Toggle("", isOn: $config.shadowEnabled)
                .toggleStyle(.switch).controlSize(.mini).tint(brandPurple)
        }
    }
}
