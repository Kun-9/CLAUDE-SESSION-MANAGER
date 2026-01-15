// MARK: - 파일 설명
// ITermService: iTerm2 앱 제어 서비스
// - 새 창에서 claude --resume 실행
// - 실행 중인 claude 창 활성화

import AppKit

enum ITermService {
    // MARK: - Public Methods

    /// 세션 이어하기 - iTerm2 새 창에서 claude --resume 실행
    static func resumeSession(sessionId: String, location: String?) {
        let safeSessionId = escapeForShellSingleQuote(sessionId)
        let cdCommand = location.map { "cd '\(escapeForShellSingleQuote($0))' && " } ?? ""
        let resumeCommand = "\(cdCommand)claude --resume '\(safeSessionId)'"

        executeInNewWindow(command: resumeCommand)
    }

    /// 새 세션 시작 - iTerm2 새 창에서 claude 실행
    static func startNewSession(location: String?) {
        let cdCommand = location.map { "cd '\(escapeForShellSingleQuote($0))' && " } ?? ""
        let command = "\(cdCommand)claude"

        executeInNewWindow(command: command)
    }

    /// 디렉토리 열기 - iTerm2 새 창에서 해당 디렉토리로 이동
    static func openDirectory(location: String?) {
        guard let location else { return }

        let command = "cd '\(escapeForShellSingleQuote(location))'"
        executeInNewWindow(command: command)
    }

    // MARK: - Private Helpers

    /// iTerm2 새 창에서 명령어 실행
    private static func executeInNewWindow(command: String) {
        let safeCommand = escapeForAppleScript(command)

        let script = """
        tell application "iTerm2"
            create window with default profile
            tell current session of current window
                write text "\(safeCommand)"
            end tell
            activate
        end tell
        """

        var error: NSDictionary?
        if let appleScript = NSAppleScript(source: script) {
            appleScript.executeAndReturnError(&error)
        }
    }

    /// 쉘 작은따옴표 내부 이스케이프
    /// - 예: it's → it'\''s (작은따옴표 종료, 이스케이프된 작은따옴표, 작은따옴표 시작)
    private static func escapeForShellSingleQuote(_ string: String) -> String {
        string.replacingOccurrences(of: "'", with: "'\\''")
    }

    /// AppleScript 문자열 이스케이프
    /// - 백슬래시와 큰따옴표 이스케이프
    private static func escapeForAppleScript(_ string: String) -> String {
        string
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }
}
