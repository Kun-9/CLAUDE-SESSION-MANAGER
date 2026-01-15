// MARK: - 파일 설명
// ClipboardService: 시스템 클립보드 접근 통합
// - NSPasteboard 래핑으로 클립보드 복사 기능 제공
// - View에서 직접 NSPasteboard 접근 방지

import AppKit

enum ClipboardService {
    /// 시스템 클립보드에 텍스트 복사
    /// - Parameter text: 복사할 텍스트
    static func copy(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
}
