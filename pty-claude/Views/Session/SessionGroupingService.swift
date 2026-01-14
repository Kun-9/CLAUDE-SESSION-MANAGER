// MARK: - 파일 설명
// SessionGroupingService: 세션 목록 그룹핑 및 상태 직렬화
// - 세션을 위치(locationPath)별로 그룹화
// - 접힌 섹션 ID 목록의 JSON 직렬화/역직렬화

import Foundation

enum SessionGroupingService {
    // MARK: - Constants

    private enum DefaultValue {
        static let unknownKey = "unknown"
        static let unknownTitle = "Unknown Location"
        static let emptyJSON = "[]"
    }

    // MARK: - Public Methods

    /// 세션 목록을 위치별로 그룹핑
    /// - Parameter sessions: 그룹핑할 세션 목록
    /// - Returns: 위치별로 그룹화된 섹션 배열 (입력 순서 보존)
    static func groupByLocation(_ sessions: [SessionItem]) -> [SessionSection] {
        // 1. 순서 보존을 위한 키 배열과 그룹 딕셔너리
        var order: [String] = []
        var grouped: [String: [SessionItem]] = [:]

        // 2. 세션을 위치별로 분류
        for session in sessions {
            let key = session.locationPath ?? DefaultValue.unknownKey
            if grouped[key] == nil {
                grouped[key] = []
                order.append(key)
            }
            grouped[key]?.append(session)
        }

        // 3. 섹션 객체로 변환
        return order.map { key in
            let items = grouped[key] ?? []
            let title: String
            let subtitle: String?

            if key == DefaultValue.unknownKey {
                title = DefaultValue.unknownTitle
                subtitle = nil
            } else {
                title = (key as NSString).lastPathComponent
                subtitle = key
            }

            return SessionSection(id: key, title: title, subtitle: subtitle, sessions: items)
        }
    }

    /// 접힌 섹션 ID JSON 역직렬화
    /// - Parameter json: JSON 문자열 (예: `["path1", "path2"]`)
    /// - Returns: 섹션 ID Set, 파싱 실패 시 빈 Set
    static func decodeCollapsedSections(_ json: String) -> Set<String> {
        guard let data = json.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([String].self, from: data) else {
            return []
        }
        return Set(decoded)
    }

    /// 접힌 섹션 ID JSON 직렬화
    /// - Parameter ids: 섹션 ID Set
    /// - Returns: 정렬된 JSON 배열 문자열
    static func encodeCollapsedSections(_ ids: Set<String>) -> String {
        let sorted = ids.sorted()
        guard let data = try? JSONEncoder().encode(sorted),
              let encoded = String(data: data, encoding: .utf8) else {
            return DefaultValue.emptyJSON
        }
        return encoded
    }
}
