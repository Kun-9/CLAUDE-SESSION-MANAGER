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
    let cacheCreation: Int
    let cacheRead: Int

    /// 총 입력 토큰 수
    /// 계산식: totalInput + cacheCreation + cacheRead
    var totalInputTokens: Int {
        totalInput + cacheCreation + cacheRead
    }

    /// 총 토큰 수
    /// 계산식: totalInputTokens + totalOutput
    /// - 참고: .claude/docs/anthropic-token-usage.md
    var totalTokens: Int {
        totalInputTokens + totalOutput
    }

    /// 실제 토큰 사용량 (비용 기준)
    /// 계산식: Input×1 + CacheWrite×1.25 + CacheRead×0.1 + Output
    var actualTokenUsage: Double {
        Double(totalInput) + Double(cacheCreation) * 1.25 + Double(cacheRead) * 0.1 + Double(totalOutput)
    }

    /// 포맷된 총 입력
    var formattedTotalInput: String { formatTokenCount(totalInputTokens) }

    /// 포맷된 총 토큰
    var formattedTotal: String { formatTokenCount(totalTokens) }

    /// 포맷된 실제 사용량
    var formattedActualUsage: String { formatTokenCount(Int(actualTokenUsage)) }

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

    /// 총 입력 토큰 수
    /// 계산식: totalInput + cacheCreation + cacheRead
    /// - 참고: .claude/docs/anthropic-token-usage.md
    var totalInputTokens: Int {
        totalInput + cacheCreation + cacheRead
    }

    /// 총 토큰 수
    /// 계산식: totalInputTokens + totalOutput
    var totalTokens: Int {
        totalInputTokens + totalOutput
    }

    /// 실제 토큰 사용량 (비용 기준)
    /// 계산식: Input×1 + CacheWrite×1.25 + CacheRead×0.1 + Output
    /// - 참고: .claude/docs/anthropic-token-usage.md
    var actualTokenUsage: Double {
        Double(totalInput) + Double(cacheCreation) * 1.25 + Double(cacheRead) * 0.1 + Double(totalOutput)
    }

    /// 캐시 비용 절감률 (비용 기반)
    /// - 일반 입력: 1x, Cache Write: 1.25x, Cache Read: 0.1x
    /// - 절감률 = (기본비용 - 실제비용) / 기본비용 × 100
    var cacheSavingsRate: Double {
        let baseCost = Double(totalInputTokens)
        guard baseCost > 0 else { return 0 }
        let actualInputCost = Double(totalInput) + Double(cacheCreation) * 1.25 + Double(cacheRead) * 0.1
        let savings = baseCost - actualInputCost
        return savings / baseCost * 100
    }

    var formattedCacheSavingsRate: String { String(format: "%.1f%%", cacheSavingsRate) }
    var formattedTotalInput: String { formatLargeTokenCount(totalInputTokens) }
    var formattedActualUsage: String { formatLargeTokenCount(Int(actualTokenUsage)) }
    var formattedTotal: String { formatLargeTokenCount(totalTokens) }
    var formattedInput: String { formatLargeTokenCount(totalInput) }
    var formattedOutput: String { formatLargeTokenCount(totalOutput) }
    var formattedCacheRead: String { formatLargeTokenCount(cacheRead) }
    var formattedCacheCreation: String { formatLargeTokenCount(cacheCreation) }

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
