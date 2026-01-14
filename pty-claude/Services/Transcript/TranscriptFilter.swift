import Foundation

enum TranscriptFilter {
    static func filteredEntries(_ entries: [TranscriptEntry], showFullTranscript: Bool) -> [TranscriptEntry] {
        if showFullTranscript {
            return entries
        }
        return entries.filter { isDirectUserInput($0) }
    }

    static func isDirectUserInput(_ entry: TranscriptEntry) -> Bool {
        if entry.role == .assistant {
            return true
        }
        if let entryType = entry.entryType?.lowercased(),
           let messageRole = entry.messageRole?.lowercased() {
            guard entryType == "user", messageRole == "user" else {
                return false
            }
            if entry.isMeta == true {
                return false
            }
            if entry.messageContentIsString != true {
                return false
            }
        } else if entry.role != .user {
            return false
        }

        let content = entry.text
        let systemTags = [
            "<command-name>", "<command-message>", "<command-args>",
            "<local-command-stdout>", "<local-command-stderr>",
            "<local-command-caveat>", "<system-reminder>",
            "<function_results>", "tool_use_id", "tool_result",
        ]
        return !systemTags.contains(where: { content.contains($0) })
    }
}
