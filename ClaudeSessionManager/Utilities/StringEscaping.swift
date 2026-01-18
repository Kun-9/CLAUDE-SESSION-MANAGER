// MARK: - 파일 설명
// StringEscaping: 문자열 이스케이프 유틸리티
// - AppleScript, Shell 등에서 사용하는 이스케이프 함수

import Foundation

enum StringEscaping {
    /// AppleScript 문자열 이스케이프
    /// - 백슬래시와 큰따옴표 이스케이프
    static func escapeForAppleScript(_ string: String) -> String {
        string
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }

    /// Shell 작은따옴표 문자열 이스케이프
    /// - 작은따옴표를 이스케이프
    static func escapeForShellSingleQuote(_ string: String) -> String {
        string.replacingOccurrences(of: "'", with: "'\\''")
    }
}
