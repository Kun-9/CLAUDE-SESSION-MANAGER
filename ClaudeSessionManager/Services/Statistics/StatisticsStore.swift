// MARK: - 파일 설명
// StatisticsStore: 통계 데이터 영속화 저장소
// - 세션별 총합 (덮어쓰기), 일별+프로젝트별 집계 (델타 누적)
// - ~/Library/Application Support/ClaudeSessionManager/statistics.json
// - 참고: .claude/doc-local.md

import Foundation

enum StatisticsStore {
    private static let statisticsFileName = "statistics.json"
    private static let appFolderName = "ClaudeSessionManager"

    // MARK: - 날짜 포맷터

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone.current
        return formatter
    }()

    // MARK: - Public Methods

    /// 세션 토큰 사용량 기록
    /// - Parameters:
    ///   - sessionId: 세션 ID
    ///   - projectPath: 프로젝트 경로 (cwd)
    ///   - usage: 세션 전체 누적 토큰 사용량 (transcript.totalUsage)
    static func record(sessionId: String, projectPath: String, usage: TokenUsage) {
        var data = load()
        let today = dateFormatter.string(from: Date())

        // Step 1: 세션 레코드 업데이트 (덮어쓰기)
        updateSessionRecord(&data, sessionId: sessionId, projectPath: projectPath, usage: usage)

        // Step 2: 델타 계산
        let delta = calculateDelta(&data, sessionId: sessionId, usage: usage)

        // Step 3: 일별+프로젝트별 레코드 업데이트 (델타 누적)
        updateDailyRecord(&data, date: today, projectPath: projectPath, delta: delta)

        // Step 4: 저장
        save(data)
    }

    /// 모든 세션 통계 레코드 로드
    static func loadAllSessions() -> [SessionUsageRecord] {
        load().sessions
    }

    /// 모든 일별 통계 레코드 로드
    static func loadAllDaily() -> [DailyProjectUsage] {
        load().daily
    }

    /// 특정 세션의 통계 레코드 로드
    static func loadSession(sessionId: String) -> SessionUsageRecord? {
        load().sessions.first { $0.id == sessionId }
    }

    /// 특정 날짜의 통계 레코드 로드
    static func loadDaily(date: String) -> [DailyProjectUsage] {
        load().daily.filter { $0.date == date }
    }

    /// 특정 프로젝트의 일별 통계 로드
    static func loadDaily(projectPath: String) -> [DailyProjectUsage] {
        load().daily.filter { $0.projectPath == projectPath }
    }

    /// 특정 세션의 통계 레코드 삭제
    static func deleteSession(sessionId: String) {
        var data = load()
        data.sessions.removeAll { $0.id == sessionId }
        data.lastUsages.removeAll { $0.sessionId == sessionId }
        save(data)
    }

    /// 모든 통계 레코드 삭제
    static func deleteAll() {
        let url = statisticsFileURL()
        try? FileManager.default.removeItem(at: url)
    }

    // MARK: - Private Methods

    /// 전체 통계 데이터 로드
    private static func load() -> StatisticsData {
        let url = statisticsFileURL()
        guard FileManager.default.fileExists(atPath: url.path) else {
            return .empty()
        }
        guard let data = try? Data(contentsOf: url) else {
            return .empty()
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode(StatisticsData.self, from: data)) ?? .empty()
    }

    /// 세션 레코드 업데이트 (덮어쓰기)
    private static func updateSessionRecord(
        _ data: inout StatisticsData,
        sessionId: String,
        projectPath: String,
        usage: TokenUsage
    ) {
        if let index = data.sessions.firstIndex(where: { $0.id == sessionId }) {
            // 기존 레코드 덮어쓰기
            data.sessions[index] = data.sessions[index].replaced(with: usage)
        } else {
            // 새 레코드 생성
            let newRecord = SessionUsageRecord.create(
                sessionId: sessionId,
                projectPath: projectPath,
                usage: usage
            )
            data.sessions.append(newRecord)
        }
    }

    /// 델타 계산 및 lastUsage 갱신
    private static func calculateDelta(
        _ data: inout StatisticsData,
        sessionId: String,
        usage: TokenUsage
    ) -> TokenUsage {
        let delta: TokenUsage

        if let index = data.lastUsages.firstIndex(where: { $0.sessionId == sessionId }) {
            // 이전 기록과의 차이 계산
            delta = data.lastUsages[index].delta(from: usage)
            // lastUsage 갱신
            data.lastUsages[index] = SessionLastUsage.from(sessionId: sessionId, usage: usage)
        } else {
            // 첫 기록: 전체가 델타
            delta = usage
            data.lastUsages.append(SessionLastUsage.from(sessionId: sessionId, usage: usage))
        }

        return delta
    }

    /// 일별+프로젝트별 레코드 업데이트 (델타 누적)
    private static func updateDailyRecord(
        _ data: inout StatisticsData,
        date: String,
        projectPath: String,
        delta: TokenUsage
    ) {
        let key = "\(date)|\(projectPath)"

        if let index = data.daily.firstIndex(where: { $0.id == key }) {
            // 기존 레코드에 델타 추가
            data.daily[index].addDelta(delta)
        } else {
            // 새 레코드 생성
            let newRecord = DailyProjectUsage.create(
                date: date,
                projectPath: projectPath,
                delta: delta
            )
            data.daily.append(newRecord)
        }
    }

    /// 전체 통계 데이터 저장
    private static func save(_ data: StatisticsData) {
        let url = statisticsFileURL()
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let encoded = try encoder.encode(data)
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try encoded.write(to: url, options: .atomic)
        } catch {
            return
        }
    }

    private static func statisticsFileURL() -> URL {
        let base = applicationSupportURL()
        return base.appendingPathComponent(statisticsFileName)
    }

    private static func applicationSupportURL() -> URL {
        let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first ?? FileManager.default.homeDirectoryForCurrentUser
        return root.appendingPathComponent(appFolderName, isDirectory: true)
    }
}
