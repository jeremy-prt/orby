import SwiftUI

struct SettingsView: View {
    @State private var selectedTab: SettingsTab = .general
    @AppStorage("appLanguage") private var appLanguage = "fr"

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                ForEach(SettingsTab.allCases, id: \.self) { tab in
                    Button {
                        selectedTab = tab
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: tab.icon)
                                .font(.system(size: 20))
                            Text(tab.label)
                                .font(.caption2)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .foregroundStyle(selectedTab == tab ? brandPurple : Color.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 4)

            Divider()
                .padding(.top, 4)

            Group {
                switch selectedTab {
                case .general:
                    GeneralTabView()
                case .raccourcis:
                    ShortcutsTabView()
                case .capture:
                    CaptureTabView()
                case .sauvegarde:
                    SaveTabView()
                case .about:
                    AboutTabView()
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .id(appLanguage) // force refresh when language changes
        }
        .frame(width: 440)
        .frame(minHeight: 550)
        .tint(brandPurple)
        .onAppear {
            DispatchQueue.main.async {
                NSApp.activate(ignoringOtherApps: true)
                if let window = NSApp.windows.last(where: { $0.isVisible && $0.canBecomeKey }) {
                    window.makeKeyAndOrderFront(nil)
                    window.orderFrontRegardless()
                }
            }
        }
    }
}
