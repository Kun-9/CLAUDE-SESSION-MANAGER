// MARK: - 파일 설명
// SessionStatus: 세션 상태 코드 정의
// - Codable: 저장/복원 지원
// - UI 속성: 라벨, 색상, 배경색

import Foundation
import SwiftUI

/// 세션 상태 코드
enum SessionStatus: String, Codable {
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
