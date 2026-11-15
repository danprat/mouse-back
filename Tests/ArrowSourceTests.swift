import CoreGraphics

@main
struct ArrowSourceTests {
    static func main() {
        let ugreenSenderIDs: Set<UInt64> = [42]
        let noSenders: Set<UInt64> = []

        for keycode: Int64 in [123, 124] {
            for type: CGEventType in [.keyDown, .keyUp] {
                precondition(!shouldTranslateUgreenArrow(type: type, keycode: keycode, flags: [], senderID: 0, ugreenSenderIDs: noSenders))
                precondition(!shouldTranslateUgreenArrow(type: type, keycode: keycode, flags: [], senderID: 99, ugreenSenderIDs: noSenders))
                precondition(!shouldTranslateUgreenArrow(type: type, keycode: keycode, flags: [], senderID: 0, ugreenSenderIDs: ugreenSenderIDs))
                precondition(!shouldTranslateUgreenArrow(type: type, keycode: keycode, flags: [], senderID: 99, ugreenSenderIDs: ugreenSenderIDs))
                for modifier: CGEventFlags in [.maskShift, .maskAlternate, .maskControl, .maskCommand] {
                    precondition(!shouldTranslateUgreenArrow(type: type, keycode: keycode, flags: modifier, senderID: 42, ugreenSenderIDs: ugreenSenderIDs))
                }
                precondition(shouldTranslateUgreenArrow(type: type, keycode: keycode, flags: [], senderID: 42, ugreenSenderIDs: ugreenSenderIDs))
            }
            precondition(!shouldTranslateUgreenArrow(type: .otherMouseDown, keycode: keycode, flags: [], senderID: 42, ugreenSenderIDs: ugreenSenderIDs))
        }
        precondition(!shouldTranslateUgreenArrow(type: .keyDown, keycode: 125, flags: [], senderID: 42, ugreenSenderIDs: ugreenSenderIDs))
    }
}
