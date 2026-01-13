import Foundation

struct HookEvent: Decodable {
    // Claude 훅 이벤트 입력(JSON) 필드
    let hook_event_name: String?
    let tool_name: String?
    let cwd: String?
    let session_id: String?
    let prompt: String?
    let transcript_path: String?
}

enum HookRunner {
    // 표준 입력으로 받은 훅 이벤트 처리
    static func run() {
        guard let event = readEvent() else {
            return
        }

        let hookType = event.hook_event_name ?? ""
        switch hookType {
        case "PreToolUse":
            handlePreToolUse(event)
        case "Stop":
            handleStop(event)
        case "PermissionRequest":
            handlePermission(event)
        case "SessionStart":
            handleSessionStart(event)
        case "UserPromptSubmit":
            handleUserPromptSubmit(event)
        case "SessionEnd":
            handleSessionEnd(event)
        default:
            break
        }

        SessionStore.notifySessionsUpdated()
    }

    // stdin JSON 디코딩
    private static func readEvent() -> HookEvent? {
        let input = FileHandle.standardInput.readDataToEndOfFile()
        guard !input.isEmpty else {
            return nil
        }

        return try? JSONDecoder().decode(HookEvent.self, from: input)
    }

    // PreToolUse 이벤트 처리
    private static func handlePreToolUse(_ event: HookEvent) {
        let toolName = event.tool_name ?? "Unknown"

        if SettingsStore.preToolUseEnabled() && shouldAllowTool(toolName) {
            notify(
                message: "도구: \(toolName)",
                cwd: event.cwd,
                sessionId: event.session_id
            )
        }

        // 훅 응답은 항상 allow=true
        writeAllowResponse()
    }

    // Stop 이벤트 처리
    private static func handleStop(_ event: HookEvent) {
        SessionStore.updateSessionStatus(sessionId: event.session_id, status: .finished)
        let summary = TranscriptArchiveService.archiveTranscript(
            sessionId: event.session_id,
            transcriptPath: event.transcript_path
        )
        if let summary {
            SessionStore.updateSessionArchive(
                sessionId: event.session_id,
                lastPrompt: summary.lastPrompt,
                lastResponse: summary.lastResponse
            )
        }
        guard SettingsStore.stopEnabled() else { return }
        notify(message: "✅ 응답이 완료되었습니다.", cwd: event.cwd, sessionId: event.session_id)
    }

    // PermissionRequest 이벤트 처리
    private static func handlePermission(_ event: HookEvent) {
        SessionStore.updateSessionStatus(sessionId: event.session_id, status: .permission)
        guard SettingsStore.permissionEnabled() else { return }
        let toolName = event.tool_name ?? "Unknown"
        notify(message: "⚠️ 권한 요청: \(toolName)", cwd: event.cwd, sessionId: event.session_id)
    }

    private static func handleSessionStart(_ event: HookEvent) {
        SessionStore.addSessionStart(sessionId: event.session_id, cwd: event.cwd)
    }

    private static func handleUserPromptSubmit(_ event: HookEvent) {
        SessionStore.updateSessionStatus(
            sessionId: event.session_id,
            status: .running,
            prompt: event.prompt
        )
    }

    private static func handleSessionEnd(_ event: HookEvent) {
        SessionStore.updateSessionStatus(sessionId: event.session_id, status: .ended)
    }

    // 허용 도구 목록 기반 필터링
    private static func shouldAllowTool(_ toolName: String) -> Bool {
        let tools = SettingsStore.preToolUseTools()
        if tools.isEmpty {
            return true
        }
        return tools.contains(toolName)
    }

    // 프로젝트 이름 기반 알림 전송
    private static func notify(message: String, cwd: String?, sessionId: String?) {
        let projectName = cwd?.split(separator: "/").last.map(String.init) ?? "Unknown"
        let fullMessage: String
        if let sessionId, !sessionId.isEmpty {
            fullMessage = "\(message)\nSession: \(sessionId)"
        } else {
            fullMessage = message
        }
        NotificationManager.send(
            title: "Claude [\(projectName)]",
            body: fullMessage
        )
    }

    // Claude 훅 응답 포맷(JSON)
    private static func writeAllowResponse() {
        let response = ["allow": true]
        guard let data = try? JSONSerialization.data(withJSONObject: response, options: []) else {
            return
        }
        FileHandle.standardOutput.write(data)
    }
}
