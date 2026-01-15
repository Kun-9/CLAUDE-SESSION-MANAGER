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
    /// - Returns: 위치별로 그룹화된 섹션 배열 (즐겨찾기 우선, 입력 순서 보존)
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

        // 3. 즐겨찾기 목록 로드
        let favorites = loadFavoriteSections()

        // 4. 빈 즐겨찾기 섹션 추가 (세션이 없는 즐겨찾기 경로)
        for favPath in favorites.sorted() {
            if !order.contains(favPath) {
                order.insert(favPath, at: 0)
                grouped[favPath] = []
            }
        }

        // 5. 섹션 객체로 변환 (즐겨찾기 우선 정렬)
        let allSections = order.map { key -> SessionSection in
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

            return SessionSection(
                id: key,
                title: title,
                subtitle: subtitle,
                sessions: items,
                isFavorite: favorites.contains(key)
            )
        }

        // 6. 즐겨찾기 섹션을 상단으로 정렬
        let favoriteSections = allSections.filter { $0.isFavorite }
        let normalSections = allSections.filter { !$0.isFavorite }
        return favoriteSections + normalSections
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

    // MARK: - 즐겨찾기 관리

    /// 즐겨찾기 섹션 ID 로드
    /// - Returns: 즐겨찾기된 섹션 ID Set
    static func loadFavoriteSections() -> Set<String> {
        let json = SettingsStore.defaults.string(forKey: SettingsKeys.favoriteSections) ?? DefaultValue.emptyJSON
        guard let data = json.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([String].self, from: data) else {
            return []
        }
        return Set(decoded)
    }

    /// 즐겨찾기 섹션 ID 저장
    /// - Parameter ids: 즐겨찾기된 섹션 ID Set
    static func saveFavoriteSections(_ ids: Set<String>) {
        let sorted = ids.sorted()
        guard let data = try? JSONEncoder().encode(sorted),
              let encoded = String(data: data, encoding: .utf8) else {
            return
        }
        SettingsStore.defaults.set(encoded, forKey: SettingsKeys.favoriteSections)
    }

    /// 섹션 즐겨찾기 여부 확인
    /// - Parameter sectionId: 섹션 ID (경로)
    /// - Returns: 즐겨찾기 여부
    static func isFavorite(_ sectionId: String) -> Bool {
        loadFavoriteSections().contains(sectionId)
    }

    /// 섹션 즐겨찾기 토글
    /// - Parameter sectionId: 섹션 ID (경로)
    /// - Returns: 토글 후 즐겨찾기 상태
    @discardableResult
    static func toggleFavorite(_ sectionId: String) -> Bool {
        var favorites = loadFavoriteSections()
        if favorites.contains(sectionId) {
            favorites.remove(sectionId)
            saveFavoriteSections(favorites)
            return false
        } else {
            favorites.insert(sectionId)
            saveFavoriteSections(favorites)
            return true
        }
    }
}
