// MARK: - 파일 설명
// StatisticsModels: 통계 화면에서 사용하는 데이터 모델
// - ProjectUsage: 프로젝트별 토큰 사용량
// - TotalStatistics: 전체 합산 토큰 사용량

import Foundation

/// 프로젝트별 토큰 사용량
struct ProjectUsage: Identifiable {
    let id: String  // location path
    let name: String  // 디렉토리 이름
    let sessionCount: Int
    let totalInput: Int
    let totalOutput: Int
    let cacheRead: Int

    /// 총 토큰 (input + output)
    var totalTokens: Int { totalInput + totalOutput }

    /// 포맷된 총 토큰
    var formattedTotal: String { formatTokenCount(totalTokens) }

    private func formatTokenCount(_ count: Int) -> String {
        if count >= 1_000_000 {
            return String(format: "%.1fM", Double(count) / 1_000_000.0)
        }
        if count >= 1000 {
            let value = Double(count) / 1000.0
            return value >= 10 ? String(format: "%.0fK", value) : String(format: "%.1fK", value)
        }
        return "\(count)"
    }
}

/// 전체 합산 통계
struct TotalStatistics {
    let totalSessions: Int
    let totalProjects: Int
    let totalInput: Int
    let totalOutput: Int
    let cacheCreation: Int
    let cacheRead: Int

    var totalTokens: Int { totalInput + totalOutput }

    /// 캐시 효율 (캐시 읽기 / 총 입력)
    var cacheHitRate: Double {
        let total = totalInput + cacheRead
        guard total > 0 else { return 0 }
        return Double(cacheRead) / Double(total) * 100
    }

    var formattedCacheHitRate: String { String(format: "%.1f%%", cacheHitRate) }
    var formattedTotal: String { formatLargeTokenCount(totalTokens) }
    var formattedInput: String { formatLargeTokenCount(totalInput) }
    var formattedOutput: String { formatLargeTokenCount(totalOutput) }
    var formattedCacheRead: String { formatLargeTokenCount(cacheRead) }

    private func formatLargeTokenCount(_ count: Int) -> String {
        if count >= 1_000_000 {
            return String(format: "%.2fM", Double(count) / 1_000_000.0)
        }
        if count >= 1000 {
            return String(format: "%.1fK", Double(count) / 1000.0)
        }
        return "\(count)"
    }

    static let empty = TotalStatistics(
        totalSessions: 0, totalProjects: 0,
        totalInput: 0, totalOutput: 0,
        cacheCreation: 0, cacheRead: 0
    )
}
