// MARK: - 파일 설명
// SidebarTab: 사이드바 탭 정의
// - 세션, 통계 등 메인 탭 열거

import Foundation

/// 사이드바 탭 열거형
enum SidebarTab: String, CaseIterable, Identifiable {
    case sessions = "세션"
    case statistics = "통계"

    var id: String { rawValue }

    /// SF Symbol 아이콘 이름
    var icon: String {
        switch self {
        case .sessions:
            return "list.bullet.rectangle"
        case .statistics:
            return "chart.bar"
        }
    }

    /// 아이콘 (선택된 상태)
    var selectedIcon: String {
        switch self {
        case .sessions:
            return "list.bullet.rectangle.fill"
        case .statistics:
            return "chart.bar.fill"
        }
    }
}
