import Foundation

struct SessionTranscript: Codable {
    let sessionId: String
    let entries: [TranscriptEntry]
    let archivedAt: TimeInterval
    let lastPrompt: String?
    let lastResponse: String?
}
