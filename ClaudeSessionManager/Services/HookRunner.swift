import Foundation

struct HookEvent: Decodable {
    // Claude 훅 이벤트 입력(JSON) 필드
    let hook_event_name: String?
    let tool_name: String?
    let cwd: String?
    let session_id: String?
    let prompt: String?
    let transcript_path: String?
    let tool_input: ToolInput?
}

// MARK: - Tool Input (AskUserQuestion 등)

struct ToolInput: Codable {
    let questions: [ToolQuestion]?
}

struct ToolQuestion: Codable, Identifiable {
    let header: String?
    let question: String?
    let multiSelect: Bool?
    let options: [ToolOption]?

    var id: String { header ?? UUID().uuidString }
}

struct ToolOption: Codable, Identifiable {
    let label: String
    let description: String?

    var id: String { label }
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

        let toolName = event.tool_name ?? "Unknown"

        // 대화형 권한 요청이 활성화된 경우: 앱에서 사용자 선택을 기다림
        if SettingsStore.interactivePermissionEnabled() {
            handleInteractivePermission(event)
            return
        }

        // 기존 동작: 알림만 전송 (Claude Code 자체 UI 사용)
        guard SettingsStore.permissionEnabled() else { return }
        notify(message: "⚠️ 권한 요청: \(toolName)", cwd: event.cwd, sessionId: event.session_id)
    }

    // 대화형 권한 요청 처리 (앱에서 선택)
    private static func handleInteractivePermission(_ event: HookEvent) {
        let toolName = event.tool_name ?? "Unknown"

        // tool_input.questions를 PermissionQuestion으로 변환
        let questions: [PermissionQuestion]? = event.tool_input?.questions?.map { q in
            PermissionQuestion(
                header: q.header,
                question: q.question,
                multiSelect: q.multiSelect ?? false,
                options: q.options?.map { PermissionOption(label: $0.label, description: $0.description) } ?? []
            )
        }

        // 1. 요청 정보 저장 (앱이 읽을 수 있도록)
        let requestId = PermissionRequestStore.savePendingRequest(
            sessionId: event.session_id,
            toolName: event.tool_name,
            cwd: event.cwd,
            questions: questions
        )

        // 2. 알림 전송
        if SettingsStore.permissionEnabled() {
            let hasQuestions = questions?.isEmpty == false
            let suffix = hasQuestions ? " (선택지 있음)" : ""
            notify(message: "⚠️ 권한 요청: \(toolName)\(suffix)", cwd: event.cwd, sessionId: event.session_id)
        }

        // 3. 앱의 응답을 기다림 (blocking, 무한 대기)
        if let response = PermissionRequestStore.waitForResponse(requestId: requestId) {
            // 사용자가 선택함 → hookSpecificOutput 형식으로 응답
            writePermissionResponse(decision: response.decision, message: response.message, answers: response.answers)
        } else {
            // pending 삭제됨 (세션 종료 또는 터미널에서 처리) → Claude Code 자체 UI로 fallback
            // 세션 상태 업데이트
            SessionStore.updateSessionStatus(sessionId: event.session_id, status: .running)
        }
    }

    // hookSpecificOutput 형식으로 권한 응답 출력
    private static func writePermissionResponse(decision: PermissionDecision, message: String?, answers: [String: String]? = nil) {
        guard let data = PermissionRequestStore.formatHookResponse(decision: decision, message: message, answers: answers) else {
            return
        }
        FileHandle.standardOutput.write(data)
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
            prompt: event.prompt,
            resetDuration: true  // 새 프롬프트 시작 시 시간 초기화
        )
    }

    private static func handlePostToolUse(_ event: HookEvent) {
        SessionStore.updateSessionStatus(
            sessionId: event.session_id,
            status: .running
        )

        // 터미널에서 직접 처리된 경우 pending 권한 요청 삭제
        // (앱에서 응답하지 않았지만 Claude Code가 자체 UI로 처리 완료)
        PermissionRequestStore.deletePendingRequests(forSessionId: event.session_id)
    }

    private static func handleSessionEnd(_ event: HookEvent) {
        let trimmedId = event.session_id?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !trimmedId.isEmpty else { return }

        // pending 권한 요청 삭제 (세션 종료 시)
        PermissionRequestStore.deletePendingRequests(forSessionId: event.session_id)

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
