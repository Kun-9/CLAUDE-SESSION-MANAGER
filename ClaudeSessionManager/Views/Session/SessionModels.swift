// MARK: - 파일 설명
// SessionModels: 세션 목록 UI에서 사용하는 ViewModel 데이터 모델
// - SessionItem: 세션 카드에 표시할 데이터
// - SessionRecord → SessionItem 변환 로직

import Foundation

/// 세션 목록 UI에서 사용하는 세션 항목 데이터
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


// MARK: - SessionRecord 변환

extension SessionItem {
    /// SessionStore.SessionRecord에서 SessionItem 생성
    init(record: SessionStore.SessionRecord) {
        id = record.id
        name = record.name
        detail = record.detail
        location = record.location
        status = record.status
        updatedText = SessionItem.relativeUpdateText(from: record.updatedAt)
        startedAt = record.startedAt
        duration = record.duration
        lastPrompt = record.lastPrompt
        lastResponse = record.lastResponse
        // finished 상태이고 미확인이면 테두리 강조 표시
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
