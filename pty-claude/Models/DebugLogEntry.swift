import Foundation

struct DebugLogEntry: Identifiable, Codable {
    let id: UUID
    let timestamp: TimeInterval
    let hookName: String
    let toolName: String?
    let sessionId: String?
    let cwd: String?
    let transcriptPath: String?
    let prompt: String?
    let rawPayload: String

    init(
        id: UUID = UUID(),
        timestamp: TimeInterval,
        hookName: String,
        toolName: String?,
        sessionId: String?,
        cwd: String?,
        transcriptPath: String?,
        prompt: String?,
        rawPayload: String
    ) {
        self.id = id
        self.timestamp = timestamp
        self.hookName = hookName
        self.toolName = toolName
        self.sessionId = sessionId
        self.cwd = cwd
        self.transcriptPath = transcriptPath
        self.prompt = prompt
        self.rawPayload = rawPayload
    }
}
