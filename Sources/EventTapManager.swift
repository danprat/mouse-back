import Foundation
import CoreGraphics
import ApplicationServices
import AppKit

final class EventTapManager {
    static let shared = EventTapManager()

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var permissionTimer: Timer?

    var onStatusChanged: ((Bool, Bool) -> Void)? // (isEnabled, hasPermission)

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
        }
    }

    private(set) var hasPermission: Bool = false

    private init() {
        hasPermission = checkAccessibility(prompt: false)
    }

    func start() {
        if !hasPermission {
            // Check periodically until granted
            permissionTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
                guard let self = self else { return }
                if self.checkAccessibility(prompt: false) {
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
        _ = checkAccessibility(prompt: true)
    }

    func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    private func checkAccessibility(prompt: Bool) -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: prompt] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    private func setupTap() {
        guard eventTap == nil else {
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

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: callback,
            userInfo: refcon
        ) else {
            print("Gagal membuat CGEventTap. Pastikan izin Aksesibilitas sudah diberikan.")
            return
        }

        self.eventTap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        self.runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: isEnabled)
    }

    private func updateTapState() {
        guard let tap = eventTap else {
            if isEnabled && hasPermission {
                setupTap()
            }
            return
        }
        CGEvent.tapEnable(tap: tap, enable: isEnabled)
        onStatusChanged?(isEnabled, hasPermission)
    }

    private func handleEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
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

            // Button 3 = Mouse Button 4 (umumnya Back)
            // Button 4 = Mouse Button 5 (umumnya Forward)
            if buttonNumber == 3 || buttonNumber == 4 {
                if type == .otherMouseDown {
                    let isButtonBack = (buttonNumber == 3)
                    let shouldGoBack = isSwapped ? !isButtonBack : isButtonBack

                    if shouldGoBack {
                        triggerBack()
                    } else {
                        triggerForward()
                    }
                }
                // Konsumsi event agar tidak diteruskan ke sistem
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
            let source = CGEventSource(stateID: .combinedSessionState)

            if let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true) {
                keyDown.flags = flags
                keyDown.post(tap: .cghidEventTap)
            }

            // Jeda 15ms untuk memastikan aplikasi mendeteksi input dengan akurat
            usleep(15_000)

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
