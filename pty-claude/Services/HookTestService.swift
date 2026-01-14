import Foundation

enum HookTestService {
    /// 훅 테스트 설정
    struct Settings {
        let preToolUseEnabled: Bool
        let stopEnabled: Bool
        let permissionEnabled: Bool
        let preToolUseTools: String
    }

    /// 훅 테스트 결과
    struct Result {
        let status: String
        let success: Bool
    }

    /// 훅 테스트 실행
    static func run(command: String, sessionId: String?, settings: Settings) -> Result {
        let eventName = determineEventName(for: settings)
        let toolName = determineToolName(for: settings)
        let cwd = workingDirectory()

        var payload: [String: Any] = [
            "hook_event_name": eventName,
            "tool_name": toolName,
            "cwd": cwd,
        ]
        if let sessionId, !sessionId.isEmpty {
            payload["session_id"] = sessionId
        }

        do {
            let data = try JSONSerialization.data(withJSONObject: payload, options: [])
            let process = Process()
            process.executableURL = URL(fileURLWithPath: command)
            let inputPipe = Pipe()
            let outputPipe = Pipe()
            let errorPipe = Pipe()
            process.standardInput = inputPipe
            process.standardOutput = outputPipe
            process.standardError = errorPipe
            try process.run()
            inputPipe.fileHandleForWriting.write(data)
            inputPipe.fileHandleForWriting.closeFile()
            process.waitUntilExit()

            if process.terminationStatus == 0 {
                return Result(status: "Hook test sent (\(eventName)).", success: true)
            }

            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let errorText = String(data: errorData, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)

            if let errorText, !errorText.isEmpty {
                return Result(status: "Hook test failed: \(errorText)", success: false)
            }
            return Result(status: "Hook test failed with status \(process.terminationStatus).", success: false)
        } catch {
            return Result(status: "Failed to run hook test: \(error.localizedDescription)", success: false)
        }
    }

    /// 테스트할 이벤트 이름 결정
    static func determineEventName(for settings: Settings) -> String {
        if settings.preToolUseEnabled {
            return "PreToolUse"
        }
        if settings.stopEnabled {
            return "Stop"
        }
        if settings.permissionEnabled {
            return "PermissionRequest"
        }
        return "PreToolUse"
    }

    /// 테스트할 도구 이름 결정
    static func determineToolName(for settings: Settings) -> String {
        let tools = settings.preToolUseTools
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        let firstTool = tools.first { !$0.isEmpty }
        return firstTool ?? "AskUserQuestion"
    }

    /// 작업 디렉토리 반환
    static func workingDirectory() -> String {
        let current = FileManager.default.currentDirectoryPath
        if current == "/" {
            return FileManager.default.homeDirectoryForCurrentUser.path
        }
        return current
    }
}
