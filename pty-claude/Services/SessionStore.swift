import Foundation

enum SessionStore {
    static let sessionsKey = "session.list"
    static let seenSessionsKey = "session.seen"
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
        let startedAt: TimeInterval?  // 작업 시작 시간 (running 상태일 때만 유효)
        let duration: TimeInterval?   // 마지막 작업 소요 시간 (완료 시 계산)
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
        let record = SessionRecord(
            id: resolvedId,
            name: projectName,
            detail: detail,
            location: cwd,
            status: .normal,
            updatedAt: Date().timeIntervalSince1970,
            startedAt: nil,
            duration: nil,
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
    /// - Parameters:
    ///   - sessionId: 세션 ID
    ///   - status: 변경할 상태
    ///   - prompt: 프롬프트 (옵션)
    ///   - reorder: true면 같은 location 그룹 내 상위로 이동, false면 순서 유지
    static func updateSessionStatus(
        sessionId: String?,
        status: SessionRecordStatus,
        prompt: String? = nil,
        reorder: Bool = true
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
        let now = Date().timeIntervalSince1970
        let updatedPrompt = normalizedPrompt(prompt) ?? existing.lastPrompt
        let updatedResponse: String?
        let updatedStartedAt: TimeInterval?
        let updatedDuration: TimeInterval?

        // running/permission 상태는 작업 진행 중으로 간주 (시간 계속 측정)
        let isActiveStatus = (status == .running || status == .permission)
        let wasActiveStatus = (existing.status == .running || existing.status == .permission)

        if isActiveStatus {
            updatedResponse = status == .running ? nil : existing.lastResponse
            // 진행 중 상태 진입 시 startedAt 설정 (이미 진행 중이면 유지)
            updatedStartedAt = wasActiveStatus ? existing.startedAt : now
            // 기존 duration 유지 (누적됨)
            updatedDuration = existing.duration
        } else {
            // finished, ended 등 완료 상태에서만 duration 최종 계산
            updatedResponse = existing.lastResponse
            // 상태 전환 시 duration 계산: 기존 duration + 이번 경과 시간
            if let startedAt = existing.startedAt {
                let elapsed = now - startedAt
                let previousDuration = existing.duration ?? 0
                updatedDuration = previousDuration + elapsed
            } else {
                updatedDuration = existing.duration
            }
            updatedStartedAt = nil
        }
        // 기존 레코드 갱신
        let updated = SessionRecord(
            id: existing.id,
            name: existing.name,
            detail: existing.detail,
            location: existing.location,
            status: status,
            updatedAt: now,
            startedAt: updatedStartedAt,
            duration: updatedDuration,
            lastPrompt: updatedPrompt,
            lastResponse: updatedResponse
        )

        sessions.remove(at: index)
        if reorder {
            // 같은 location 그룹 내 첫 번째 위치에 삽입 (그룹 순서 유지)
            let insertIndex = sessions.firstIndex { $0.location == updated.location } ?? 0
            sessions.insert(updated, at: insertIndex)
        } else {
            // 순서 유지 (원래 위치에 삽입)
            sessions.insert(updated, at: min(index, sessions.count))
        }
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
            startedAt: existing.startedAt,
            duration: existing.duration,
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
        // seen 목록에서도 제거
        markSessionAsUnseen(sessionId: sessionId)
    }

    // MARK: - Seen 상태 관리

    /// 확인된 세션 ID 목록 로드
    static func loadSeenSessionIds() -> Set<String> {
        defaults.synchronize()
        guard let data = defaults.data(forKey: seenSessionsKey),
              let ids = try? JSONDecoder().decode(Set<String>.self, from: data) else {
            return []
        }
        return ids
    }

    /// 확인된 세션 ID 목록 저장
    private static func saveSeenSessionIds(_ ids: Set<String>) {
        guard let data = try? JSONEncoder().encode(ids) else {
            return
        }
        defaults.set(data, forKey: seenSessionsKey)
        defaults.synchronize()
        notifySessionsUpdated()
    }

    /// 세션을 확인됨으로 표시
    static func markSessionAsSeen(sessionId: String?) {
        let trimmedId = sessionId?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !trimmedId.isEmpty else { return }
        var seenIds = loadSeenSessionIds()
        seenIds.insert(trimmedId)
        saveSeenSessionIds(seenIds)
    }

    /// 세션을 미확인으로 표시 (running 상태로 전환 시)
    static func markSessionAsUnseen(sessionId: String?) {
        let trimmedId = sessionId?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !trimmedId.isEmpty else { return }
        var seenIds = loadSeenSessionIds()
        seenIds.remove(trimmedId)
        saveSeenSessionIds(seenIds)
    }

    /// 세션이 확인되었는지 여부
    static func isSessionSeen(sessionId: String?) -> Bool {
        let trimmedId = sessionId?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !trimmedId.isEmpty else { return true }
        return loadSeenSessionIds().contains(trimmedId)
    }
}
