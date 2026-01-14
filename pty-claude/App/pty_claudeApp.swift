import SwiftUI

@main
struct pty_claudeApp: App {
    // AppDelegate 연동
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var toastCenter = ToastCenter()
    @StateObject private var debugLogStore = DebugLogStore()

    var body: some Scene {
        WindowGroup {
            // 메인 설정 화면
            ContentView()
                .environmentObject(toastCenter)
                .environmentObject(debugLogStore)
        }
    }
}
