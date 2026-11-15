import AppKit

final class HUDWindowController: NSWindowController {
    static let shared = HUDWindowController()

    private var label: NSTextField!

    init() {
        let screenRect = NSScreen.main?.visibleFrame ?? NSRect(x: 100, y: 100, width: 800, height: 600)
        let panelWidth: CGFloat = 340
        let panelHeight: CGFloat = 110
        let panelRect = NSRect(
            x: screenRect.maxX - panelWidth - 20,
            y: screenRect.maxY - panelHeight - 20,
            width: panelWidth,
            height: panelHeight
        )

        let panel = NSPanel(
            contentRect: panelRect,
            styleMask: [.titled, .utilityWindow, .nonactivatingPanel, .hudWindow],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.isFloatingPanel = true
        panel.title = "MouseBack - Pemantau Sinyal Mouse"
        panel.isOpaque = false
        panel.backgroundColor = NSColor.black.withAlphaComponent(0.85)
        panel.hasShadow = true

        let contentView = NSView(frame: NSRect(x: 0, y: 0, width: panelWidth, height: panelHeight))

        let titleLabel = NSTextField(labelWithString: "🖱️ Sinyal Event Mouse Terakhir:")
        titleLabel.frame = NSRect(x: 15, y: 70, width: panelWidth - 30, height: 20)
        titleLabel.font = NSFont.boldSystemFont(ofSize: 12)
        titleLabel.textColor = .white
        contentView.addSubview(titleLabel)

        let statusText = NSTextField(labelWithString: "Menunggu interaksi mouse...")
        statusText.frame = NSRect(x: 15, y: 15, width: panelWidth - 30, height: 50)
        statusText.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        statusText.textColor = NSColor(calibratedRed: 0.3, green: 0.85, blue: 1.0, alpha: 1.0)
        statusText.maximumNumberOfLines = 3
        contentView.addSubview(statusText)

        panel.contentView = contentView

        super.init(window: panel)
        self.label = statusText
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func updateEvent(text: String, isSideButton: Bool = false) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.label.stringValue = text
            if isSideButton {
                self.label.textColor = NSColor(calibratedRed: 0.2, green: 1.0, blue: 0.4, alpha: 1.0)
            } else {
                self.label.textColor = NSColor(calibratedRed: 0.3, green: 0.85, blue: 1.0, alpha: 1.0)
            }
        }
    }

    func showHUD() {
        self.window?.orderFront(nil)
    }

    func hideHUD() {
        self.window?.orderOut(nil)
    }
}
