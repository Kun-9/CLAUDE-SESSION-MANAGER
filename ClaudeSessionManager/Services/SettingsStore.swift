import AppKit
import Foundation

enum SettingsKeys {
    // UserDefaults 키 모음
    static let notificationsEnabled = "notifications.enabled"
    static let preToolUseEnabled = "hook.preToolUse.enabled"
    static let preToolUseTools = "hook.preToolUse.tools"
    static let stopEnabled = "hook.stop.enabled"
    static let permissionEnabled = "hook.permission.enabled"
    static let interactivePermission = "hook.permission.interactive"
    static let soundEnabled = "sound.enabled"
    static let soundName = "sound.name"
    static let soundVolume = "sound.volume"
    static let debugEnabled = "debug.enabled"
    static let debugLogs = "debug.logs"
    static let sessionListMode = "session.list.mode"
    static let sessionLayoutMode = "session.layout.mode"
    static let sessionStatusFilter = "session.status.filter"
    static let sessionCollapsedSections = "session.collapsed.sections"
    static let favoriteSections = "session.favorite.sections"
    static let terminalApp = "terminal.app"
}

/// 지원하는 터미널 앱
enum TerminalApp: String, CaseIterable, Identifiable {
    case iTerm2 = "iTerm2"
    case terminal = "Terminal"

    var id: String { rawValue }

    /// 앱 번들 ID
    var bundleId: String {
        switch self {
        case .iTerm2: return "com.googlecode.iterm2"
        case .terminal: return "com.apple.Terminal"
        }
    }

    /// 앱 이름 (UI 표시용)
    var displayName: String { rawValue }

    /// 시스템에 설치되어 있는지 확인
    var isInstalled: Bool {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) != nil
    }
}

enum SettingsStore {
    static let sharedSuiteName = "kun-project.ClaudeSessionManager.shared"
    static let defaults = UserDefaults(suiteName: sharedSuiteName) ?? .standard

    // 기본값을 UserDefaults에 등록
    static func registerDefaults() {
        defaults.register(
            defaults: [
                SettingsKeys.notificationsEnabled: true,
                SettingsKeys.preToolUseEnabled: false,
                SettingsKeys.preToolUseTools: "AskUserQuestion",
                SettingsKeys.stopEnabled: true,
                SettingsKeys.permissionEnabled: true,
                SettingsKeys.interactivePermission: false,
                SettingsKeys.soundEnabled: true,
                SettingsKeys.soundName: "Glass",
                SettingsKeys.soundVolume: 1.0,
                SettingsKeys.debugEnabled: false,
                SettingsKeys.sessionListMode: "By Location",
                SettingsKeys.sessionLayoutMode: "List",
                SettingsKeys.sessionCollapsedSections: "[]",
                SettingsKeys.favoriteSections: "[]",
                SettingsKeys.terminalApp: TerminalApp.iTerm2.rawValue,
            ]
        )
    }

    // MARK: - Terminal

    /// 현재 선택된 터미널 앱
    static func terminalApp() -> TerminalApp {
        let raw = defaults.string(forKey: SettingsKeys.terminalApp) ?? TerminalApp.iTerm2.rawValue
        return TerminalApp(rawValue: raw) ?? .iTerm2
    }

    /// 터미널 앱 설정 저장
    static func setTerminalApp(_ app: TerminalApp) {
        defaults.set(app.rawValue, forKey: SettingsKeys.terminalApp)
    }

    // MARK: - Notifications

    // 알림 전체 사용 여부
    static func notificationsEnabled() -> Bool {
        defaults.bool(forKey: SettingsKeys.notificationsEnabled)
    }

    // PreToolUse 훅 사용 여부
    static func preToolUseEnabled() -> Bool {
        defaults.bool(forKey: SettingsKeys.preToolUseEnabled)
    }

    // PreToolUse 허용 도구 목록 파싱
    static func preToolUseTools() -> [String] {
        let raw = defaults.string(forKey: SettingsKeys.preToolUseTools) ?? ""
        return raw
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    // Stop 훅 사용 여부
    static func stopEnabled() -> Bool {
        defaults.bool(forKey: SettingsKeys.stopEnabled)
    }

    // PermissionRequest 훅 사용 여부
    static func permissionEnabled() -> Bool {
        defaults.bool(forKey: SettingsKeys.permissionEnabled)
    }

    // 대화형 권한 요청 사용 여부 (앱에서 선택)
    static func interactivePermissionEnabled() -> Bool {
        defaults.bool(forKey: SettingsKeys.interactivePermission)
    }

    // 대화형 권한 요청 설정
    static func setInteractivePermission(_ enabled: Bool) {
        defaults.set(enabled, forKey: SettingsKeys.interactivePermission)
        defaults.synchronize()
    }

    // 사운드 사용 여부
    static func soundEnabled() -> Bool {
        defaults.bool(forKey: SettingsKeys.soundEnabled)
    }

    // 사운드 이름 가져오기
    static func soundName() -> String {
        let name = defaults.string(forKey: SettingsKeys.soundName) ?? ""
        return name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // 사운드 볼륨 (0.0 ~ 1.0)
    static func soundVolume() -> Double {
        let value = defaults.double(forKey: SettingsKeys.soundVolume)
        return value.clamped(to: 0.0...1.0)
    }

    // 디버그 로그 기록 여부
    static func debugEnabled() -> Bool {
        defaults.bool(forKey: SettingsKeys.debugEnabled)
    }

    // 디버그 로그 로드
    static func loadDebugLogs() -> [DebugLogEntry] {
        guard let data = defaults.data(forKey: SettingsKeys.debugLogs) else {
            return []
        }
        return (try? JSONDecoder().decode([DebugLogEntry].self, from: data)) ?? []
    }

    // 디버그 로그 저장
    static func saveDebugLogs(_ logs: [DebugLogEntry]) {
        guard let data = try? JSONEncoder().encode(logs) else {
            return
        }
        defaults.set(data, forKey: SettingsKeys.debugLogs)
    }

    // 디버그 로그 추가 (최근 200개 유지)
    static func appendDebugLog(_ entry: DebugLogEntry, maxEntries: Int = 200) {
        var logs = loadDebugLogs()
        logs.append(entry)
        if logs.count > maxEntries {
            logs.removeFirst(logs.count - maxEntries)
        }
        saveDebugLogs(logs)
    }

    static func clearDebugLogs() {
        defaults.removeObject(forKey: SettingsKeys.debugLogs)
    }
}

private extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
