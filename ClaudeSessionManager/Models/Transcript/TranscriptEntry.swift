import Foundation

/// API 요청의 토큰 사용량 정보
struct TokenUsage: Codable, Equatable {
    let inputTokens: Int
    let outputTokens: Int
    let cacheCreationInputTokens: Int?
    let cacheReadInputTokens: Int?

    /// 총 입력 토큰 (캐시 포함)
    var totalInputTokens: Int {
        inputTokens + (cacheCreationInputTokens ?? 0) + (cacheReadInputTokens ?? 0)
    }

    /// 포맷된 요약 문자열 (예: "↓1.2K ↑350 💾5K")
    var formattedSummary: String {
        var parts: [String] = []
        parts.append("↓\(formatTokenCount(totalInputTokens))")
        parts.append("↑\(formatTokenCount(outputTokens))")
        if let cacheRead = cacheReadInputTokens, cacheRead > 0 {
            parts.append("💾\(formatTokenCount(cacheRead))")
        }
        return parts.joined(separator: " ")
    }

    private func formatTokenCount(_ count: Int) -> String {
        if count >= 1000 {
            let value = Double(count) / 1000.0
            if value >= 10 {
                return String(format: "%.0fK", value)
            }
            return String(format: "%.1fK", value)
        }
        return "\(count)"
    }
}

struct TranscriptEntry: Identifiable, Codable {
    let id: UUID
    let role: TranscriptRole
    let text: String
    let createdAt: TimeInterval?
    let entryType: String?
    let messageRole: String?
    let isMeta: Bool?
    let messageContentIsString: Bool?
    /// API 요청 ID (같은 요청의 스트리밍 응답 구분용)
    let requestId: String?
    /// API 요청의 토큰 사용량 (Assistant 메시지에만 존재)
    let usage: TokenUsage?

    init(
        id: UUID = UUID(),
        role: TranscriptRole,
        text: String,
        createdAt: TimeInterval? = nil,
        entryType: String? = nil,
        messageRole: String? = nil,
        isMeta: Bool? = nil,
        messageContentIsString: Bool? = nil,
        requestId: String? = nil,
        usage: TokenUsage? = nil
    ) {
        self.id = id
        self.role = role
        self.text = text
        self.createdAt = createdAt
        self.entryType = entryType
        self.messageRole = messageRole
        self.isMeta = isMeta
        self.messageContentIsString = messageContentIsString
        self.requestId = requestId
        self.usage = usage
    }
}

enum TranscriptRole: String, Codable {
    case user
    case assistant
    case system
    case unknown

    init(rawValue: String?) {
        guard let value = rawValue?.lowercased() else {
            self = .unknown
            return
        }
        switch value {
        case "user":
            self = .user
        case "assistant":
            self = .assistant
        case "system":
            self = .system
        default:
            self = .unknown
        }
    }
}
