// MARK: - 파일 설명
// SessionUsageRecord: 세션별 토큰 사용량 기록
// - 세션 삭제 후에도 유지되는 통계 데이터
// - StatisticsStore에서 사용
// - 덮어쓰기 방식: totalUsage(세션 누적값)를 그대로 저장

import Foundation

/// 세션별 토큰 사용량 기록
struct SessionUsageRecord: Codable, Identifiable {
    let id: String              // sessionId
    let projectPath: String     // 그룹핑용 (cwd)
    let projectName: String     // 표시용 (디렉토리 이름)
    var inputTokens: Int
    var outputTokens: Int
    var cacheCreationTokens: Int
    var cacheReadTokens: Int
    let createdAt: Date         // 최초 기록 시점
    var lastUpdatedAt: Date     // 마지막 업데이트 시점

    /// 총 토큰 수
    /// 계산식: (inputTokens + cacheCreationTokens + cacheReadTokens) + outputTokens
    /// - 총 입력 = inputTokens + cacheCreationTokens + cacheReadTokens
    /// - 참고: .claude/docs/anthropic-token-usage.md
    var totalTokens: Int {
        inputTokens + cacheCreationTokens + cacheReadTokens + outputTokens
    }

    /// 기존 레코드를 새 사용량으로 덮어쓰기 (누적값 교체)
    /// - Parameter usage: 세션 전체 누적 토큰 사용량
    /// - Returns: 업데이트된 레코드
    func replaced(with usage: TokenUsage) -> SessionUsageRecord {
        var record = self
        record.inputTokens = usage.inputTokens
        record.outputTokens = usage.outputTokens
        record.cacheCreationTokens = usage.cacheCreationInputTokens ?? 0
        record.cacheReadTokens = usage.cacheReadInputTokens ?? 0
        record.lastUpdatedAt = Date()
        return record
    }

    /// 새 레코드 생성
    static func create(
        sessionId: String,
        projectPath: String,
        usage: TokenUsage
    ) -> SessionUsageRecord {
        let projectName = (projectPath as NSString).lastPathComponent
        let now = Date()
        return SessionUsageRecord(
            id: sessionId,
            projectPath: projectPath,
            projectName: projectName,
            inputTokens: usage.inputTokens,
            outputTokens: usage.outputTokens,
            cacheCreationTokens: usage.cacheCreationInputTokens ?? 0,
            cacheReadTokens: usage.cacheReadInputTokens ?? 0,
            createdAt: now,
            lastUpdatedAt: now
        )
    }
}

// MARK: - 일별+프로젝트별 사용량 집계

/// 일별+프로젝트별 토큰 사용량 집계
/// - 날짜별 통계 조회용
/// - 델타 누적 방식: 각 Stop 이벤트의 증분만 더함
struct DailyProjectUsage: Codable, Identifiable {
    var id: String { "\(date)|\(projectPath)" }
    let date: String            // "2026-01-18" 형식
    let projectPath: String
    let projectName: String
    var inputTokens: Int
    var outputTokens: Int
    var cacheCreationTokens: Int
    var cacheReadTokens: Int

    /// 총 토큰 수
    var totalTokens: Int {
        inputTokens + cacheCreationTokens + cacheReadTokens + outputTokens
    }

    /// 델타 추가
    mutating func addDelta(_ delta: TokenUsage) {
        inputTokens += delta.inputTokens
        outputTokens += delta.outputTokens
        cacheCreationTokens += delta.cacheCreationInputTokens ?? 0
        cacheReadTokens += delta.cacheReadInputTokens ?? 0
    }

    /// 새 레코드 생성
    static func create(
        date: String,
        projectPath: String,
        delta: TokenUsage
    ) -> DailyProjectUsage {
        let projectName = (projectPath as NSString).lastPathComponent
        return DailyProjectUsage(
            date: date,
            projectPath: projectPath,
            projectName: projectName,
            inputTokens: delta.inputTokens,
            outputTokens: delta.outputTokens,
            cacheCreationTokens: delta.cacheCreationInputTokens ?? 0,
            cacheReadTokens: delta.cacheReadInputTokens ?? 0
        )
    }
}

// MARK: - 세션별 마지막 기록 (델타 계산용)

/// 세션별 마지막 기록 토큰 (델타 계산용)
/// - 이전 totalUsage를 저장해서 다음 Stop 이벤트와의 차이를 계산
struct SessionLastUsage: Codable, Identifiable {
    var id: String { sessionId }
    let sessionId: String
    var inputTokens: Int
    var outputTokens: Int
    var cacheCreationTokens: Int
    var cacheReadTokens: Int

    /// TokenUsage와의 델타 계산
    func delta(from usage: TokenUsage) -> TokenUsage {
        TokenUsage(
            inputTokens: usage.inputTokens - inputTokens,
            outputTokens: usage.outputTokens - outputTokens,
            cacheCreationInputTokens: (usage.cacheCreationInputTokens ?? 0) - cacheCreationTokens,
            cacheReadInputTokens: (usage.cacheReadInputTokens ?? 0) - cacheReadTokens
        )
    }

    /// 현재 사용량으로 갱신
    static func from(sessionId: String, usage: TokenUsage) -> SessionLastUsage {
        SessionLastUsage(
            sessionId: sessionId,
            inputTokens: usage.inputTokens,
            outputTokens: usage.outputTokens,
            cacheCreationTokens: usage.cacheCreationInputTokens ?? 0,
            cacheReadTokens: usage.cacheReadInputTokens ?? 0
        )
    }
}

// MARK: - 통계 데이터 컨테이너

/// 전체 통계 데이터 컨테이너 (단일 파일 저장용)
struct StatisticsData: Codable {
    var sessions: [SessionUsageRecord]
    var daily: [DailyProjectUsage]
    var lastUsages: [SessionLastUsage]

    static func empty() -> StatisticsData {
        StatisticsData(sessions: [], daily: [], lastUsages: [])
    }
}
