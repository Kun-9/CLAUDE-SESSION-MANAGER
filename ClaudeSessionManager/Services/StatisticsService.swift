// MARK: - 파일 설명
// StatisticsService: 토큰 사용량 통계 계산
// - 세션별/프로젝트별 토큰 집계
// - StatisticsStore에서 데이터 로드 (세션 삭제 후에도 유지)

import Foundation

enum StatisticsService {
    /// 전체 통계 계산
    /// StatisticsStore에서 영속화된 데이터를 사용하여 세션 삭제 후에도 통계 유지
    static func calculateStatistics() -> (total: TotalStatistics, projects: [ProjectUsage]) {
        let records = StatisticsStore.loadAllSessions()

        var projectMap: [String: (name: String, sessions: [String], input: Int, output: Int, cacheCreation: Int, cacheRead: Int)] = [:]
        var totalInput = 0
        var totalOutput = 0
        var totalCacheCreation = 0
        var totalCacheRead = 0

        for record in records {
            totalInput += record.inputTokens
            totalOutput += record.outputTokens
            totalCacheCreation += record.cacheCreationTokens
            totalCacheRead += record.cacheReadTokens

            // 프로젝트별 집계
            let projectKey = record.projectPath
            var existing = projectMap[projectKey] ?? (name: record.projectName, sessions: [], input: 0, output: 0, cacheCreation: 0, cacheRead: 0)
            existing.sessions.append(record.id)
            existing.input += record.inputTokens
            existing.output += record.outputTokens
            existing.cacheCreation += record.cacheCreationTokens
            existing.cacheRead += record.cacheReadTokens
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
                cacheCreation: value.cacheCreation,
                cacheRead: value.cacheRead
            )
        }.sorted { $0.totalTokens > $1.totalTokens }

        let total = TotalStatistics(
            totalSessions: records.count,
            totalProjects: projectMap.count,
            totalInput: totalInput,
            totalOutput: totalOutput,
            cacheCreation: totalCacheCreation,
            cacheRead: totalCacheRead
        )

        return (total, projects)
    }
}
