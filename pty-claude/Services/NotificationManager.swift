import AppKit
import Foundation
import UserNotifications

enum NotificationManager {
    // 필요 시 알림 권한 요청
    static func requestAuthorizationIfNeeded() {
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            if settings.authorizationStatus == .notDetermined {
                center.requestAuthorization(options: [.alert, .sound]) { _, _ in }
            }
        }
    }

    // 즉시 알림 전송 + 선택적 사운드 재생
    static func send(title: String, body: String) {
        // CLI 훅 도구에서는 UNUserNotificationCenter가 예외를 발생시키므로 우회
        if !isAppBundle {
            sendLegacy(title: title, body: body)
            playSoundIfNeeded()
            return
        }

        guard ensureAuthorization() else {
            return
        }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        let center = UNUserNotificationCenter.current()
        let semaphore = DispatchSemaphore(value: 0)
        center.add(request) { _ in
            semaphore.signal()
        }
        _ = semaphore.wait(timeout: .now() + 1.0)

        playSoundIfNeeded()
    }

    // .app 번들에서 실행 중인지 확인 (CLI 도구는 .app이 아님)
    private static var isAppBundle: Bool {
        Bundle.main.bundleURL.pathExtension == "app"
    }

    // CLI 도구용 레거시 알림 경로
    private static func sendLegacy(title: String, body: String) {
        let script = "display notification \"\(escapeForAppleScript(body))\" with title \"\(escapeForAppleScript(title))\""
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]
        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            logToStderr("Failed to send legacy notification: \(error.localizedDescription)")
        }
    }

    // 현재 권한 상태 확인 및 필요 시 요청
    private static func ensureAuthorization() -> Bool {
        let center = UNUserNotificationCenter.current()
        let semaphore = DispatchSemaphore(value: 0)
        var authorized = false

        center.getNotificationSettings { settings in
            switch settings.authorizationStatus {
            case .authorized:
                authorized = true
                semaphore.signal()
            case .notDetermined:
                center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
                    authorized = granted
                    semaphore.signal()
                }
            default:
                authorized = false
                semaphore.signal()
            }
        }

        _ = semaphore.wait(timeout: .now() + 1.0)

        if !authorized {
            // 훅 모드에서는 UI가 없으므로 stderr로 안내
            logToStderr("Notifications not authorized. Run the app once to grant permission in System Settings > Notifications.")
        }

        return authorized
    }

    // 표준 에러 출력
    private static func logToStderr(_ message: String) {
        guard let data = (message + "\n").data(using: .utf8) else {
            return
        }
        FileHandle.standardError.write(data)
    }

    // 설정에 따른 사운드 재생 처리
    private static func playSoundIfNeeded() {
        if SettingsStore.soundEnabled() {
            let soundName = SettingsStore.soundName()
            if !soundName.isEmpty, let sound = NSSound(named: NSSound.Name(soundName)) {
                sound.volume = Float(SettingsStore.soundVolume())
                sound.play()
                // 짧게 기다려 사운드가 끊기지 않도록 처리
                waitForSoundPlayback(sound)
            }
        }
    }

    // AppleScript 문자열 이스케이프 처리
    private static func escapeForAppleScript(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }

    // 재생이 끝나거나 타임아웃까지 대기
    private static func waitForSoundPlayback(_ sound: NSSound) {
        let timeout = Date().addingTimeInterval(0.8)
        while sound.isPlaying && Date() < timeout {
            RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.05))
        }
    }
}
