// MARK: - 파일 설명
// ITermService: iTerm2 앱 제어 서비스
// - 새 창에서 claude --resume 실행
// - 실행 중인 claude 창 활성화

import AppKit

enum ITermService {
    // MARK: - Public Methods

    /// 세션 이어하기 - iTerm2 새 창에서 claude --resume 실행
    static func resumeSession(sessionId: String, location: String?) {
        let cdCommand = location.map { "cd '\($0)' && " } ?? ""
        let resumeCommand = "\(cdCommand)claude --resume '\(sessionId)'"

        let script = """
        tell application "iTerm2"
            create window with default profile
            tell current session of current window
                write text "\(resumeCommand)"
            end tell
            activate
        end tell
        """

        var error: NSDictionary?
        if let appleScript = NSAppleScript(source: script) {
            appleScript.executeAndReturnError(&error)
        }
    }

    /// 새 세션 시작 - iTerm2 새 창에서 claude 실행
    static func startNewSession(location: String?) {
        let cdCommand = location.map { "cd '\($0)' && " } ?? ""
        let command = "\(cdCommand)claude"

        let script = """
        tell application "iTerm2"
            create window with default profile
            tell current session of current window
                write text "\(command)"
            end tell
            activate
        end tell
        """

        var error: NSDictionary?
        if let appleScript = NSAppleScript(source: script) {
            appleScript.executeAndReturnError(&error)
        }
    }

    /// 디렉토리 열기 - iTerm2 새 창에서 해당 디렉토리로 이동
    static func openDirectory(location: String?) {
        guard let location else { return }

        let script = """
        tell application "iTerm2"
            create window with default profile
            tell current session of current window
                write text "cd '\(location)'"
            end tell
            activate
        end tell
        """

        var error: NSDictionary?
        if let appleScript = NSAppleScript(source: script) {
            appleScript.executeAndReturnError(&error)
        }
    }
}
