import Foundation

enum TranscriptArchiveService {
    // 아카이브 요약 정보
    struct Summary {
        let lastPrompt: String?
        let lastResponse: String?
    }

    // 훅에서 전달된 transcript_path를 읽어 세션 단위로 아카이빙
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
        let mergedEntries = mergeWithExisting(sessionId: trimmedId, newEntries: entries)
        let mergedSummary = buildSummary(from: mergedEntries)
        let transcript = SessionTranscript(
            sessionId: trimmedId,
            entries: mergedEntries,
            archivedAt: Date().timeIntervalSince1970,
            lastPrompt: mergedSummary.lastPrompt,
            lastResponse: mergedSummary.lastResponse
        )
        TranscriptArchiveStore.save(transcript)
        return mergedSummary
    }

    // JSONL 파일을 파싱해 엔트리 목록 생성
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

    // JSON 객체를 TranscriptEntry로 변환
    private static func buildEntry(from object: Any) -> TranscriptEntry? {
        guard let dict = object as? [String: Any] else {
            return nil
        }

        let entryType = stringValue(dict["type"])
        let messageRole = stringValue((dict["message"] as? [String: Any])?["role"])
        let roleValue = stringValue(dict["role"])
            ?? entryType
            ?? messageRole
        let role = TranscriptRole(rawValue: roleValue)
        let text = extractText(from: dict)

        guard let text, !text.isEmpty else {
            return nil
        }

        let createdAt = timestampValue(dict["created_at"])
            ?? timestampValue(dict["timestamp"])
        let isMeta = dict["isMeta"] as? Bool
        let messageContentIsString = (dict["message"] as? [String: Any])?["content"] is String
        return TranscriptEntry(
            role: role,
            text: text,
            createdAt: createdAt,
            entryType: entryType,
            messageRole: messageRole,
            isMeta: isMeta,
            messageContentIsString: messageContentIsString
        )
    }

    // 다양한 포맷에서 텍스트 추출
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

    // 배열 형태의 content를 하나의 문장으로 합치기
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

    // 문자열 값 정규화
    private static func stringValue(_ value: Any?) -> String? {
        if let string = value as? String {
            let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
        return nil
    }

    // 숫자 기반 타임스탬프 파싱
    private static func numberValue(_ value: Any?) -> TimeInterval? {
        if let number = value as? NSNumber {
            return number.doubleValue
        }
        if let string = value as? String, let number = Double(string) {
            return number
        }
        return nil
    }

    // ISO 8601 문자열까지 포함한 타임스탬프 파싱
    private static func timestampValue(_ value: Any?) -> TimeInterval? {
        if let number = numberValue(value) {
            return number
        }
        guard let text = stringValue(value) else {
            return nil
        }
        guard let date = parseISODate(text) else {
            return nil
        }
        return date.timeIntervalSince1970
    }

    // ISO 8601 포맷 날짜 파싱
    private static func parseISODate(_ value: String) -> Date? {
        if let date = isoFormatterWithFractional.date(from: value) {
            return date
        }
        return isoFormatter.date(from: value)
    }

    // 소수점 초 포함 ISO 8601 포맷터
    private static let isoFormatterWithFractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    // 일반 ISO 8601 포맷터
    private static let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    // 세션 요약 생성
    private static func buildSummary(from entries: [TranscriptEntry]) -> Summary {
        let lastPrompt = entries.last(where: { $0.role == .user })?.text
        let lastResponse = entries.last(where: { $0.role == .assistant })?.text
        return Summary(
            lastPrompt: lastPrompt,
            lastResponse: lastResponse
        )
    }

    private static func mergeWithExisting(sessionId: String, newEntries: [TranscriptEntry]) -> [TranscriptEntry] {
        guard let existing = TranscriptArchiveStore.load(sessionId: sessionId) else {
            return newEntries
        }

        var seen = Set<String>()
        func key(for entry: TranscriptEntry) -> String {
            let timestamp = entry.createdAt.map { String($0) } ?? "nil"
            return "\(entry.role.rawValue)|\(timestamp)|\(entry.text)"
        }

        let combined = existing.entries + newEntries
        var merged: [TranscriptEntry] = []
        merged.reserveCapacity(combined.count)
        for entry in combined {
            let entryKey = key(for: entry)
            if seen.insert(entryKey).inserted {
                merged.append(entry)
            }
        }

        return merged.sorted { (lhs, rhs) in
            let left = lhs.createdAt ?? 0
            let right = rhs.createdAt ?? 0
            if left == right {
                return lhs.id.uuidString < rhs.id.uuidString
            }
            return left < right
        }
    }
}
