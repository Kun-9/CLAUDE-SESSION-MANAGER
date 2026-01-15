import Foundation

enum SettingsKeys {
    // UserDefaults 키 모음
    static let notificationsEnabled = "notifications.enabled"
    static let preToolUseEnabled = "hook.preToolUse.enabled"
    static let preToolUseTools = "hook.preToolUse.tools"
    static let stopEnabled = "hook.stop.enabled"
    static let permissionEnabled = "hook.permission.enabled"
    static let soundEnabled = "sound.enabled"
    static let soundName = "sound.name"
    static let soundVolume = "sound.volume"
    static let debugEnabled = "debug.enabled"
    static let debugLogs = "debug.logs"
    static let sessionListMode = "session.list.mode"
    static let sessionLayoutMode = "session.layout.mode"
    static let sessionStatusFilter = "session.status.filter"
    static let sessionCollapsedSections = "session.collapsed.sections"
}

enum SettingsStore {
    static let sharedSuiteName = "kun-project.pty-claude.shared"
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
                SettingsKeys.soundEnabled: true,
                SettingsKeys.soundName: "Glass",
                SettingsKeys.soundVolume: 1.0,
                SettingsKeys.debugEnabled: false,
                SettingsKeys.sessionListMode: "By Location",
                SettingsKeys.sessionLayoutMode: "List",
                SettingsKeys.sessionCollapsedSections: "[]",
            ]
        )
    }

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
