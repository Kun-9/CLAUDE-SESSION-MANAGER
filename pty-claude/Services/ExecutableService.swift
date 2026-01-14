import Foundation

enum ExecutableService {
    /// 앱 번들에 포함된 훅 CLI 실행 파일 경로 반환
    static func hookCommandPath() -> String? {
        let toolURL = Bundle.main.bundleURL
            .appendingPathComponent("Contents")
            .appendingPathComponent("Resources")
            .appendingPathComponent("pty-claude-hook")
        guard FileManager.default.isExecutableFile(atPath: toolURL.path) else {
            return nil
        }
        return toolURL.path
    }
}
