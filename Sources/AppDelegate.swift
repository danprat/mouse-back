import AppKit
import ServiceManagement
import UserNotifications

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private var statusMenuItem: NSMenuItem!
    private var toggleMenuItem: NSMenuItem!
    private var swapMenuItem: NSMenuItem!
    private var notificationMenuItem: NSMenuItem!
    private var launchAtLoginMenuItem: NSMenuItem!
    private var accessibilityMenuItem: NSMenuItem!
    private var globalMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        logDebug("=== APLIKASI MOUSEBACK DIMULAI ===")
        setupStatusBar()
        setupEventTap()
        setupGlobalMonitor()
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

        // 4. Opsi Notifikasi Pengujian
        notificationMenuItem = NSMenuItem(title: "Tampilkan Notifikasi Pop-up saat Tombol Ditekan", action: #selector(toggleNotifications), keyEquivalent: "")
        notificationMenuItem.target = self
        menu.addItem(notificationMenuItem)

        menu.addItem(NSMenuItem.separator())

        // 5. Launch at Login
        launchAtLoginMenuItem = NSMenuItem(title: "Buka Otomatis saat Login", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        launchAtLoginMenuItem.target = self
        menu.addItem(launchAtLoginMenuItem)

        // 6. Aksesibilitas
        accessibilityMenuItem = NSMenuItem(title: "Buka Pengaturan Aksesibilitas...", action: #selector(openAccessibilitySettings), keyEquivalent: "")
        accessibilityMenuItem.target = self
        menu.addItem(accessibilityMenuItem)

        // 7. Buka File Log
        let logMenuItem = NSMenuItem(title: "Buka File Log (/tmp/mouseback.log)...", action: #selector(openLogFile), keyEquivalent: "")
        logMenuItem.target = self
        menu.addItem(logMenuItem)

        menu.addItem(NSMenuItem.separator())

        // 8. Tentang & Keluar
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

        EventTapManager.shared.onButtonTriggered = { [weak self] action in
            guard EventTapManager.shared.showNotifications else { return }
            DispatchQueue.main.async {
                self?.showNotificationBanner(title: "MouseBack", message: "Tombol Ditekan: \(action)")
            }
        }

        EventTapManager.shared.start()

        if !EventTapManager.shared.hasPermission {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                EventTapManager.shared.requestPermission()
            }
        }
    }

    // AppKit Level Global Monitor sebagai pelengkap CGEventTap
    private func setupGlobalMonitor() {
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.otherMouseDown, .otherMouseUp]) { [weak self] event in
            logDebug("[NSEvent Monitor] Tipe: \(event.type.rawValue), Button: \(event.buttonNumber)")
            if event.type == .otherMouseDown {
                if event.buttonNumber == 3 || event.buttonNumber == 4 || event.buttonNumber == 5 {
                    EventTapManager.shared.processButtonAction(buttonNumber: event.buttonNumber, source: "NSEventMonitor")
                }
            }
        }
        logDebug("NSEvent Global Monitor terdaftar.")
    }

    func menuWillOpen(_ menu: NSMenu) {
        _ = EventTapManager.shared.checkAccessibility(prompt: false)
        updateMenuStates()
    }

    private func updateMenuStates() {
        let isEnabled = EventTapManager.shared.isEnabled
        let hasPermission = EventTapManager.shared.checkAccessibility(prompt: false)
        let isSwapped = EventTapManager.shared.isSwapped
        let showNotifications = EventTapManager.shared.showNotifications

        if !hasPermission {
            statusMenuItem.title = "🟡 Butuh Izin Aksesibilitas"
        } else if isEnabled {
            statusMenuItem.title = "🟢 MouseBack: Aktif"
        } else {
            statusMenuItem.title = "⚪ MouseBack: Nonaktif"
        }

        toggleMenuItem.state = isEnabled ? .on : .off
        swapMenuItem.state = isSwapped ? .on : .off
        notificationMenuItem.state = showNotifications ? .on : .off

        if #available(macOS 13.0, *) {
            launchAtLoginMenuItem.state = (SMAppService.mainApp.status == .enabled) ? .on : .off
            launchAtLoginMenuItem.isEnabled = true
        } else {
            launchAtLoginMenuItem.state = .off
            launchAtLoginMenuItem.isEnabled = false
        }
    }

    private func showNotificationBanner(title: String, message: String) {
        let notification = NSUserNotification()
        notification.title = title
        notification.informativeText = message
        NSUserNotificationCenter.default.deliver(notification)
    }

    @objc private func toggleEnabled() {
        EventTapManager.shared.isEnabled.toggle()
        updateMenuStates()
    }

    @objc private func toggleSwap() {
        EventTapManager.shared.isSwapped.toggle()
        updateMenuStates()
    }

    @objc private func toggleNotifications() {
        EventTapManager.shared.showNotifications.toggle()
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

    @objc private func openLogFile() {
        let path = "/tmp/mouseback.log"
        if !FileManager.default.fileExists(atPath: path) {
            FileManager.default.createFile(atPath: path, contents: nil, attributes: nil)
        }
        NSWorkspace.shared.open(URL(fileURLWithPath: path))
    }

    @objc private func showAbout() {
        let alert = NSAlert()
        alert.messageText = "MouseBack"
        alert.informativeText = """
        Versi 1.2.0
        Aplikasi Menu Bar untuk tombol samping (Back & Forward) pada mouse Bluetooth Ugreen dan mouse lainnya.

        Shortcut navigasi:
        • Tombol Belakang: Cmd + [ (Kembali)
        • Tombol Depan: Cmd + ] (Maju)
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    @objc private func quitApp() {
        logDebug("Aplikasi MouseBack dihentikan oleh pengguna.")
        NSApplication.shared.terminate(nil)
    }

    deinit {
        if let monitor = globalMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }
}
