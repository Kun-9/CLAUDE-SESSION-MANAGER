import Foundation

enum SessionStore {
    static let sessionsKey = "session.list"
    static let defaults = SettingsStore.defaults
    static let sessionsDidChangeNotification = Notification.Name("pty-claude.session.list.updated")

    // 세션 저장 레코드
    struct SessionRecord: Codable, Identifiable {
        let id: String
        let name: String
        let detail: String
        let location: String?
        let status: SessionRecordStatus
        let updatedAt: TimeInterval
        let lastPrompt: String?
        let lastResponse: String?
    }

    // 세션 상태 코드
    enum SessionRecordStatus: String, Codable {
        case running
        case finished
        case permission
        case normal
        case ended
    }

    // 저장된 세션 목록 로드
    static func loadSessions() -> [SessionRecord] {
        defaults.synchronize()
        guard let data = defaults.data(forKey: sessionsKey) else {
            return []
        }
        return (try? JSONDecoder().decode([SessionRecord].self, from: data)) ?? []
    }

    // 세션 목록 저장
    static func saveSessions(_ sessions: [SessionRecord]) {
        guard let data = try? JSONEncoder().encode(sessions) else {
            return
        }
        defaults.set(data, forKey: sessionsKey)
        defaults.synchronize()
        notifySessionsUpdated()
    }

    // 세션 변경 알림 전파
    static func notifySessionsUpdated() {
        DistributedNotificationCenter.default().postNotificationName(
            sessionsDidChangeNotification,
            object: nil,
            userInfo: nil,
            deliverImmediately: true
        )
    }

    // SessionStart 이벤트 처리
    static func addSessionStart(sessionId: String?, cwd: String?) {
        let trimmedId = sessionId?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !trimmedId.isEmpty else {
            return
        }
        let resolvedId = trimmedId
        let projectName = cwd?
            .split(separator: "/")
            .last
            .map(String.init) ?? "Claude Session"

        let detail: String
        if let cwd, !cwd.isEmpty {
            detail = cwd
        } else {
            detail = "session: \(trimmedId)"
        }

        // 새로운 세션 레코드 생성
        // 새로운 세션 레코드 생성
        let record = SessionRecord(
            id: resolvedId,
            name: projectName,
            detail: detail,
            location: cwd,
            status: .normal,
            updatedAt: Date().timeIntervalSince1970,
            lastPrompt: nil,
            lastResponse: nil
        )

        var sessions = loadSessions()
        if let index = sessions.firstIndex(where: { $0.id == resolvedId }) {
            sessions.remove(at: index)
        }
        sessions.insert(record, at: 0)
        saveSessions(sessions)
    }

    // 상태 업데이트 + 최근 변경 시각 갱신
    static func updateSessionStatus(
        sessionId: String?,
        status: SessionRecordStatus,
        prompt: String? = nil
    ) {
        let trimmedId = sessionId?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !trimmedId.isEmpty else {
            return
        }

        var sessions = loadSessions()
        guard let index = sessions.firstIndex(where: { $0.id == trimmedId }) else {
            return
        }

        // 기존 레코드 갱신
        let existing = sessions[index]
        let updatedPrompt = normalizedPrompt(prompt) ?? existing.lastPrompt
        let updatedResponse: String?
        if status == .running {
            updatedResponse = nil
        } else {
            updatedResponse = existing.lastResponse
        }
        // 기존 레코드 갱신
        let updated = SessionRecord(
            id: existing.id,
            name: existing.name,
            detail: existing.detail,
            location: existing.location,
            status: status,
            updatedAt: Date().timeIntervalSince1970,
            lastPrompt: updatedPrompt,
            lastResponse: updatedResponse
        )

        sessions.remove(at: index)
        sessions.insert(updated, at: 0)
        saveSessions(sessions)
    }

    // 아카이브 요약 정보 갱신
    static func updateSessionArchive(
        sessionId: String?,
        lastPrompt: String?,
        lastResponse: String?
    ) {
        let trimmedId = sessionId?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !trimmedId.isEmpty else {
            return
        }

        var sessions = loadSessions()
        guard let index = sessions.firstIndex(where: { $0.id == trimmedId }) else {
            return
        }

        // 기존 레코드 갱신
        // 기존 레코드 갱신
        let existing = sessions[index]
        let updatedPrompt = normalizedPrompt(lastPrompt) ?? existing.lastPrompt
        let updatedResponse = normalizedPrompt(lastResponse) ?? existing.lastResponse
        let updated = SessionRecord(
            id: existing.id,
            name: existing.name,
            detail: existing.detail,
            location: existing.location,
            status: existing.status,
            updatedAt: Date().timeIntervalSince1970,
            lastPrompt: updatedPrompt,
            lastResponse: updatedResponse
        )

        sessions[index] = updated
        saveSessions(sessions)
    }

    private static func normalizedPrompt(_ prompt: String?) -> String? {
        guard let prompt, !prompt.isEmpty else {
            return nil
        }
        let compact = prompt
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return compact.isEmpty ? nil : compact
    }

    // 세션과 메타데이터 삭제
    static func deleteSession(sessionId: String?) {
        let trimmedId = sessionId?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !trimmedId.isEmpty else {
            return
        }
        var sessions = loadSessions()
        sessions.removeAll { $0.id == trimmedId }
        saveSessions(sessions)
    }
}
