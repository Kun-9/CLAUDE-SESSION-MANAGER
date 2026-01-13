import Foundation

enum SessionStore {
    static let sessionsKey = "session.list"
    static let defaults = SettingsStore.defaults
    static let sessionsDidChangeNotification = Notification.Name("pty-claude.session.list.updated")

    struct SessionRecord: Codable, Identifiable {
        let id: String
        let name: String
        let detail: String
        let status: SessionRecordStatus
        let updatedAt: TimeInterval
        let lastPrompt: String?
    }

    enum SessionRecordStatus: String, Codable {
        case running
        case finished
        case permission
        case normal
        case ended
    }

    static func loadSessions() -> [SessionRecord] {
        defaults.synchronize()
        guard let data = defaults.data(forKey: sessionsKey) else {
            return []
        }
        return (try? JSONDecoder().decode([SessionRecord].self, from: data)) ?? []
    }

    static func saveSessions(_ sessions: [SessionRecord]) {
        guard let data = try? JSONEncoder().encode(sessions) else {
            return
        }
        defaults.set(data, forKey: sessionsKey)
        defaults.synchronize()
        notifySessionsUpdated()
    }

    static func notifySessionsUpdated() {
        DistributedNotificationCenter.default().postNotificationName(
            sessionsDidChangeNotification,
            object: nil,
            userInfo: nil,
            deliverImmediately: true
        )
    }

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

        let record = SessionRecord(
            id: resolvedId,
            name: projectName,
            detail: detail,
            status: .normal,
            updatedAt: Date().timeIntervalSince1970,
            lastPrompt: nil
        )

        var sessions = loadSessions()
        if let index = sessions.firstIndex(where: { $0.id == resolvedId }) {
            sessions.remove(at: index)
        }
        sessions.insert(record, at: 0)
        saveSessions(sessions)
    }

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

        let existing = sessions[index]
        let updatedPrompt = normalizedPrompt(prompt) ?? existing.lastPrompt
        let updated = SessionRecord(
            id: existing.id,
            name: existing.name,
            detail: existing.detail,
            status: status,
            updatedAt: Date().timeIntervalSince1970,
            lastPrompt: updatedPrompt
        )

        sessions.remove(at: index)
        sessions.insert(updated, at: 0)
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
}
