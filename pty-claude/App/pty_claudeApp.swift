import SwiftUI

@main
struct pty_claudeApp: App {
    // AppDelegate 연동
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            // 메인 설정 화면
            ContentView()
        }
    }
}
