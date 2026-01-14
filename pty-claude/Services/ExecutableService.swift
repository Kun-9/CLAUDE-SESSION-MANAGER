// MARK: - 파일 설명
// ExecutableService: 앱 번들 내 실행 파일 경로 관리
// - 번들 리소스 경로 해석
// - 실행 권한 검증

import Foundation

enum ExecutableService {
    // MARK: - Constants

    private enum BundlePath {
        static let hookTool = "Contents/Resources/pty-claude-hook"
    }

    // MARK: - Public Methods

    /// 앱 번들에 포함된 훅 CLI 실행 파일 경로 반환
    /// - Returns: 실행 가능한 훅 도구 경로, 없거나 실행 불가 시 nil
    static func hookCommandPath() -> String? {
        let toolURL = Bundle.main.bundleURL
            .appendingPathComponent(BundlePath.hookTool)

        guard FileManager.default.isExecutableFile(atPath: toolURL.path) else {
            return nil
        }

        return toolURL.path
    }
}
