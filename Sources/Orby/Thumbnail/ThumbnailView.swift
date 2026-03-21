import SwiftUI

// MARK: - Thumbnail View

struct ThumbnailView: View {
    let image: NSImage
    let onCopy: () -> Void
    let onSave: () -> Void
    let onEdit: () -> Void
    let onDismiss: () -> Void
    let onPin: (Bool) -> Void
    let onHover: (Bool) -> Void

    @State private var isHovered = false
    @State private var isPinned = false
    @State private var showCopied = false
    @State private var hoveredButton: String?
    @State private var visibleTooltip: String?
    @State private var tooltipTimer: Timer?

    private var showOverlay: Bool { isHovered || isPinned }

    var body: some View {
        ZStack {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: thumbWidth, height: thumbHeight)
                .clipped()
                .blur(radius: showOverlay ? 10 : 0)
                .brightness(showOverlay ? -0.08 : 0)
                .scaleEffect(showOverlay ? 1.03 : 1.0)

            if showOverlay {
                RoundedRectangle(cornerRadius: 10)
                    .fill(.ultraThinMaterial.opacity(0.4))
                    .frame(width: thumbWidth, height: thumbHeight)
                    .transition(.opacity)

                // Central Edit button
                pillButton(label: "Edit", buttonId: "edit", action: onEdit)
                    .transition(.opacity.combined(with: .scale(scale: 0.92)))

                // Corner buttons
                VStack {
                    HStack {
                        cornerButton(icon: "xmark", buttonId: "close", action: onDismiss)
                        Spacer()
                        cornerButton(
                            icon: "pin.fill",
                            buttonId: "pin",
                            highlighted: isPinned,
                            rotation: 45
                        ) {
                            isPinned.toggle()
                            onPin(isPinned)
                        }
                    }
                    Spacer()
                    HStack {
                        cornerButton(
                            icon: showCopied ? "checkmark" : "doc.on.doc.fill",
                            buttonId: "copy",
                            action: {
                                onCopy()
                                withAnimation(.easeInOut(duration: 0.2)) { showCopied = true }
                            }
                        )
                        Spacer()
                        cornerButton(icon: "square.and.arrow.down.fill", buttonId: "save", action: onSave)
                    }
                }
                .padding(6)
                .frame(width: thumbWidth, height: thumbHeight)
                .transition(.opacity)

                // Drag handle — when pinned, centered between pin and close buttons
                if isPinned {
                    VStack {
                        HStack {
                            Spacer()
                            WindowDragHandleView()
                                .frame(width: thumbWidth - 70, height: 28)
                                .overlay(
                                    HStack(spacing: 2) {
                                        ForEach(0..<3, id: \.self) { _ in
                                            Circle()
                                                .fill(.white.opacity(0.6))
                                                .frame(width: 4, height: 4)
                                        }
                                    }
                                )
                            Spacer()
                        }
                        Spacer()
                    }
                    .frame(width: thumbWidth, height: thumbHeight)
                    .transition(.opacity)
                }

                // Tooltip
                if let tip = visibleTooltip {
                    VStack {
                        Spacer()
                        Text(tip)
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(.black.opacity(0.7)))
                            .padding(.bottom, 4)
                    }
                    .frame(width: thumbWidth, height: thumbHeight)
                    .allowsHitTesting(false)
                    .transition(.opacity)
                }
            }
        }
        .frame(width: thumbWidth, height: thumbHeight)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .shadow(color: .black.opacity(0.25), radius: 6, x: 0, y: 2)
        .padding(thumbPadding)
        .animation(.easeInOut(duration: 0.3), value: isHovered)
        .animation(.easeInOut(duration: 0.3), value: isPinned)
        .animation(.easeInOut(duration: 0.15), value: visibleTooltip)
        .onHover { hovering in
            isHovered = hovering
            onHover(hovering)
            if !hovering {
                hoveredButton = nil
                tooltipTimer?.invalidate()
                tooltipTimer = nil
                visibleTooltip = nil
            }
        }
        .onChange(of: hoveredButton) { _, newValue in
            tooltipTimer?.invalidate()
            tooltipTimer = nil
            visibleTooltip = nil

            if let buttonId = newValue {
                tooltipTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { _ in
                    MainActor.assumeIsolated {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            visibleTooltip = tooltipText(for: buttonId)
                        }
                    }
                }
            }
        }
    }

    private func tooltipText(for buttonId: String) -> String? {
        switch buttonId {
        case "copy": L10n.tooltipCopy
        case "save": L10n.tooltipSave
        case "edit": L10n.tooltipEdit
        case "pin": isPinned ? L10n.tooltipUnpin : L10n.tooltipPin
        case "close": L10n.tooltipClose
        default: nil
        }
    }

    private func pillButton(label: String, buttonId: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.black.opacity(0.8))
                .frame(width: 80, height: 26)
                .background(Capsule().fill(.white.opacity(0.85)))
        }
        .buttonStyle(.plain)
        .onHover { h in hoveredButton = h ? buttonId : nil }
    }

    private func cornerButton(icon: String, buttonId: String, highlighted: Bool = false, rotation: Double = 0, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .bold))
                .rotationEffect(.degrees(rotation))
                .foregroundStyle(highlighted ? .yellow : .black.opacity(0.7))
                .frame(width: 24, height: 24)
                .background(Circle().fill(.white.opacity(0.85)))
        }
        .buttonStyle(.plain)
        .onHover { h in hoveredButton = h ? buttonId : nil }
    }
}
