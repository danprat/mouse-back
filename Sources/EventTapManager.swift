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

typealias CGEventCopyIOHIDEventFunc = @convention(c) (CGEvent) -> Unmanaged<AnyObject>?
typealias IOHIDEventGetSenderIDFunc = @convention(c) (AnyObject) -> UInt64

final class EventTapManager {
    static let shared = EventTapManager()

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var permissionTimer: Timer?
    private var lastTriggerTime: TimeInterval = 0
    private let debounceInterval: TimeInterval = 0.35

    private var copyIOHIDEvent: CGEventCopyIOHIDEventFunc?
    private var getSenderID: IOHIDEventGetSenderIDFunc?

    // SenderID mouse yang diketahui (akan terdeteksi otomatis saat event mouse diterima)
    var knownMouseSenderIDs: Set<UInt64> = []

    var onStatusChanged: ((Bool, Bool) -> Void)?
    var onButtonTriggered: ((String) -> Void)?

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
            UserDefaults.standard.object(forKey: "MouseBackNotifications") as? Bool ?? true
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "MouseBackNotifications")
        }
    }

    private(set) var hasPermission: Bool = false

    private init() {
        setupDynamicSymbols()
        hasPermission = checkAccessibility(prompt: false)
        logDebug("EventTapManager diinisialisasi. Izin Aksesibilitas: \(hasPermission)")
    }

    private func setupDynamicSymbols() {
        if let cgHandle = dlopen("/System/Library/Frameworks/CoreGraphics.framework/CoreGraphics", RTLD_LAZY) {
            if let sym = dlsym(cgHandle, "CGEventCopyIOHIDEvent") {
                copyIOHIDEvent = unsafeBitCast(sym, to: CGEventCopyIOHIDEventFunc.self)
            }
        }
        if let iokitHandle = dlopen("/System/Library/Frameworks/IOKit.framework/IOKit", RTLD_LAZY) {
            if let sym = dlsym(iokitHandle, "IOHIDEventGetSenderID") {
                getSenderID = unsafeBitCast(sym, to: IOHIDEventGetSenderIDFunc.self)
            }
        }
    }

    func extractSenderID(for event: CGEvent) -> UInt64? {
        guard let copyFunc = copyIOHIDEvent, let getFunc = getSenderID else { return nil }
        if let unmanagedHID = copyFunc(event) {
            let hidEvent = unmanagedHID.takeRetainedValue()
            return getFunc(hidEvent)
        }
        return nil
    }

    func start() {
        logDebug("Memulai EventTapManager...")
        hasPermission = checkAccessibility(prompt: false)

        if hasPermission {
            setupTap()
        } else {
            logDebug("Izin belum aktif. Memulai timer pengecekan berkala...")
            permissionTimer?.invalidate()
            permissionTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
                guard let self = self else { return }
                if self.checkAccessibility(prompt: false) {
                    logDebug("Izin Aksesibilitas DIBERIKAN oleh pengguna!")
                    self.permissionTimer?.invalidate()
                    self.permissionTimer = nil
                    self.hasPermission = true
                    self.setupTap()
                    self.onStatusChanged?(self.isEnabled, self.hasPermission)
                }
            }
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
        return AXIsProcessTrustedWithOptions(options)
    }

    func setupTap() {
        guard eventTap == nil else {
            updateTapState()
            return
        }

        let eventTypes: [CGEventType] = [
            .otherMouseDown, .otherMouseUp,
            .keyDown, .keyUp
        ]
        var eventMask: CGEventMask = 0
        for evType in eventTypes {
            eventMask |= (1 << evType.rawValue)
        }

        let refcon = Unmanaged.passUnretained(self).toOpaque()

        let callback: CGEventTapCallBack = { proxy, type, event, refcon in
            guard let refcon = refcon else {
                return Unmanaged.passUnretained(event)
            }
            let manager = Unmanaged<EventTapManager>.fromOpaque(refcon).takeUnretainedValue()
            return manager.handleEvent(proxy: proxy, type: type, event: event)
        }

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
            logDebug("Gagal pada .cghidEventTap. Mencoba .cgSessionEventTap...")
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
                logDebug("GAGAL membuat CGEventTap pada semua level.")
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
            if let tap = eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return Unmanaged.passUnretained(event)
        }

        let keycode = event.getIntegerValueField(.keyboardEventKeycode)

        // 1. PENANGANAN TOMBOL SAMPING UGREEN (YANG MENGIRIM KEY 123 DAN KEY 124)
        if keycode == 123 || keycode == 124 {
            guard isEnabled else { return nil }

            if type == .keyDown {
                let isBack = (keycode == 123)
                let shouldGoBack = isSwapped ? !isBack : isBack

                if shouldGoBack {
                    let msg = "🟢 KEMBALI (Cmd + [) | Ugreen Side Button (Key \(keycode))"
                    logDebug(">>> \(msg)")
                    HUDWindowController.shared.updateEvent(text: msg, isSideButton: true)
                    triggerBack()
                    onButtonTriggered?("Kembali (Cmd + [)")
                } else {
                    let msg = "🟢 MAJU (Cmd + ]) | Ugreen Side Button (Key \(keycode))"
                    logDebug(">>> \(msg)")
                    HUDWindowController.shared.updateEvent(text: msg, isSideButton: true)
                    triggerForward()
                    onButtonTriggered?("Maju (Cmd + ])")
                }
            }

            // Telan event agar tidak terjadi aksi ganda atau kursor bergeser
            return nil
        }

        // 2. PENANGANAN MOUSE STANDARD LAINNYA (JIKA MENGIRIM BUTTON 3, 4, 5)
        if type == .otherMouseDown || type == .otherMouseUp {
            let buttonNumber = event.getIntegerValueField(.mouseEventButtonNumber)
            let isSide = (buttonNumber == 3 || buttonNumber == 4 || buttonNumber == 5)
            if isSide && isEnabled {
                if type == .otherMouseDown {
                    processButtonAction(buttonNumber: Int(buttonNumber), source: "CGEventTap")
                }
                return nil
            }
        }

        return Unmanaged.passUnretained(event)
    }

    func processButtonAction(buttonNumber: Int, source: String) {
        let isButtonBack = (buttonNumber == 3)
        let shouldGoBack = isSwapped ? !isButtonBack : isButtonBack

        if shouldGoBack {
            let msg = "🟢 KEMBALI (Cmd + [) | Button \(buttonNumber) via \(source)"
            logDebug(">>> \(msg)")
            HUDWindowController.shared.updateEvent(text: msg, isSideButton: true)
            triggerBack()
            onButtonTriggered?("Kembali (Cmd + [)")
        } else {
            let msg = "🟢 MAJU (Cmd + ]) | Button \(buttonNumber) via \(source)"
            logDebug(">>> \(msg)")
            HUDWindowController.shared.updateEvent(text: msg, isSideButton: true)
            triggerForward()
            onButtonTriggered?("Maju (Cmd + ])")
        }
    }

    private func triggerBack() {
        let now = Date().timeIntervalSince1970
        guard now - lastTriggerTime > debounceInterval else {
            logDebug("Debounce: lewati klik duplikat.")
            return
        }
        lastTriggerTime = now
        // Kirim shortcut navigasi Kembali: Cmd + [
        simulateShortcut(keyCode: 0x21, flags: .maskCommand)
    }

    private func triggerForward() {
        let now = Date().timeIntervalSince1970
        guard now - lastTriggerTime > debounceInterval else {
            logDebug("Debounce: lewati klik duplikat.")
            return
        }
        lastTriggerTime = now
        // Kirim shortcut navigasi Maju: Cmd + ]
        simulateShortcut(keyCode: 0x1E, flags: .maskCommand)
    }

    private func simulateShortcut(keyCode: CGKeyCode, flags: CGEventFlags) {
        DispatchQueue.global(qos: .userInteractive).async {
            let source = CGEventSource(stateID: .hidSystemState)

            if let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true) {
                keyDown.flags = flags
                keyDown.post(tap: .cghidEventTap)
            }

            usleep(25_000)

            if let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false) {
                keyUp.flags = flags
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
