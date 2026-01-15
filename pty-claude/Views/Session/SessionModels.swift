import Foundation
import SwiftUI

struct SessionItem: Identifiable {
    let id: String
    let name: String
    let detail: String
    let location: String?
    let status: SessionStatus
    let updatedText: String
    let startedAt: TimeInterval?  // 작업 시작 시간 (running 상태일 때만 유효)
    let duration: TimeInterval?   // 마지막 작업 소요 시간
    let lastPrompt: String?
    let lastResponse: String?
    let isUnseen: Bool            // 완료 후 미확인 상태 여부
}

enum SessionStatus: String {
    case running
    case finished
    case permission
    case normal
    case ended

    var label: String {
        switch self {
        case .running:
            return "진행중"
        case .finished:
            return "완료"
        case .permission:
            return "권한/선택 대기중"
        case .normal:
            return "대기"
        case .ended:
            return "종료"
        }
    }

    var tint: Color {
        switch self {
        case .running:
            return Color.green
        case .finished:
            return Color.blue
        case .permission:
            return Color.orange
        case .normal:
            return Color.gray
        case .ended:
            return Color.red
        }
    }

    var background: Color {
        switch self {
        case .running:
            return Color.green.opacity(0.12)
        case .finished:
            return Color.blue.opacity(0.12)
        case .permission:
            return Color.orange.opacity(0.12)
        case .normal:
            return Color.gray.opacity(0.12)
        case .ended:
            return Color.red.opacity(0.12)
        }
    }
}

extension SessionStatus {
    init(recordStatus: SessionStore.SessionRecordStatus) {
        switch recordStatus {
        case .running:
            self = .running
        case .finished:
            self = .finished
        case .permission:
            self = .permission
        case .normal:
            self = .normal
        case .ended:
            self = .ended
        }
    }
}

// 세션 위치 정보 보정 유틸
extension SessionItem {
    init(record: SessionStore.SessionRecord) {
        id = record.id
        name = record.name
        detail = record.detail
        location = record.location
        status = SessionStatus(recordStatus: record.status)
        updatedText = SessionItem.relativeUpdateText(from: record.updatedAt)
        startedAt = record.startedAt
        duration = record.duration
        lastPrompt = record.lastPrompt
        lastResponse = record.lastResponse
        // finished 상태이고 미확인이면 반짝이는 효과 표시
        isUnseen = (record.status == .finished) && !SessionStore.isSessionSeen(sessionId: record.id)
    }

    static func relativeUpdateText(from timestamp: TimeInterval) -> String {
        let now = Date().timeIntervalSince1970
        let delta = max(0, Int(now - timestamp))
        if delta < 60 {
            return "just now"
        }
        let minutes = delta / 60
        if minutes < 60 {
            return "\(minutes)m ago"
        }
        let hours = minutes / 60
        if hours < 24 {
            return "\(hours)h ago"
        }
        let days = hours / 24
        return "\(days)d ago"
    }
}

extension SessionItem {
    var locationPath: String? {
        let trimmedLocation = location?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !trimmedLocation.isEmpty {
            return trimmedLocation
        }
        let detailTrimmed = detail.trimmingCharacters(in: .whitespacesAndNewlines)
        if detailTrimmed.hasPrefix("/") || detailTrimmed.hasPrefix("~") {
            return detailTrimmed
        }
        return nil
    }

    var locationTitle: String {
        guard let locationPath else {
            return "Unknown Location"
        }
        return (locationPath as NSString).lastPathComponent
    }
}
