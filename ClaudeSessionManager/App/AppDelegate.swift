import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // 프리뷰 실행에서는 실제 동작을 건너뜀
        if EnvironmentUtils.isRunningForPreviews {
            return
        }

        // 이전 버전(pty-claude) 데이터 마이그레이션
        MigrationService.migrateIfNeeded()

        // 기본 설정 등록
        SettingsStore.registerDefaults()

        // 일반 앱 실행에서는 알림 권한 확인
        NotificationManager.requestAuthorizationIfNeeded()
    }
}
