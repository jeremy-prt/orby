import SwiftUI

// MARK: - Fill mode

enum FillMode: String, CaseIterable {
    case outline, semiFilled, solidFilled
}

// MARK: - Floating Annotation Toolbar

struct AnnotationToolbar: View {
    let annotation: Annotation
    let onChangeColor: (Color) -> Void
    let onChangeLineWidth: (CGFloat) -> Void
    let onChangeFillMode: (FillMode) -> Void
    let onChangeFontSize: (CGFloat) -> Void
    let onChangeArrowStyle: (ArrowStyle) -> Void
    let onChangeTextBackground: (Bool) -> Void
    let onChangeBlurRadius: (CGFloat) -> Void
    let onChangeBlurStyle: (BlurStyle) -> Void
    let onDeselect: () -> Void
    let onDelete: () -> Void

    @State private var showColorPicker = false

    private let presetColors: [Color] = [.red, .orange, .yellow, .green, .blue, .purple, .white, .black]

    var body: some View {
        HStack(spacing: 6) {
            // Back / deselect
            Button { onDeselect() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 11, weight: .semibold))
                    .frame(width: 22, height: 22)
            }.buttonStyle(.plain)

            Divider().frame(height: 18)

            // Single color circle — tap to show color picker (hidden for blur)
            if annotation.shape != .blur {
                Button { showColorPicker.toggle() } label: {
                    Circle()
                        .fill(annotation.color)
                        .overlay(Circle().stroke(Color.gray.opacity(0.3), lineWidth: 0.5))
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showColorPicker, arrowEdge: .bottom) {
                    colorPickerContent
                }

                Divider().frame(height: 18)
            }

            // Thickness or font size (not for blur — blur has its own radius slider)
            if annotation.shape == .text {
                ThicknessSlider(
                    value: annotation.fontSize,
                    range: 12...60,
                    onChange: onChangeFontSize
                )
                Text("\(Int(annotation.fontSize))px")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary).frame(width: 30)
            } else if annotation.shape != .blur {
                thicknessControl
            }

            // Fill modes (only for rect/circle)
            if annotation.shape == .rect || annotation.shape == .circle {
                Divider().frame(height: 18)
                HStack(spacing: 2) {
                    fillButton(icon: "square", mode: .outline,
                               active: !annotation.filled)
                    fillButton(icon: "square.inset.filled", mode: .semiFilled,
                               active: annotation.filled && !annotation.solidFill)
                    fillButton(icon: "square.fill", mode: .solidFilled,
                               active: annotation.filled && annotation.solidFill)
                }
            }

            // Text background mode (only for text)
            if annotation.shape == .text {
                Divider().frame(height: 18)
                HStack(spacing: 2) {
                    // With background
                    Button { onChangeTextBackground(true) } label: {
                        ZStack {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color.primary.opacity(0.7))
                                .frame(width: 16, height: 14)
                            Text("T")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(Color(nsColor: .windowBackgroundColor))
                        }
                        .frame(width: 24, height: 22)
                        .background(RoundedRectangle(cornerRadius: 4)
                            .fill(annotation.textHasBackground ? brandPurple.opacity(0.2) : Color.clear))
                    }.buttonStyle(.plain)

                    // Plain text
                    Button { onChangeTextBackground(false) } label: {
                        Text("T")
                            .font(.system(size: 13, weight: .bold))
                            .frame(width: 24, height: 22)
                            .background(RoundedRectangle(cornerRadius: 4)
                                .fill(!annotation.textHasBackground ? brandPurple.opacity(0.2) : Color.clear))
                    }.buttonStyle(.plain)
                }
            }

            // Arrow style (only for arrow)
            if annotation.shape == .arrow {
                Divider().frame(height: 18)
                HStack(spacing: 2) {
                    arrowStyleButton(icon: "arrow.right", style: .outline,
                                     active: annotation.arrowStyle == .outline, weight: .ultraLight)
                    arrowStyleButton(icon: "arrow.right", style: .thin,
                                     active: annotation.arrowStyle == .thin, weight: .regular)
                    arrowStyleButton(icon: "arrowshape.right.fill", style: .filled,
                                     active: annotation.arrowStyle == .filled, weight: .regular)
                    arrowStyleButton(icon: "arrow.left.and.right", style: .double,
                                     active: annotation.arrowStyle == .double, weight: .regular)
                }
            }

            // Blur controls (only for blur)
            if annotation.shape == .blur {
                Divider().frame(height: 18)
                ThicknessSlider(
                    value: annotation.blurRadius,
                    range: 5...30,
                    onChange: onChangeBlurRadius
                )
                Text("\(Int(annotation.blurRadius))")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary).frame(width: 20)

                Divider().frame(height: 18)
                HStack(spacing: 2) {
                    blurStyleButton(icon: "aqi.medium", style: .gaussian,
                                    active: annotation.blurStyle == .gaussian)
                    blurStyleButton(icon: "square.grid.3x3", style: .pixelate,
                                    active: annotation.blurStyle == .pixelate)
                }
            }
        }
        .padding(.horizontal, 8).padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(nsColor: .windowBackgroundColor))
                .shadow(color: .black.opacity(0.15), radius: 6, y: 2)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.2), lineWidth: 0.5))
        )
    }

    // MARK: - Color picker popover

    private var colorPickerContent: some View {
        VStack(spacing: 8) {
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(24), spacing: 6), count: 4), spacing: 6) {
                ForEach(presetColors, id: \.self) { c in
                    Circle()
                        .fill(c)
                        .overlay(Circle().stroke(Color.gray.opacity(0.3), lineWidth: 0.5))
                        .overlay(
                            annotation.color == c
                                ? Circle().stroke(brandPurple, lineWidth: 2.5).padding(-2)
                                : nil
                        )
                        .frame(width: 24, height: 24)
                        .onTapGesture {
                            onChangeColor(c)
                            showColorPicker = false
                        }
                }
            }
            Divider()
            ColorPicker("Custom", selection: Binding(
                get: { annotation.color },
                set: { onChangeColor($0) }
            ))
            .labelsHidden()
            .frame(height: 24)
        }
        .padding(10)
        .frame(width: 130)
    }

    // MARK: - Thickness control

    private var thicknessControl: some View {
        ThicknessSlider(
            value: annotation.lineWidth,
            range: 1...20,
            onChange: onChangeLineWidth
        )
    }

    private func fillButton(icon: String, mode: FillMode, active: Bool) -> some View {
        Button { onChangeFillMode(mode) } label: {
            Image(systemName: icon)
                .font(.system(size: 13))
                .frame(width: 24, height: 22)
                .background(RoundedRectangle(cornerRadius: 4)
                    .fill(active ? brandPurple.opacity(0.2) : Color.clear))
        }.buttonStyle(.plain)
    }

    private func arrowStyleButton(icon: String, style: ArrowStyle, active: Bool, weight: Font.Weight) -> some View {
        Button { onChangeArrowStyle(style) } label: {
            Image(systemName: icon)
                .font(.system(size: 13, weight: weight))
                .frame(width: 24, height: 22)
                .background(RoundedRectangle(cornerRadius: 4)
                    .fill(active ? brandPurple.opacity(0.2) : Color.clear))
        }.buttonStyle(.plain)
    }

    private func blurStyleButton(icon: String, style: BlurStyle, active: Bool) -> some View {
        Button { onChangeBlurStyle(style) } label: {
            Image(systemName: icon)
                .font(.system(size: 13))
                .frame(width: 24, height: 22)
                .background(RoundedRectangle(cornerRadius: 4)
                    .fill(active ? brandPurple.opacity(0.2) : Color.clear))
        }.buttonStyle(.plain)
    }
}

// MARK: - Custom Thickness Slider (triangle shape)

struct ThicknessSlider: View {
    let value: CGFloat
    let range: ClosedRange<CGFloat>
    let onChange: (CGFloat) -> Void

    private let sliderWidth: CGFloat = 90
    private let sliderHeight: CGFloat = 18
    private let handleSize: CGFloat = 14

    private var normalizedValue: CGFloat {
        (value - range.lowerBound) / (range.upperBound - range.lowerBound)
    }

    var body: some View {
        ZStack(alignment: .leading) {
            // Triangle track
            Canvas { ctx, size in
                let minH: CGFloat = 1.5
                let maxH: CGFloat = size.height - 4
                var path = Path()
                path.move(to: CGPoint(x: 0, y: size.height / 2 - minH / 2))
                path.addLine(to: CGPoint(x: size.width, y: size.height / 2 - maxH / 2))
                path.addLine(to: CGPoint(x: size.width, y: size.height / 2 + maxH / 2))
                path.addLine(to: CGPoint(x: 0, y: size.height / 2 + minH / 2))
                path.closeSubpath()
                ctx.fill(path, with: .color(Color.gray.opacity(0.3)))

                // Filled portion
                let fillX = normalizedValue * size.width
                var fillPath = Path()
                let fillH = minH + (maxH - minH) * normalizedValue
                fillPath.move(to: CGPoint(x: 0, y: size.height / 2 - minH / 2))
                fillPath.addLine(to: CGPoint(x: fillX, y: size.height / 2 - fillH / 2))
                fillPath.addLine(to: CGPoint(x: fillX, y: size.height / 2 + fillH / 2))
                fillPath.addLine(to: CGPoint(x: 0, y: size.height / 2 + minH / 2))
                fillPath.closeSubpath()
                ctx.fill(fillPath, with: .color(Color.primary.opacity(0.5)))
            }
            .frame(width: sliderWidth, height: sliderHeight)

            // Handle
            Circle()
                .fill(Color.white)
                .shadow(color: .black.opacity(0.2), radius: 2, y: 1)
                .frame(width: handleSize, height: handleSize)
                .offset(x: normalizedValue * (sliderWidth - handleSize))
        }
        .frame(width: sliderWidth, height: sliderHeight)
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { drag in
                    let x = max(0, min(drag.location.x, sliderWidth))
                    let newValue = range.lowerBound + (x / sliderWidth) * (range.upperBound - range.lowerBound)
                    onChange(round(newValue))
                }
        )
    }
}
