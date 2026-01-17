// MARK: - 파일 설명
// StatisticsService: 토큰 사용량 통계 계산
// - 세션별/프로젝트별 토큰 집계
// - TranscriptArchiveStore에서 데이터 로드

import Foundation

enum StatisticsService {
    /// 전체 통계 계산
    static func calculateStatistics() -> (total: TotalStatistics, projects: [ProjectUsage]) {
        let sessions = SessionStore.loadSessions()

        var projectMap: [String: (name: String, sessions: [String], input: Int, output: Int, cacheCreation: Int, cacheRead: Int)] = [:]
        var totalInput = 0
        var totalOutput = 0
        var totalCacheCreation = 0
        var totalCacheRead = 0
        var sessionCount = 0

        for session in sessions {
            guard let transcript = TranscriptArchiveStore.load(sessionId: session.id),
                  let usage = transcript.totalUsage else {
                continue
            }

            sessionCount += 1
            totalInput += usage.inputTokens
            totalOutput += usage.outputTokens
            totalCacheCreation += usage.cacheCreationInputTokens ?? 0
            totalCacheRead += usage.cacheReadInputTokens ?? 0

            // 프로젝트별 집계
            let projectKey = session.location ?? "Unknown"
            let projectName = (projectKey as NSString).lastPathComponent
            var existing = projectMap[projectKey] ?? (name: projectName, sessions: [], input: 0, output: 0, cacheCreation: 0, cacheRead: 0)
            existing.sessions.append(session.id)
            existing.input += usage.inputTokens
            existing.output += usage.outputTokens
            existing.cacheCreation += usage.cacheCreationInputTokens ?? 0
            existing.cacheRead += usage.cacheReadInputTokens ?? 0
            projectMap[projectKey] = existing
        }

        // 프로젝트 목록 생성 (토큰 사용량 내림차순 정렬)
        let projects = projectMap.map { key, value in
            ProjectUsage(
                id: key,
                name: value.name,
                sessionCount: value.sessions.count,
                totalInput: value.input,
                totalOutput: value.output,
                cacheRead: value.cacheRead
            )
        }.sorted { $0.totalTokens > $1.totalTokens }

        let total = TotalStatistics(
            totalSessions: sessionCount,
            totalProjects: projectMap.count,
            totalInput: totalInput,
            totalOutput: totalOutput,
            cacheCreation: totalCacheCreation,
            cacheRead: totalCacheRead
        )

        return (total, projects)
    }
}
