import Foundation

struct SessionTranscript: Codable {
    let sessionId: String
    let entries: [TranscriptEntry]
    let archivedAt: TimeInterval
    let lastPrompt: String?
    let lastResponse: String?

    /// 세션 전체 토큰 사용량 합산 (requestId 기준 중복 제거)
    var totalUsage: TokenUsage? {
        var seenRequestIds = Set<String>()
        var uniqueUsages: [TokenUsage] = []

        for entry in entries {
            guard let usage = entry.usage else { continue }

            if let requestId = entry.requestId {
                if seenRequestIds.contains(requestId) { continue }
                seenRequestIds.insert(requestId)
            }
            uniqueUsages.append(usage)
        }

        guard !uniqueUsages.isEmpty else { return nil }

        let totalInput = uniqueUsages.reduce(0) { $0 + $1.inputTokens }
        let totalOutput = uniqueUsages.reduce(0) { $0 + $1.outputTokens }
        let totalCacheCreation = uniqueUsages.reduce(0) { $0 + ($1.cacheCreationInputTokens ?? 0) }
        let totalCacheRead = uniqueUsages.reduce(0) { $0 + ($1.cacheReadInputTokens ?? 0) }

        return TokenUsage(
            inputTokens: totalInput,
            outputTokens: totalOutput,
            cacheCreationInputTokens: totalCacheCreation > 0 ? totalCacheCreation : nil,
            cacheReadInputTokens: totalCacheRead > 0 ? totalCacheRead : nil
        )
    }
}
