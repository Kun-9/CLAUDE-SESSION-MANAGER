// MARK: - 파일 설명
// HookTestService: 훅 테스트 실행 관리
// - 훅 CLI 프로세스 실행 및 결과 처리
// - JSON 페이로드 생성 및 stdin 전달
// - 테스트 이벤트/도구 이름 결정 로직

import Foundation

enum HookTestService {
    // MARK: - Constants

    private enum EventName {
        static let preToolUse = "PreToolUse"
        static let stop = "Stop"
        static let permissionRequest = "PermissionRequest"
    }

    private enum PayloadKey {
        static let hookEventName = "hook_event_name"
        static let toolName = "tool_name"
        static let cwd = "cwd"
        static let sessionId = "session_id"
    }

    private enum DefaultValue {
        static let toolName = "AskUserQuestion"
    }

    // MARK: - Types

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

    // MARK: - Public Methods

    /// 훅 테스트 실행
    /// - Parameters:
    ///   - command: 훅 CLI 실행 파일 경로
    ///   - sessionId: 세션 ID (선택)
    ///   - settings: 훅 테스트 설정
    /// - Returns: 테스트 결과 (상태 메시지 및 성공 여부)
    static func run(command: String, sessionId: String?, settings: Settings) -> Result {
        // 1. 테스트 파라미터 결정
        let eventName = determineEventName(for: settings)
        let toolName = determineToolName(for: settings)
        let cwd = workingDirectory()

        // 2. JSON 페이로드 구성
        var payload: [String: Any] = [
            PayloadKey.hookEventName: eventName,
            PayloadKey.toolName: toolName,
            PayloadKey.cwd: cwd,
        ]
        if let sessionId, !sessionId.isEmpty {
            payload[PayloadKey.sessionId] = sessionId
        }

        // 3. 프로세스 실행 및 결과 반환
        return executeProcess(command: command, payload: payload, eventName: eventName)
    }

    // MARK: - Private Helpers

    /// 테스트할 이벤트 이름 결정
    private static func determineEventName(for settings: Settings) -> String {
        if settings.preToolUseEnabled {
            return EventName.preToolUse
        }
        if settings.stopEnabled {
            return EventName.stop
        }
        if settings.permissionEnabled {
            return EventName.permissionRequest
        }
        return EventName.preToolUse
    }

    /// 테스트할 도구 이름 결정
    private static func determineToolName(for settings: Settings) -> String {
        let tools = settings.preToolUseTools
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        return tools.first { !$0.isEmpty } ?? DefaultValue.toolName
    }

    /// 작업 디렉토리 반환
    private static func workingDirectory() -> String {
        let current = FileManager.default.currentDirectoryPath
        if current == "/" {
            return FileManager.default.homeDirectoryForCurrentUser.path
        }
        return current
    }

    /// 프로세스 실행 및 결과 처리
    private static func executeProcess(command: String, payload: [String: Any], eventName: String) -> Result {
        do {
            // JSON 직렬화
            let data = try JSONSerialization.data(withJSONObject: payload, options: [])

            // 프로세스 및 파이프 설정
            let process = Process()
            process.executableURL = URL(fileURLWithPath: command)
            let inputPipe = Pipe()
            let outputPipe = Pipe()
            let errorPipe = Pipe()
            process.standardInput = inputPipe
            process.standardOutput = outputPipe
            process.standardError = errorPipe

            // 프로세스 실행
            try process.run()

            // stdin으로 페이로드 전송
            inputPipe.fileHandleForWriting.write(data)
            inputPipe.fileHandleForWriting.closeFile()

            // 종료 대기
            process.waitUntilExit()

            // 결과 처리
            if process.terminationStatus == 0 {
                return Result(status: "Hook test sent (\(eventName)).", success: true)
            }

            // 에러 메시지 추출
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
}
