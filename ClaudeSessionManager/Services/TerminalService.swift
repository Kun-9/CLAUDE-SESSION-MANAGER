// MARK: - 파일 설명
// TerminalService: 터미널 앱 제어 통합 서비스
// - iTerm2, Terminal.app 지원
// - 설정에서 선택한 터미널로 명령 실행
// - 세션 이어하기, 새 세션 시작, 디렉토리 열기
// - 자동화 권한 확인 및 요청

import AppKit

enum TerminalService {
    // MARK: - Permission Check

    /// 터미널 앱에 대한 자동화 권한 확인
    /// - 간단한 AppleScript를 실행하여 권한 상태 확인
    /// - Returns: 권한이 허용되었으면 true
    static func checkAutomationPermission(for app: TerminalApp) -> Bool {
        let script: String
        switch app {
        case .iTerm2:
            script = """
            tell application "iTerm2"
                return name
            end tell
            """
        case .terminal:
            script = """
            tell application "Terminal"
                return name
            end tell
            """
        }

        var error: NSDictionary?
        guard let appleScript = NSAppleScript(source: script) else {
            return false
        }

        appleScript.executeAndReturnError(&error)

        // 에러가 없으면 권한 허용됨
        if error == nil {
            return true
        }

        // 에러 코드 확인 (-1743: 권한 거부)
        if let errorNumber = error?[NSAppleScript.errorNumber] as? Int,
           errorNumber == -1743
        {
            return false
        }

        // 다른 에러는 권한 문제가 아닐 수 있음 (앱 미설치 등)
        return false
    }

    /// 자동화 권한 요청 (시스템 대화상자 트리거)
    /// - 앱에 간단한 명령을 보내 시스템이 권한 대화상자를 표시하도록 함
    static func requestAutomationPermission(for app: TerminalApp) {
        let script: String
        switch app {
        case .iTerm2:
            script = """
            tell application "iTerm2"
                return name
            end tell
            """
        case .terminal:
            script = """
            tell application "Terminal"
                return name
            end tell
            """
        }

        var error: NSDictionary?
        if let appleScript = NSAppleScript(source: script) {
            appleScript.executeAndReturnError(&error)
        }
    }

    /// 시스템 환경설정 > 개인 정보 보호 및 보안 > 자동화 열기
    static func openAutomationSettings() {
        // macOS Ventura 이상
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation") {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - Public Methods

    /// 세션 이어하기 - 새 창에서 claude --resume 실행
    static func resumeSession(sessionId: String, location: String?) {
        let safeSessionId = escapeForShellSingleQuote(sessionId)
        let cdCommand = location.map { "cd '\(escapeForShellSingleQuote($0))' && " } ?? ""
        let resumeCommand = "\(cdCommand)claude --resume '\(safeSessionId)'"

        executeInNewWindow(command: resumeCommand)
    }

    /// 새 세션 시작 - 새 창에서 claude 실행
    static func startNewSession(location: String?) {
        let cdCommand = location.map { "cd '\(escapeForShellSingleQuote($0))' && " } ?? ""
        let command = "\(cdCommand)claude"

        executeInNewWindow(command: command)
    }

    /// 디렉토리 열기 - 새 창에서 해당 디렉토리로 이동
    static func openDirectory(location: String?) {
        guard let location else { return }

        let command = "cd '\(escapeForShellSingleQuote(location))'"
        executeInNewWindow(command: command)
    }

    // MARK: - Private Helpers

    /// 설정된 터미널 앱에서 명령어 실행
    private static func executeInNewWindow(command: String) {
        let terminalApp = SettingsStore.terminalApp()

        switch terminalApp {
        case .iTerm2:
            executeInITerm(command: command)
        case .terminal:
            executeInTerminal(command: command)
        }
    }

    /// iTerm2에서 새 창으로 명령어 실행
    private static func executeInITerm(command: String) {
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

        executeAppleScript(script)
    }

    /// Terminal.app에서 새 창으로 명령어 실행
    private static func executeInTerminal(command: String) {
        let safeCommand = escapeForAppleScript(command)

        let script = """
        tell application "Terminal"
            do script "\(safeCommand)"
            activate
        end tell
        """

        executeAppleScript(script)
    }

    /// AppleScript 실행
    private static func executeAppleScript(_ script: String) {
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
