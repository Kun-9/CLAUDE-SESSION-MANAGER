import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // 비활성 창에서도 첫 클릭이 동작하도록 설정
        enableClickThrough()
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

    /// 비활성 창에서도 첫 클릭이 버튼/컨트롤에 전달되도록 설정
    private func enableClickThrough() {
        // NSView의 acceptsFirstMouse를 swizzle하여 항상 true 반환
        ClickThroughEnabler.enable()
    }
}

// MARK: - Click-Through Enabler
// NSView의 acceptsFirstMouse를 swizzle하여 비활성 창에서도 클릭 동작
private enum ClickThroughEnabler {
    static func enable() {
        let originalSelector = #selector(NSView.acceptsFirstMouse(for:))
        let swizzledSelector = #selector(NSView.swizzled_acceptsFirstMouse(for:))

        guard let originalMethod = class_getInstanceMethod(NSView.self, originalSelector),
              let swizzledMethod = class_getInstanceMethod(NSView.self, swizzledSelector) else {
            return
        }

        method_exchangeImplementations(originalMethod, swizzledMethod)
    }
}

extension NSView {
    @objc func swizzled_acceptsFirstMouse(for event: NSEvent?) -> Bool {
        return true
    }
}
