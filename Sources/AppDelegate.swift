import AppKit
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private var statusMenuItem: NSMenuItem!
    private var toggleMenuItem: NSMenuItem!
    private var swapMenuItem: NSMenuItem!
    private var launchAtLoginMenuItem: NSMenuItem!
    private var accessibilityMenuItem: NSMenuItem!

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusBar()
        setupEventTap()
    }

    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            if #available(macOS 11.0, *) {
                let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .regular)
                if let image = NSImage(systemSymbolName: "computermouse.fill", accessibilityDescription: "MouseBack")?.withSymbolConfiguration(config) {
                    image.isTemplate = true
                    button.image = image
                } else {
                    button.title = "🖱️"
                }
            } else {
                button.title = "🖱️"
            }
            button.toolTip = "MouseBack - Navigasi Tombol Samping Mouse"
        }

        let menu = NSMenu()
        menu.delegate = self

        // 1. Status Label
        statusMenuItem = NSMenuItem(title: "Status: Memeriksa...", action: nil, keyEquivalent: "")
        statusMenuItem.isEnabled = false
        menu.addItem(statusMenuItem)

        menu.addItem(NSMenuItem.separator())

        // 2. Toggle Aktifkan
        toggleMenuItem = NSMenuItem(title: "Aktifkan MouseBack", action: #selector(toggleEnabled), keyEquivalent: "")
        toggleMenuItem.target = self
        menu.addItem(toggleMenuItem)

        // 3. Opsi Tukar Tombol
        swapMenuItem = NSMenuItem(title: "Tukar Tombol Samping (Swap Back / Forward)", action: #selector(toggleSwap), keyEquivalent: "")
        swapMenuItem.target = self
        menu.addItem(swapMenuItem)

        menu.addItem(NSMenuItem.separator())

        // 4. Launch at Login
        launchAtLoginMenuItem = NSMenuItem(title: "Buka Otomatis saat Login", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        launchAtLoginMenuItem.target = self
        menu.addItem(launchAtLoginMenuItem)

        // 5. Aksesibilitas
        accessibilityMenuItem = NSMenuItem(title: "Buka Pengaturan Aksesibilitas...", action: #selector(openAccessibilitySettings), keyEquivalent: "")
        accessibilityMenuItem.target = self
        menu.addItem(accessibilityMenuItem)

        menu.addItem(NSMenuItem.separator())

        // 6. Tentang & Keluar
        let aboutMenuItem = NSMenuItem(title: "Tentang MouseBack", action: #selector(showAbout), keyEquivalent: "")
        aboutMenuItem.target = self
        menu.addItem(aboutMenuItem)

        let quitMenuItem = NSMenuItem(title: "Keluar dari MouseBack", action: #selector(quitApp), keyEquivalent: "q")
        quitMenuItem.target = self
        menu.addItem(quitMenuItem)

        statusItem.menu = menu
        updateMenuStates()
    }

    private func setupEventTap() {
        EventTapManager.shared.onStatusChanged = { [weak self] _, _ in
            DispatchQueue.main.async {
                self?.updateMenuStates()
            }
        }
        EventTapManager.shared.start()

        if !EventTapManager.shared.hasPermission {
            // Tampilkan permintaan izin bawaan macOS jika pertama kali
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                EventTapManager.shared.requestPermission()
            }
        }
    }

    func menuWillOpen(_ menu: NSMenu) {
        updateMenuStates()
    }

    private func updateMenuStates() {
        let isEnabled = EventTapManager.shared.isEnabled
        let hasPermission = EventTapManager.shared.hasPermission
        let isSwapped = EventTapManager.shared.isSwapped

        if !hasPermission {
            statusMenuItem.title = "🟡 Butuh Izin Aksesibilitas"
            accessibilityMenuItem.isHidden = false
        } else if isEnabled {
            statusMenuItem.title = "🟢 MouseBack: Aktif"
            accessibilityMenuItem.isHidden = false
        } else {
            statusMenuItem.title = "⚪ MouseBack: Nonaktif"
            accessibilityMenuItem.isHidden = false
        }

        toggleMenuItem.state = isEnabled ? .on : .off
        swapMenuItem.state = isSwapped ? .on : .off

        // Launch at login state
        if #available(macOS 13.0, *) {
            launchAtLoginMenuItem.state = (SMAppService.mainApp.status == .enabled) ? .on : .off
            launchAtLoginMenuItem.isEnabled = true
        } else {
            launchAtLoginMenuItem.state = .off
            launchAtLoginMenuItem.isEnabled = false
        }
    }

    @objc private func toggleEnabled() {
        EventTapManager.shared.isEnabled.toggle()
        updateMenuStates()
    }

    @objc private func toggleSwap() {
        EventTapManager.shared.isSwapped.toggle()
        updateMenuStates()
    }

    @objc private func toggleLaunchAtLogin() {
        if #available(macOS 13.0, *) {
            do {
                if SMAppService.mainApp.status == .enabled {
                    try SMAppService.mainApp.unregister()
                } else {
                    try SMAppService.mainApp.register()
                }
            } catch {
                let alert = NSAlert()
                alert.messageText = "Gagal Mengubah Pengaturan Login"
                alert.informativeText = error.localizedDescription
                alert.runModal()
            }
        }
        updateMenuStates()
    }

    @objc private func openAccessibilitySettings() {
        EventTapManager.shared.openAccessibilitySettings()
    }

    @objc private func showAbout() {
        let alert = NSAlert()
        alert.messageText = "MouseBack"
        alert.informativeText = """
        Versi 1.0.0
        Aplikasi Menu Bar untuk mengaktifkan tombol samping (Back & Forward) pada mouse Bluetooth Ugreen dan mouse lainnya.

        Shortcut yang dikirim:
        • Tombol Belakang: Cmd + [ (Kembali)
        • Tombol Depan: Cmd + ] (Maju)
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}
