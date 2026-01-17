import Foundation

/// API 요청의 토큰 사용량 정보
struct TokenUsage: Codable, Equatable {
    let inputTokens: Int
    let outputTokens: Int
    let cacheCreationInputTokens: Int?
    let cacheReadInputTokens: Int?

    /// 총 입력 토큰 (캐시 포함)
    /// 계산식: inputTokens + cacheCreationInputTokens + cacheReadInputTokens
    var totalInputTokens: Int {
        inputTokens + (cacheCreationInputTokens ?? 0) + (cacheReadInputTokens ?? 0)
    }

    /// 총 토큰 수
    /// 계산식: totalInputTokens + outputTokens
    var totalTokens: Int {
        totalInputTokens + outputTokens
    }

    /// 실제 토큰 사용량 (비용 기준)
    /// 계산식: Input×1 + CacheWrite×1.25 + CacheRead×0.1 + Output
    var actualTokenUsage: Double {
        Double(inputTokens) + Double(cacheCreationInputTokens ?? 0) * 1.25 + Double(cacheReadInputTokens ?? 0) * 0.1 + Double(outputTokens)
    }

    /// 포맷된 요약 문자열 (예: "1.2K · 850")
    /// - 왼쪽: 총 토큰, 오른쪽: 실제 사용량
    var formattedSummary: String {
        "\(Self.formatTokenCount(totalTokens)) · \(Self.formatTokenCount(Int(actualTokenUsage)))"
    }

    /// 토큰 수 포맷 (K 단위 변환)
    static func formatTokenCount(_ count: Int) -> String {
        if count >= 1000 {
            let value = Double(count) / 1000.0
            if value >= 10 {
                return String(format: "%.0fK", value)
            }
            return String(format: "%.1fK", value)
        }
        return "\(count)"
    }

    /// 다른 TokenUsage와 합산
    func adding(_ other: TokenUsage) -> TokenUsage {
        TokenUsage(
            inputTokens: inputTokens + other.inputTokens,
            outputTokens: outputTokens + other.outputTokens,
            cacheCreationInputTokens: (cacheCreationInputTokens ?? 0) + (other.cacheCreationInputTokens ?? 0),
            cacheReadInputTokens: (cacheReadInputTokens ?? 0) + (other.cacheReadInputTokens ?? 0)
        )
    }

    /// 빈 TokenUsage
    static let zero = TokenUsage(
        inputTokens: 0,
        outputTokens: 0,
        cacheCreationInputTokens: 0,
        cacheReadInputTokens: 0
    )
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
