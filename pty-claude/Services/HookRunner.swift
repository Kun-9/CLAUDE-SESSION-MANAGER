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
        guard let envelope = readEvent() else {
            return
        }
        let event = envelope.event

        if SettingsStore.debugEnabled() {
            logDebugEvent(event, rawPayload: envelope.rawPayload)
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
        case "PostToolUse":
            handlePostToolUse(event)
        case "SessionEnd":
            handleSessionEnd(event)
        default:
            break
        }

        SessionStore.notifySessionsUpdated()
    }

    // stdin JSON 디코딩
    private struct HookEventEnvelope {
        let event: HookEvent
        let rawPayload: String
    }

    private static func readEvent() -> HookEventEnvelope? {
        let input = FileHandle.standardInput.readDataToEndOfFile()
        guard !input.isEmpty else {
            return nil
        }

        guard let event = try? JSONDecoder().decode(HookEvent.self, from: input) else {
            return nil
        }
        let rawPayload = String(data: input, encoding: .utf8) ?? ""
        return HookEventEnvelope(event: event, rawPayload: rawPayload)
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
        // 응답 완료 상태로 전환
        SessionStore.updateSessionStatus(sessionId: event.session_id, status: .finished)
        // transcript_path 기반 아카이빙
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
        let summary = TranscriptArchiveService.archiveTranscript(
            sessionId: event.session_id,
            transcriptPath: event.transcript_path
        )
        if summary != nil {
            SessionStore.updateSessionStatus(sessionId: event.session_id, status: .finished)
        }
        if let summary {
            SessionStore.updateSessionArchive(
                sessionId: event.session_id,
                lastPrompt: summary.lastPrompt,
                lastResponse: summary.lastResponse
            )
        }
    }

    private static func handleUserPromptSubmit(_ event: HookEvent) {
        // 새 작업 시작 시 미확인 상태로 전환 (완료 후 반짝이게)
        SessionStore.markSessionAsUnseen(sessionId: event.session_id)
        SessionStore.updateSessionStatus(
            sessionId: event.session_id,
            status: .running,
            prompt: event.prompt
        )
    }

    private static func handlePostToolUse(_ event: HookEvent) {
        SessionStore.updateSessionStatus(
            sessionId: event.session_id,
            status: .running
        )
    }

    private static func handleSessionEnd(_ event: HookEvent) {
        let trimmedId = event.session_id?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !trimmedId.isEmpty else { return }

        // 세션 정보 확인
        let sessions = SessionStore.loadSessions()
        guard let session = sessions.first(where: { $0.id == trimmedId }) else { return }

        // 대화가 없으면 (lastPrompt가 nil이면) 세션 삭제
        // 최소 한 번의 대화가 있어야 종료 카드가 생성됨
        if session.lastPrompt == nil {
            SessionStore.deleteSession(sessionId: event.session_id)
        } else {
            SessionStore.updateSessionStatus(sessionId: event.session_id, status: .ended)
        }
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
        NotificationManager.send(
            title: "Claude [\(projectName)]",
            body: message
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

    private static func logDebugEvent(_ event: HookEvent, rawPayload: String) {
        let entry = DebugLogEntry(
            timestamp: Date().timeIntervalSince1970,
            hookName: event.hook_event_name ?? "Unknown",
            toolName: event.tool_name,
            sessionId: event.session_id,
            cwd: event.cwd,
            transcriptPath: event.transcript_path,
            prompt: event.prompt,
            rawPayload: rawPayload
        )
        SettingsStore.appendDebugLog(entry)
    }
}
