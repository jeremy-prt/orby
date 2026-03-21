import SwiftUI

// MARK: - Crop Toolbar

struct CropToolbar: View {
    let onApply: () -> Void
    let onCancel: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Button { onCancel() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.red)
                    .frame(width: 28, height: 28)
                    .background(RoundedRectangle(cornerRadius: 6).fill(.red.opacity(0.15)))
            }.buttonStyle(.plain)

            Button { onApply() } label: {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark").font(.system(size: 12, weight: .bold))
                    Text("Apply").font(.system(size: 12, weight: .semibold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(RoundedRectangle(cornerRadius: 6).fill(brandPurple))
            }.buttonStyle(.plain)
        }
        .padding(.horizontal, 8).padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(nsColor: .windowBackgroundColor))
                .shadow(color: .black.opacity(0.15), radius: 6, y: 2)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.2), lineWidth: 0.5))
        )
    }
}

// MARK: - Crop Mask

struct CropMask: Shape {
    let rect: CGRect; let size: CGSize
    func path(in frame: CGRect) -> Path {
        var p = Path(); p.addRect(CGRect(origin: .zero, size: size)); p.addRect(rect); return p
    }
    var body: some View { self.fill(style: FillStyle(eoFill: true)) }
}
