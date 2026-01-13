import Foundation

enum TranscriptArchiveService {
    struct Summary {
        let lastPrompt: String?
        let lastResponse: String?
    }

    static func archiveTranscript(sessionId: String?, transcriptPath: String?) -> Summary? {
        let trimmedId = sessionId?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !trimmedId.isEmpty else {
            return nil
        }
        guard let transcriptPath, !transcriptPath.isEmpty else {
            return nil
        }

        let expandedPath = (transcriptPath as NSString).expandingTildeInPath
        guard FileManager.default.fileExists(atPath: expandedPath) else {
            return nil
        }

        guard let entries = parseTranscript(at: expandedPath), !entries.isEmpty else {
            return nil
        }

        let summary = buildSummary(from: entries)
        let transcript = SessionTranscript(
            sessionId: trimmedId,
            entries: entries,
            archivedAt: Date().timeIntervalSince1970,
            lastPrompt: summary.lastPrompt,
            lastResponse: summary.lastResponse
        )
        TranscriptArchiveStore.save(transcript)
        return summary
    }

    private static func parseTranscript(at path: String) -> [TranscriptEntry]? {
        guard let content = try? String(contentsOfFile: path, encoding: .utf8) else {
            return nil
        }

        var entries: [TranscriptEntry] = []
        content.enumerateLines { line, _ in
            guard let data = line.data(using: .utf8) else {
                return
            }
            guard let object = try? JSONSerialization.jsonObject(with: data) else {
                return
            }
            guard let entry = buildEntry(from: object) else {
                return
            }
            entries.append(entry)
        }

        return entries
    }

    private static func buildEntry(from object: Any) -> TranscriptEntry? {
        guard let dict = object as? [String: Any] else {
            return nil
        }

        let roleValue = stringValue(dict["role"])
            ?? stringValue(dict["type"])
            ?? stringValue((dict["message"] as? [String: Any])?["role"])
        let role = TranscriptRole(rawValue: roleValue)
        let text = extractText(from: dict)

        guard let text, !text.isEmpty else {
            return nil
        }

        let createdAt = numberValue(dict["created_at"]) ?? numberValue(dict["timestamp"])
        return TranscriptEntry(role: role, text: text, createdAt: createdAt)
    }

    private static func extractText(from dict: [String: Any]) -> String? {
        if let content = stringValue(dict["content"]) {
            return content
        }
        if let text = stringValue(dict["text"]) {
            return text
        }
        if let message = dict["message"] as? [String: Any] {
            if let content = stringValue(message["content"]) {
                return content
            }
            if let text = stringValue(message["text"]) {
                return text
            }
            if let content = message["content"] as? [Any] {
                return joinContentBlocks(content)
            }
        }
        if let content = dict["content"] as? [Any] {
            return joinContentBlocks(content)
        }
        return nil
    }

    private static func joinContentBlocks(_ content: [Any]) -> String? {
        let parts = content.compactMap { item -> String? in
            if let text = stringValue(item as Any) {
                return text
            }
            if let dict = item as? [String: Any] {
                return stringValue(dict["text"]) ?? stringValue(dict["content"])
            }
            return nil
        }
        let joined = parts.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        return joined.isEmpty ? nil : joined
    }

    private static func stringValue(_ value: Any?) -> String? {
        if let string = value as? String {
            let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
        return nil
    }

    private static func numberValue(_ value: Any?) -> TimeInterval? {
        if let number = value as? NSNumber {
            return number.doubleValue
        }
        if let string = value as? String, let number = Double(string) {
            return number
        }
        return nil
    }

    private static func buildSummary(from entries: [TranscriptEntry]) -> Summary {
        let lastPrompt = entries.last(where: { $0.role == .user })?.text
        let lastResponse = entries.last(where: { $0.role == .assistant })?.text
        return Summary(
            lastPrompt: lastPrompt,
            lastResponse: lastResponse
        )
    }
}
