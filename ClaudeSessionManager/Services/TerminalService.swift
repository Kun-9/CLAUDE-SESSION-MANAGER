// MARK: - 파일 설명
// TerminalService: 터미널 앱 제어 통합 서비스
// - iTerm2, Terminal.app 지원
// - 설정에서 선택한 터미널로 명령 실행
// - 세션 이어하기, 새 세션 시작, 디렉토리 열기
// - 자동화 권한 확인 및 요청
// - 터미널 열기 전 사용자 확인

import AppKit

/// 터미널 작업 유형
enum TerminalAction {
    case resumeSession(sessionId: String)
    case newSession
    case openDirectory(path: String)

    var title: String {
        switch self {
        case .resumeSession:
            return "세션 이어하기"
        case .newSession:
            return "새 세션 시작"
        case .openDirectory:
            return "디렉토리 열기"
        }
    }

    var message: String {
        let terminalName = SettingsStore.terminalApp().displayName
        switch self {
        case .resumeSession(let sessionId):
            // sessionId의 앞 8자리만 표시
            let shortId = String(sessionId.prefix(8))
            return "\(terminalName)에서 세션(\(shortId)...)을 이어서 진행합니다."
        case .newSession:
            return "\(terminalName)에서 새 Claude 세션을 시작합니다."
        case .openDirectory(let path):
            // 경로의 마지막 컴포넌트만 표시
            let dirName = (path as NSString).lastPathComponent
            return "\(terminalName)에서 '\(dirName)' 디렉토리를 엽니다."
        }
    }
}

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

    /// 세션 이어하기 - 확인 후 터미널에서 claude --resume 실행
    static func resumeSession(sessionId: String, location: String?) {
        let action = TerminalAction.resumeSession(sessionId: sessionId)
        showConfirmation(for: action) { confirmed in
            guard confirmed else { return }

            let safeSessionId = StringEscaping.escapeForShellSingleQuote(sessionId)
            let cdCommand = location.map { "cd '\(StringEscaping.escapeForShellSingleQuote($0))' && " } ?? ""
            let resumeCommand = "\(cdCommand)claude --resume '\(safeSessionId)'"

            executeInNewWindow(command: resumeCommand)
        }
    }

    /// 새 세션 시작 - 확인 후 터미널에서 claude 실행
    static func startNewSession(location: String?) {
        let action = TerminalAction.newSession
        showConfirmation(for: action) { confirmed in
            guard confirmed else { return }

            let cdCommand = location.map { "cd '\(StringEscaping.escapeForShellSingleQuote($0))' && " } ?? ""
            let command = "\(cdCommand)claude"

            executeInNewWindow(command: command)
        }
    }

    /// 디렉토리 열기 - 확인 후 터미널에서 해당 디렉토리로 이동
    static func openDirectory(location: String?) {
        guard let location else { return }

        let action = TerminalAction.openDirectory(path: location)
        showConfirmation(for: action) { confirmed in
            guard confirmed else { return }

            let command = "cd '\(StringEscaping.escapeForShellSingleQuote(location))'"
            executeInNewWindow(command: command)
        }
    }

    // MARK: - Confirmation

    /// 터미널 작업 전 사용자 확인 (비동기)
    /// - Parameters:
    ///   - action: 수행할 터미널 작업
    ///   - completion: 사용자가 확인하면 true
    private static func showConfirmation(for action: TerminalAction, completion: @escaping (Bool) -> Void) {
        DispatchQueue.main.async {
            let window = NSApp.mainWindow ?? NSApp.windows.first(where: { $0.isVisible }) ?? NSApp.windows.first

            let alert = NSAlert()
            alert.messageText = action.title
            alert.informativeText = action.message
            alert.alertStyle = .informational

            alert.addButton(withTitle: "열기")
            alert.addButton(withTitle: "취소")

            if let window = window {
                alert.beginSheetModal(for: window) { response in
                    completion(response == .alertFirstButtonReturn)
                }
            } else {
                let response = alert.runModal()
                completion(response == .alertFirstButtonReturn)
            }
        }
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

    /// iTerm2에서 명령어 실행
    /// - iTerm2가 실행 중이면 새 탭 추가
    /// - iTerm2가 실행 중이 아니면 시작 후 기본 창 사용 (추가 창 생성 안함)
    private static func executeInITerm(command: String) {
        let safeCommand = StringEscaping.escapeForAppleScript(command)

        // iTerm2가 실행 중인지 먼저 확인 (tell 전에 확인해야 앱이 시작되기 전 상태를 알 수 있음)
        let script = """
        set wasRunning to application "iTerm2" is running
        tell application "iTerm2"
            activate
            if wasRunning then
                -- 이미 실행 중이면 새 탭 추가
                if (count of windows) > 0 then
                    tell current window
                        create tab with default profile
                        tell current session
                            write text "\(safeCommand)"
                        end tell
                    end tell
                else
                    create window with default profile
                    tell current session of current window
                        write text "\(safeCommand)"
                    end tell
                end if
            else
                -- 방금 시작됨: 기본 창이 생성될 때까지 대기 후 사용
                repeat while (count of windows) is 0
                    delay 0.1
                end repeat
                tell current session of current window
                    write text "\(safeCommand)"
                end tell
            end if
        end tell
        """

        executeAppleScript(script)
    }

    /// Terminal.app에서 명령어 실행
    /// - 기존 창이 있으면 새 탭 추가 (빠름)
    /// - 기존 창이 없으면 새 창 생성
    private static func executeInTerminal(command: String) {
        let safeCommand = StringEscaping.escapeForAppleScript(command)

        let script = """
        tell application "Terminal"
            if (count of windows) > 0 then
                tell front window
                    set newTab to do script "\(safeCommand)"
                end tell
            else
                do script "\(safeCommand)"
            end if
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

}
