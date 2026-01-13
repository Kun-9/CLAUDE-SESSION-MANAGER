import Foundation

struct TranscriptEntry: Identifiable, Codable {
    let id: UUID
    let role: TranscriptRole
    let text: String
    let createdAt: TimeInterval?

    init(id: UUID = UUID(), role: TranscriptRole, text: String, createdAt: TimeInterval? = nil) {
        self.id = id
        self.role = role
        self.text = text
        self.createdAt = createdAt
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
