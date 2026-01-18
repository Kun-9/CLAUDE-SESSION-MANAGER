// MARK: - 파일 설명
// MessageBubbleStyle: 메시지 말풍선 스타일 정의
// - 역할별 정렬, 색상, 배지 정보
// - TranscriptEntry에서 스타일 자동 결정

import SwiftUI

/// 메시지 말풍선 스타일
enum MessageBubbleStyle {
    case user
    case userDetail
    case assistant
    case assistantDetail
    case system

    // MARK: - Layout

    /// 수평 정렬
    var alignment: HorizontalAlignment {
        switch self {
        case .user, .userDetail:
            return .trailing
        case .assistant, .assistantDetail:
            return .leading
        case .system:
            return .center
        }
    }

    /// 프레임 정렬
    var frameAlignment: Alignment {
        switch self {
        case .user, .userDetail:
            return .trailing
        case .assistant, .assistantDetail:
            return .leading
        case .system:
            return .center
        }
    }

    /// 말풍선 꼬리 방향
    var tailDirection: BubbleTailDirection {
        switch self {
        case .user, .userDetail:
            return .right
        case .assistant, .assistantDetail:
            return .left
        case .system:
            return .none
        }
    }

    // MARK: - Colors

    /// 말풍선 배경색
    var backgroundColor: Color {
        switch self {
        case .user:
            return Color.blue.opacity(0.15)
        case .userDetail:
            return Color.orange.opacity(0.10)
        case .assistant:
            return Color.green.opacity(0.15)
        case .assistantDetail:
            return Color.purple.opacity(0.10)
        case .system:
            return Color.gray.opacity(0.08)
        }
    }

    /// 배지 라벨
    var badgeLabel: String {
        switch self {
        case .user:
            return "User"
        case .userDetail:
            return "User Detail"
        case .assistant:
            return "Assistant"
        case .assistantDetail:
            return "Assistant Detail"
        case .system:
            return "System"
        }
    }

    /// 배지 색상
    var badgeColor: Color {
        switch self {
        case .user:
            return Color.blue
        case .userDetail:
            return Color.orange
        case .assistant:
            return Color.green
        case .assistantDetail:
            return Color.purple
        case .system:
            return Color.gray
        }
    }

    // MARK: - Factory

    /// TranscriptEntry에서 스타일 결정 (캐시 사용)
    /// - Parameters:
    ///   - entry: 대상 엔트리
    ///   - entryCache: 사전 계산된 엔트리 메타데이터 캐시
    ///   - showDetail: 상세보기 모드 여부
    /// - Note: 성능 최적화를 위해 캐시된 값 사용. 목록 렌더링에서는 이 메서드 사용 권장
    static func from(
        entry: TranscriptEntry,
        entryCache: TranscriptEntryCache,
        showDetail: Bool
    ) -> MessageBubbleStyle {
        switch entry.role {
        case .user:
            // 상세보기 모드에서 시스템 주입 메시지 구분
            if showDetail && !TranscriptFilter.isDirectUserInput(entry) {
                return .userDetail
            }
            return .user

        case .assistant:
            // 상세보기 모드에서 중간 응답 구분 (캐시 사용)
            if showDetail && (entryCache.isIntermediate[entry.id] ?? false) {
                return .assistantDetail
            }
            return .assistant

        case .system, .unknown:
            return .system
        }
    }

    /// TranscriptEntry에서 스타일 결정 (캐시 없음, 단일 항목용)
    /// - Parameters:
    ///   - entry: 대상 엔트리
    ///   - allEntries: 전체 엔트리 (중간 응답 판별용)
    ///   - showDetail: 상세보기 모드 여부
    /// - Note: 단일 항목 조회 시에만 사용. 목록 렌더링에서는 캐시 버전 사용 권장
    static func from(
        entry: TranscriptEntry,
        allEntries: [TranscriptEntry],
        showDetail: Bool
    ) -> MessageBubbleStyle {
        switch entry.role {
        case .user:
            // 상세보기 모드에서 시스템 주입 메시지 구분
            if showDetail && !TranscriptFilter.isDirectUserInput(entry) {
                return .userDetail
            }
            return .user

        case .assistant:
            // 상세보기 모드에서 중간 응답 구분
            if showDetail && TranscriptFilter.isIntermediateAssistant(entry, in: allEntries) {
                return .assistantDetail
            }
            return .assistant

        case .system, .unknown:
            return .system
        }
    }
}
