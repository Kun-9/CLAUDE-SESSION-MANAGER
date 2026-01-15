import Foundation

// Claude 훅 미리보기 라인 모델
struct PreviewLine: Identifiable {
    let id = UUID()
    let text: String
    let kind: ChangeKind
}

enum ChangeKind {
    case unchanged
    case added
    case removed
}
