import AppKit

enum ClipboardService {
    /// 시스템 클립보드에 텍스트 복사
    static func copy(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
}
