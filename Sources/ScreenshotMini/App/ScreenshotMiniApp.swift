import SwiftUI

@main
struct ScreenshotMiniApp: App {
    @NSApplicationDelegateAdaptor private var appDelegate: AppDelegate

    var body: some Scene {
        MenuBarExtra("", isInserted: .constant(false)) {
            EmptyView()
        }
    }
}

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    private var statusItem: NSStatusItem!
    private var settingsWindow: NSWindow?
    let screenshotService = ScreenCaptureService()

    private var menuBarObserver: NSObjectProtocol?

    func applicationDidFinishLaunching(_ notification: Notification) {
        UserDefaults.standard.register(defaults: ["dismissDelay": 5.0, "playSound": true, "showMenuBarIcon": true, "appTheme": "system", "exportRetina": true])
        applyTheme(UserDefaults.standard.string(forKey: "appTheme") ?? "system")
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            if let iconPath = Bundle.main.path(forResource: "menubar-icon", ofType: "png"),
               let icon = NSImage(contentsOfFile: iconPath) {
                icon.isTemplate = true
                icon.size = NSSize(width: 18, height: 18)
                button.image = icon
            } else {
                button.image = NSImage(systemSymbolName: "camera.viewfinder", accessibilityDescription: "Screenshot")
            }
            button.target = self
            button.action = #selector(statusItemClicked(_:))
            button.sendAction(on: [.leftMouseUp])
        }

        let mgr = HotkeyManager.shared
        mgr.onFullscreen = { [weak self] in
            self?.takeFullscreen()
        }
        mgr.onArea = { [weak self] in
            self?.takeArea()
        }
        mgr.onWindow = { [weak self] in
            self?.takeWindow()
        }
        mgr.onOCR = { [weak self] in
            self?.takeOCR()
        }
        mgr.onHistory = {
            HistoryWindow.shared.toggle()
        }
        mgr.registerHotkey(.fullscreen)
        mgr.registerHotkey(.area)
        mgr.registerHotkey(.window)
        mgr.registerHotkey(.ocr)
        mgr.registerHotkey(.history)

        // If menu bar icon is hidden, open settings on launch so user isn't locked out
        if !UserDefaults.standard.bool(forKey: "showMenuBarIcon") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.openSettings()
            }
        }

        // Watch for menu bar icon visibility changes
        menuBarObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.updateMenuBarVisibility()
            }
        }
        updateMenuBarVisibility()
    }

    private func updateMenuBarVisibility() {
        let show = UserDefaults.standard.bool(forKey: "showMenuBarIcon")
        statusItem.isVisible = show
    }

    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        showMenu()
    }

    private func takeFullscreen() {
        Task { await screenshotService.captureFullScreen() }
    }

    private func takeArea() {
        Task { await screenshotService.captureArea() }
    }

    private func takeWindow() {
        Task { await screenshotService.captureWindow() }
    }

    private func takeOCR() {
        Task { await screenshotService.captureOCR() }
    }

    private func showMenu() {
        let menu = NSMenu()
        let mgr = HotkeyManager.shared

        let fullscreenItem = NSMenuItem(title: L10n.menuCapture, action: #selector(captureFullscreenAction), keyEquivalent: "")
        fullscreenItem.target = self
        if let combo = mgr.fullscreenHotkey { applyKeyEquivalent(combo, to: fullscreenItem) }
        menu.addItem(fullscreenItem)

        let areaItem = NSMenuItem(title: L10n.lang == "en" ? "Capture area" : "Capturer une zone", action: #selector(captureAreaAction), keyEquivalent: "")
        areaItem.target = self
        if let combo = mgr.areaHotkey { applyKeyEquivalent(combo, to: areaItem) }
        menu.addItem(areaItem)

        let windowItem = NSMenuItem(title: L10n.lang == "en" ? "Capture window" : "Capturer une fenêtre", action: #selector(captureWindowAction), keyEquivalent: "")
        windowItem.target = self
        if let combo = mgr.windowHotkey { applyKeyEquivalent(combo, to: windowItem) }
        menu.addItem(windowItem)

        let ocrItem = NSMenuItem(title: L10n.lang == "en" ? "OCR (text capture)" : "OCR (capture texte)", action: #selector(captureOCRAction), keyEquivalent: "")
        ocrItem.target = self
        if let combo = mgr.ocrHotkey { applyKeyEquivalent(combo, to: ocrItem) }
        menu.addItem(ocrItem)

        menu.addItem(NSMenuItem.separator())

        let historyItem = NSMenuItem(title: L10n.lang == "en" ? "Capture history" : "Historique des captures", action: #selector(openHistoryAction), keyEquivalent: "")
        historyItem.target = self
        historyItem.image = NSImage(systemSymbolName: "clock.arrow.circlepath", accessibilityDescription: nil)
        if let combo = mgr.combo(for: .history) { applyKeyEquivalent(combo, to: historyItem) }
        menu.addItem(historyItem)

        let settingsItem = NSMenuItem(title: L10n.menuSettings, action: #selector(openSettings), keyEquivalent: "")
        settingsItem.target = self
        settingsItem.image = NSImage(systemSymbolName: "gearshape", accessibilityDescription: nil)
        menu.addItem(settingsItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: L10n.menuQuit, action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    private func applyKeyEquivalent(_ combo: HotkeyCombo, to item: NSMenuItem) {
        let char = combo.keyCharacter
        guard !char.isEmpty else { return }
        item.keyEquivalent = char
        var mods: NSEvent.ModifierFlags = []
        if combo.modifiers.contains(.command) { mods.insert(.command) }
        if combo.modifiers.contains(.option) { mods.insert(.option) }
        if combo.modifiers.contains(.control) { mods.insert(.control) }
        if combo.modifiers.contains(.shift) { mods.insert(.shift) }
        item.keyEquivalentModifierMask = mods
    }

    @objc private func captureFullscreenAction() { takeFullscreen() }
    @objc private func captureAreaAction() { takeArea() }
    @objc private func captureWindowAction() { takeWindow() }
    @objc private func captureOCRAction() { takeOCR() }
    @objc private func openHistoryAction() { HistoryWindow.shared.toggle() }

    @objc func openSettings() {
        if let window = settingsWindow, window.isVisible {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let settingsView = SettingsView()
        let hostingView = NSHostingView(rootView: settingsView)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 440, height: 620),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = L10n.menuSettings
        window.titleVisibility = .hidden
        window.contentView = hostingView
        window.center()
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        settingsWindow = window
    }

    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}
