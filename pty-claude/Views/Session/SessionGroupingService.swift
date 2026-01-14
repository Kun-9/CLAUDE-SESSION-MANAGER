import Foundation

enum SessionGroupingService {
    /// 세션 목록을 위치별로 그룹핑
    static func groupByLocation(_ sessions: [SessionItem]) -> [SessionSection] {
        var order: [String] = []
        var grouped: [String: [SessionItem]] = [:]
        for session in sessions {
            let key = session.locationPath ?? "unknown"
            if grouped[key] == nil {
                grouped[key] = []
                order.append(key)
            }
            grouped[key]?.append(session)
        }

        return order.map { key in
            let items = grouped[key] ?? []
            let title: String
            let subtitle: String?
            if key == "unknown" {
                title = "Unknown Location"
                subtitle = nil
            } else {
                title = (key as NSString).lastPathComponent
                subtitle = key
            }
            return SessionSection(id: key, title: title, subtitle: subtitle, sessions: items)
        }
    }

    /// 접힌 섹션 ID JSON 역직렬화
    static func decodeCollapsedSections(_ json: String) -> Set<String> {
        guard let data = json.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([String].self, from: data) else {
            return []
        }
        return Set(decoded)
    }

    /// 접힌 섹션 ID JSON 직렬화
    static func encodeCollapsedSections(_ ids: Set<String>) -> String {
        let sorted = ids.sorted()
        guard let data = try? JSONEncoder().encode(sorted),
              let encoded = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return encoded
    }
}
