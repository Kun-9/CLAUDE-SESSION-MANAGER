// MARK: - 파일 설명
// SessionStore: 세션 메타데이터 CRUD 및 상태 관리
// - UserDefaults 기반 영속화
// - DistributedNotificationCenter로 변경 알림 전파
// - 메모리 캐싱으로 반복적인 JSON 파싱 방지

import Foundation

enum SessionStore {
    static let sessionsKey = "session.list"
    static let seenSessionsKey = "session.seen"
    static let defaults = SettingsStore.defaults
    static let sessionsDidChangeNotification = Notification.Name("ClaudeSessionManager.session.list.updated")

    // MARK: - 캐시 (성능 최적화)

    /// 세션 목록 캐시 (JSON 파싱 비용 절감)
    private static var cachedSessions: [SessionRecord]?
    /// 세션 ID → 인덱스 매핑 (O(1) 검색용)
    private static var sessionIndexMap: [String: Int] = [:]
    /// seen 세션 ID 캐시
    private static var cachedSeenIds: Set<String>?

    /// 캐시 무효화 (외부 변경 감지 시 호출)
    static func invalidateCache() {
        cachedSessions = nil
        sessionIndexMap.removeAll()
        cachedSeenIds = nil
    }

    // 세션 저장 레코드
    struct SessionRecord: Codable, Identifiable {
        let id: String
        let name: String
        let detail: String
        let location: String?
        let status: SessionStatus
        let updatedAt: TimeInterval
        let startedAt: TimeInterval?  // 작업 시작 시간 (running 상태일 때만 유효)
        let duration: TimeInterval?   // 마지막 작업 소요 시간 (완료 시 계산)
        let lastPrompt: String?
        let lastResponse: String?
    }

    // MARK: - CRUD 메서드

    /// 저장된 세션 목록 로드 (캐시 우선)
    static func loadSessions() -> [SessionRecord] {
        // 캐시가 있으면 바로 반환
        if let cached = cachedSessions {
            return cached
        }

        // 캐시 미스: UserDefaults에서 로드
        guard let data = defaults.data(forKey: sessionsKey) else {
            cachedSessions = []
            rebuildIndexMap([])
            return []
        }

        let sessions = (try? JSONDecoder().decode([SessionRecord].self, from: data)) ?? []
        cachedSessions = sessions
        rebuildIndexMap(sessions)
        return sessions
    }

    /// 세션 목록 저장 (캐시 동기화)
    static func saveSessions(_ sessions: [SessionRecord]) {
        guard let data = try? JSONEncoder().encode(sessions) else {
            return
        }
        defaults.set(data, forKey: sessionsKey)

        // 캐시 업데이트
        cachedSessions = sessions
        rebuildIndexMap(sessions)

        notifySessionsUpdated()
    }

    /// 인덱스 맵 재구성 (O(1) 검색용)
    private static func rebuildIndexMap(_ sessions: [SessionRecord]) {
        sessionIndexMap.removeAll(keepingCapacity: true)
        for (index, session) in sessions.enumerated() {
            sessionIndexMap[session.id] = index
        }
    }

    /// 세션 인덱스 조회 (O(1))
    private static func index(for sessionId: String) -> Int? {
        // 캐시 로드 보장
        _ = loadSessions()
        return sessionIndexMap[sessionId]
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
        var projectName = cwd?
            .split(separator: "/")
            .last
            .map(String.init) ?? "Claude Session"

        let detail: String
        if let cwd, !cwd.isEmpty {
            detail = cwd
        } else {
            detail = "session: \(trimmedId)"
        }

        // 기존 세션이 있으면 사용자 설정 이름 보존 (O(1) 검색)
        var sessions = loadSessions()
        if let existingIndex = index(for: resolvedId), existingIndex < sessions.count {
            let existing = sessions[existingIndex]
            projectName = existing.name
            sessions.remove(at: existingIndex)
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
        status: SessionStatus,
        prompt: String? = nil,
        reorder: Bool = true,
        resetDuration: Bool = false
    ) {
        let trimmedId = sessionId?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !trimmedId.isEmpty else {
            return
        }

        var sessions = loadSessions()
        // O(1) 인덱스 조회
        guard let index = index(for: trimmedId), index < sessions.count else {
            return
        }

        // 기존 레코드 갱신
        let existing = sessions[index]
        let now = Date().timeIntervalSince1970
        let updatedPrompt = normalizedPrompt(prompt) ?? existing.lastPrompt
        let updatedResponse: String?
        let updatedStartedAt: TimeInterval?
        let updatedDuration: TimeInterval?

        if status == .running {
            // running: 시간 측정 시작/재개
            updatedResponse = nil
            if resetDuration {
                // UserPromptSubmit: 새 프롬프트 시작, duration 초기화
                updatedStartedAt = now
                updatedDuration = nil
            } else if existing.status == .running {
                // 이미 running: 유지
                updatedStartedAt = existing.startedAt
                updatedDuration = existing.duration
            } else {
                // permission/finished 등에서 재개: 기존 duration 유지
                updatedStartedAt = now
                updatedDuration = existing.duration
            }
        } else if status == .permission {
            // permission: 일시정지 (현재까지 시간 저장)
            updatedResponse = existing.lastResponse
            if let startedAt = existing.startedAt {
                let elapsed = now - startedAt
                updatedDuration = (existing.duration ?? 0) + elapsed
            } else {
                updatedDuration = existing.duration
            }
            updatedStartedAt = nil
        } else {
            // finished, ended 등 완료 상태
            updatedResponse = existing.lastResponse
            if let startedAt = existing.startedAt {
                let elapsed = now - startedAt
                updatedDuration = (existing.duration ?? 0) + elapsed
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
            // min 필요: remove 후 index가 배열 크기와 같아질 수 있음 (마지막 요소였던 경우)
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
        // O(1) 인덱스 조회
        guard let index = index(for: trimmedId), index < sessions.count else {
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

    /// 세션 라벨(이름) 업데이트
    /// - Parameters:
    ///   - sessionId: 세션 ID
    ///   - newLabel: 새 라벨 (빈 문자열이면 무시)
    static func updateSessionLabel(sessionId: String?, newLabel: String) {
        let trimmedId = sessionId?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let trimmedLabel = newLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedId.isEmpty, !trimmedLabel.isEmpty else {
            return
        }

        var sessions = loadSessions()
        // O(1) 인덱스 조회
        guard let index = index(for: trimmedId), index < sessions.count else {
            return
        }

        let existing = sessions[index]
        let updated = SessionRecord(
            id: existing.id,
            name: trimmedLabel,
            detail: existing.detail,
            location: existing.location,
            status: existing.status,
            updatedAt: existing.updatedAt,
            startedAt: existing.startedAt,
            duration: existing.duration,
            lastPrompt: existing.lastPrompt,
            lastResponse: existing.lastResponse
        )

        sessions[index] = updated
        saveSessions(sessions)
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

    /// 확인된 세션 ID 목록 로드 (캐시 우선)
    static func loadSeenSessionIds() -> Set<String> {
        // 캐시가 있으면 바로 반환
        if let cached = cachedSeenIds {
            return cached
        }

        guard let data = defaults.data(forKey: seenSessionsKey),
              let ids = try? JSONDecoder().decode(Set<String>.self, from: data) else {
            cachedSeenIds = []
            return []
        }
        cachedSeenIds = ids
        return ids
    }

    /// 확인된 세션 ID 목록 저장 (캐시 동기화)
    private static func saveSeenSessionIds(_ ids: Set<String>) {
        guard let data = try? JSONEncoder().encode(ids) else {
            return
        }
        defaults.set(data, forKey: seenSessionsKey)
        cachedSeenIds = ids
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
