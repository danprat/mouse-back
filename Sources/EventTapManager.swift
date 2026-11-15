import Foundation
import CoreGraphics
import ApplicationServices
import AppKit

func logDebug(_ message: String) {
    let timestamp = ISO8601DateFormatter().string(from: Date())
    let line = "[\(timestamp)] \(message)\n"
    if let data = line.data(using: .utf8) {
        let logPath = "/tmp/mouseback.log"
        if let fileHandle = FileHandle(forWritingAtPath: logPath) {
            fileHandle.seekToEndOfFile()
            fileHandle.write(data)
            try? fileHandle.close()
        } else {
            FileManager.default.createFile(atPath: logPath, contents: data, attributes: nil)
        }
    }
    NSLog("[MouseBack] %@", message)
}

final class EventTapManager {
    static let shared = EventTapManager()

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var permissionTimer: Timer?

    var onStatusChanged: ((Bool, Bool) -> Void)? // (isEnabled, hasPermission)
    var onButtonTriggered: ((String) -> Void)?   // (actionName)

    var isEnabled: Bool {
        get {
            UserDefaults.standard.object(forKey: "MouseBackEnabled") as? Bool ?? true
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "MouseBackEnabled")
            updateTapState()
        }
    }

    var isSwapped: Bool {
        get {
            UserDefaults.standard.bool(forKey: "MouseBackSwapped")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "MouseBackSwapped")
            logDebug("Pengaturan tombol ditukar: \(newValue)")
        }
    }

    var showNotifications: Bool {
        get {
            UserDefaults.standard.bool(forKey: "MouseBackNotifications")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "MouseBackNotifications")
        }
    }

    private(set) var hasPermission: Bool = false

    private init() {
        hasPermission = checkAccessibility(prompt: false)
        logDebug("EventTapManager diinisialisasi. Izin Aksesibilitas: \(hasPermission)")
    }

    func start() {
        logDebug("Memulai EventTapManager...")
        hasPermission = checkAccessibility(prompt: false)

        if !hasPermission {
            logDebug("Izin belum diberikan. Memulai timer pengecekan berkala (setiap 1.5 detik)...")
            permissionTimer?.invalidate()
            permissionTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
                guard let self = self else { return }
                if self.checkAccessibility(prompt: false) {
                    logDebug("Izin Aksesibilitas terdeteksi telah DIBERIKAN oleh pengguna!")
                    self.permissionTimer?.invalidate()
                    self.permissionTimer = nil
                    self.hasPermission = true
                    self.setupTap()
                    self.onStatusChanged?(self.isEnabled, self.hasPermission)
                }
            }
        } else {
            setupTap()
        }
        onStatusChanged?(isEnabled, hasPermission)
    }

    func requestPermission() {
        logDebug("Meminta izin aksesibilitas ke sistem macOS...")
        _ = checkAccessibility(prompt: true)
    }

    func openAccessibilitySettings() {
        logDebug("Membuka System Settings > Privacy & Security > Accessibility...")
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    func checkAccessibility(prompt: Bool) -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: prompt] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(options)
        return trusted
    }

    private func setupTap() {
        guard eventTap == nil else {
            logDebug("Tap sudah ada, memperbarui state...")
            updateTapState()
            return
        }

        let eventMask: CGEventMask = (1 << CGEventType.otherMouseDown.rawValue) | (1 << CGEventType.otherMouseUp.rawValue)

        let refcon = Unmanaged.passUnretained(self).toOpaque()

        let callback: CGEventTapCallBack = { proxy, type, event, refcon in
            guard let refcon = refcon else {
                return Unmanaged.passUnretained(event)
            }
            let manager = Unmanaged<EventTapManager>.fromOpaque(refcon).takeUnretainedValue()
            return manager.handleEvent(proxy: proxy, type: type, event: event)
        }

        // PENTING: Gunakan .cghidEventTap terlebih dahulu karena mouse Bluetooth (Ugreen dll.)
        // mengirim event pada level hardware HID. Jika gagal, baru gunakan .cgSessionEventTap.
        var tap: CFMachPort? = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: callback,
            userInfo: refcon
        )

        if tap != nil {
            logDebug("Berhasil membuat CGEventTap pada level .cghidEventTap!")
        } else {
            logDebug("Gagal membuat pada level .cghidEventTap. Mencoba level .cgSessionEventTap...")
            tap = CGEvent.tapCreate(
                tap: .cgSessionEventTap,
                place: .headInsertEventTap,
                options: .defaultTap,
                eventsOfInterest: eventMask,
                callback: callback,
                userInfo: refcon
            )
            if tap != nil {
                logDebug("Berhasil membuat CGEventTap pada level .cgSessionEventTap!")
            } else {
                logDebug("GAGAL membuat CGEventTap pada semua level. Pastikan Izin Aksesibilitas sudah aktif di System Settings.")
                return
            }
        }

        self.eventTap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap!, 0)
        self.runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap!, enable: isEnabled)
        logDebug("EventTap aktif dan terdaftar di RunLoop utama (isEnabled: \(isEnabled)).")
    }

    private func updateTapState() {
        guard let tap = eventTap else {
            if isEnabled && hasPermission {
                setupTap()
            }
            return
        }
        CGEvent.tapEnable(tap: tap, enable: isEnabled)
        logDebug("State tap diperbarui -> isEnabled: \(isEnabled)")
        onStatusChanged?(isEnabled, hasPermission)
    }

    private func handleEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            logDebug("Peringatan: EventTap sempat dinonaktifkan sistem (\(type.rawValue)), mengaktifkan kembali...")
            if let tap = eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return Unmanaged.passUnretained(event)
        }

        guard isEnabled else {
            return Unmanaged.passUnretained(event)
        }

        if type == .otherMouseDown || type == .otherMouseUp {
            let buttonNumber = event.getIntegerValueField(.mouseEventButtonNumber)
            logDebug("Event mouse terdeteksi: type=\(type.rawValue), buttonNumber=\(buttonNumber)")

            // Tombol 3 = Mouse Button 4 (umumnya Back)
            // Tombol 4 = Mouse Button 5 (umumnya Forward)
            // Tombol 5 = Beberapa mouse menamai Forward sebagai button 5
            if buttonNumber == 3 || buttonNumber == 4 || buttonNumber == 5 {
                if type == .otherMouseDown {
                    let isButtonBack = (buttonNumber == 3)
                    let shouldGoBack = isSwapped ? !isButtonBack : isButtonBack

                    if shouldGoBack {
                        logDebug(">>> Aksi: KEMBALI (Back - Cmd + [) dipicu oleh buttonNumber \(buttonNumber)")
                        triggerBack()
                        onButtonTriggered?("Kembali (Cmd + [)")
                    } else {
                        logDebug(">>> Aksi: MAJU (Forward - Cmd + ]) dipicu oleh buttonNumber \(buttonNumber)")
                        triggerForward()
                        onButtonTriggered?("Maju (Cmd + ])")
                    }
                }
                // Konsumsi event agar tidak menimbulkan efek samping lain
                return nil
            }
        }

        return Unmanaged.passUnretained(event)
    }

    private func triggerBack() {
        // Cmd + [ (kVK_ANSI_LeftBracket = 0x21)
        simulateShortcut(keyCode: 0x21, flags: .maskCommand)
    }

    private func triggerForward() {
        // Cmd + ] (kVK_ANSI_RightBracket = 0x1E)
        simulateShortcut(keyCode: 0x1E, flags: .maskCommand)
    }

    private func simulateShortcut(keyCode: CGKeyCode, flags: CGEventFlags) {
        DispatchQueue.global(qos: .userInteractive).async {
            let source = CGEventSource(stateID: .hidSystemState)

            if let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true) {
                keyDown.flags = flags
                // Kirim ke session event tap (menjangkau aplikasi yang aktif di depan)
                keyDown.post(tap: .cgSessionEventTap)
                keyDown.post(tap: .cghidEventTap)
            }

            usleep(25_000) // 25ms jeda agar OS dan browser mencatat event

            if let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false) {
                keyUp.flags = flags
                keyUp.post(tap: .cgSessionEventTap)
                keyUp.post(tap: .cghidEventTap)
            }
        }
    }

    deinit {
        permissionTimer?.invalidate()
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
    }
}
