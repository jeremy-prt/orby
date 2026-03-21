import SwiftUI
import Sparkle

struct AboutTabView: View {
    private let en = L10n.lang == "en"
    private let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
    private let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            // App icon
            if let icon = NSImage(named: "AppIcon") {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 80, height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .shadow(color: .black.opacity(0.15), radius: 6, y: 2)
            } else {
                Image(systemName: "camera.viewfinder")
                    .font(.system(size: 50))
                    .foregroundStyle(brandPurple)
            }

            // App name + version
            VStack(spacing: 4) {
                Text("Orby")
                    .font(.system(size: 18, weight: .bold))
                Text("v\(version)")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            // Description
            Text(en
                ? "A lightweight screenshot tool for macOS."
                : "Un outil de capture d'écran léger pour macOS.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Divider().padding(.horizontal, 60)

            // Links + update
            VStack(spacing: 8) {
                Link(destination: URL(string: "https://jeremy-prt.github.io/orby/")!) {
                    Label(en ? "Website" : "Site web", systemImage: "globe")
                        .font(.system(size: 12))
                }
                .foregroundStyle(brandPurple)

                Link(destination: URL(string: "https://github.com/jeremy-prt/orby")!) {
                    Label("GitHub", systemImage: "chevron.left.forwardslash.chevron.right")
                        .font(.system(size: 12))
                }
                .foregroundStyle(brandPurple)

                // Check for updates button
            Button {
                SPUStandardUpdaterController(startingUpdater: false, updaterDelegate: nil, userDriverDelegate: nil).checkForUpdates(nil)
            } label: {
                Label(en ? "Check for Updates…" : "Vérifier les mises à jour…",
                      systemImage: "arrow.triangle.2.circlepath")
                    .font(.system(size: 12))
            }
            .buttonStyle(.plain)
            .foregroundStyle(brandPurple)
            }

            Spacer()

            // Copyright
            Text("© 2025 Jeremy Perret — MIT License")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
                .padding(.bottom, 12)
        }
        .frame(maxWidth: .infinity)
    }
}
