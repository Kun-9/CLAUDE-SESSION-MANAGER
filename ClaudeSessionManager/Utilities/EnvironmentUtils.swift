import Foundation

enum EnvironmentUtils {
    // Xcode 프리뷰 실행 여부 판단
    static var isRunningForPreviews: Bool {
        ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }
}
