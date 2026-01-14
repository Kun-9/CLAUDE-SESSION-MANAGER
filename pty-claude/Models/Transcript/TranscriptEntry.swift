import Foundation

struct TranscriptEntry: Identifiable, Codable {
    let id: UUID
    let role: TranscriptRole
    let text: String
    let createdAt: TimeInterval?
    let entryType: String?
    let messageRole: String?
    let isMeta: Bool?
    let messageContentIsString: Bool?

    init(
        id: UUID = UUID(),
        role: TranscriptRole,
        text: String,
        createdAt: TimeInterval? = nil,
        entryType: String? = nil,
        messageRole: String? = nil,
        isMeta: Bool? = nil,
        messageContentIsString: Bool? = nil
    ) {
        self.id = id
        self.role = role
        self.text = text
        self.createdAt = createdAt
        self.entryType = entryType
        self.messageRole = messageRole
        self.isMeta = isMeta
        self.messageContentIsString = messageContentIsString
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
