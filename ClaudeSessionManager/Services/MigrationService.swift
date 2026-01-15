// MARK: - 파일 설명
// MigrationService: 이전 버전(pty-claude) 데이터 마이그레이션
// - UserDefaults 마이그레이션 (kun-project.pty-claude.shared → kun-project.ClaudeSessionManager.shared)
// - Application Support 폴더 마이그레이션 (pty-claude → ClaudeSessionManager)

import AppKit

enum MigrationService {
    // MARK: - Constants

    private static let legacySuiteName = "kun-project.pty-claude.shared"
    private static let legacyAppFolderName = "pty-claude"
    private static let currentAppFolderName = "ClaudeSessionManager"
    private static let migrationCompletedKey = "migration.pty-claude.completed"

    // MARK: - Public Methods

    /// 앱 시작 시 호출하여 이전 데이터 마이그레이션 수행
    /// - 이미 마이그레이션이 완료된 경우 건너뜀
    /// - 마이그레이션 대상이 있으면 확인창 표시 후 진행
    static func migrateIfNeeded() {
        guard !isMigrationCompleted() else {
            return
        }

        // 마이그레이션 대상이 있는지 확인
        guard hasMigrationTargets() else {
            markMigrationCompleted()
            return
        }

        // 확인창 표시 후 사용자 승인 시 마이그레이션 수행
        if showMigrationConfirmation() {
            migrateUserDefaults()
            migrateApplicationSupportFolder()
            markMigrationCompleted()
        } else {
            // 사용자가 거부해도 다시 묻지 않도록 완료 표시
            markMigrationCompleted()
        }
    }

    // MARK: - Migration Check

    /// 마이그레이션 대상 데이터가 있는지 확인
    private static func hasMigrationTargets() -> Bool {
        // UserDefaults 확인
        if let legacyDefaults = UserDefaults(suiteName: legacySuiteName) {
            let legacyDict = legacyDefaults.dictionaryRepresentation()
            if !legacyDict.isEmpty {
                return true
            }
        }

        // Application Support 폴더 확인
        let fileManager = FileManager.default
        if let appSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            let legacyURL = appSupportURL.appendingPathComponent(legacyAppFolderName, isDirectory: true)
            if fileManager.fileExists(atPath: legacyURL.path) {
                return true
            }
        }

        return false
    }

    /// 마이그레이션 확인창 표시
    /// - Returns: 사용자가 마이그레이션에 동의하면 true
    private static func showMigrationConfirmation() -> Bool {
        let alert = NSAlert()
        alert.messageText = "이전 데이터 마이그레이션"
        alert.informativeText = """
            이전 버전(pty-claude)의 설정과 데이터가 발견되었습니다.

            마이그레이션을 진행하면 기존 설정, 세션 목록, 트랜스크립트 아카이브가 새 버전으로 복사됩니다.

            마이그레이션을 진행하시겠습니까?
            """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "마이그레이션")
        alert.addButton(withTitle: "건너뛰기")

        return alert.runModal() == .alertFirstButtonReturn
    }

    // MARK: - Private Methods

    /// 마이그레이션 완료 여부 확인
    private static func isMigrationCompleted() -> Bool {
        SettingsStore.defaults.bool(forKey: migrationCompletedKey)
    }

    /// 마이그레이션 완료 표시
    private static func markMigrationCompleted() {
        SettingsStore.defaults.set(true, forKey: migrationCompletedKey)
        SettingsStore.defaults.synchronize()
    }

    /// UserDefaults 마이그레이션
    /// - 이전 suite(pty-claude)의 데이터를 새 suite(ClaudeSessionManager)로 복사
    private static func migrateUserDefaults() {
        guard let legacyDefaults = UserDefaults(suiteName: legacySuiteName) else {
            return
        }

        let legacyDict = legacyDefaults.dictionaryRepresentation()
        guard !legacyDict.isEmpty else {
            return
        }

        // 마이그레이션할 키 목록 (앱에서 사용하는 모든 키)
        let keysToMigrate = [
            SettingsKeys.notificationsEnabled,
            SettingsKeys.preToolUseEnabled,
            SettingsKeys.preToolUseTools,
            SettingsKeys.stopEnabled,
            SettingsKeys.permissionEnabled,
            SettingsKeys.soundEnabled,
            SettingsKeys.soundName,
            SettingsKeys.soundVolume,
            SettingsKeys.debugEnabled,
            SettingsKeys.debugLogs,
            SettingsKeys.sessionListMode,
            SettingsKeys.sessionLayoutMode,
            SettingsKeys.sessionStatusFilter,
            SettingsKeys.sessionCollapsedSections,
            SettingsKeys.favoriteSections,
            SettingsKeys.terminalApp,
            "session.list",      // SessionStore.sessionsKey
            "session.seen",      // SessionStore.seenSessionsKey
        ]

        for key in keysToMigrate {
            // 새 defaults에 이미 값이 있으면 건너뜀
            if SettingsStore.defaults.object(forKey: key) != nil {
                continue
            }

            // 이전 defaults에서 값 복사
            if let value = legacyDefaults.object(forKey: key) {
                SettingsStore.defaults.set(value, forKey: key)
            }
        }

        SettingsStore.defaults.synchronize()
    }

    /// Application Support 폴더 마이그레이션
    /// - ~/Library/Application Support/pty-claude/ → ~/Library/Application Support/ClaudeSessionManager/
    private static func migrateApplicationSupportFolder() {
        let fileManager = FileManager.default
        guard let appSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return
        }

        let legacyURL = appSupportURL.appendingPathComponent(legacyAppFolderName, isDirectory: true)
        let currentURL = appSupportURL.appendingPathComponent(currentAppFolderName, isDirectory: true)

        // 이전 폴더가 없으면 건너뜀
        guard fileManager.fileExists(atPath: legacyURL.path) else {
            return
        }

        // 새 폴더가 이미 있으면 내용물만 복사
        if fileManager.fileExists(atPath: currentURL.path) {
            mergeDirectories(from: legacyURL, to: currentURL)
        } else {
            // 새 폴더가 없으면 이름 변경으로 이동
            do {
                try fileManager.moveItem(at: legacyURL, to: currentURL)
            } catch {
                // 이동 실패 시 복사 시도
                mergeDirectories(from: legacyURL, to: currentURL)
            }
        }
    }

    /// 디렉토리 내용물 병합 (기존 파일은 덮어쓰지 않음)
    private static func mergeDirectories(from sourceURL: URL, to destinationURL: URL) {
        let fileManager = FileManager.default

        // 대상 폴더 생성
        try? fileManager.createDirectory(at: destinationURL, withIntermediateDirectories: true)

        guard let contents = try? fileManager.contentsOfDirectory(
            at: sourceURL,
            includingPropertiesForKeys: nil
        ) else {
            return
        }

        for itemURL in contents {
            let destinationItemURL = destinationURL.appendingPathComponent(itemURL.lastPathComponent)

            // 이미 존재하면 건너뜀
            if fileManager.fileExists(atPath: destinationItemURL.path) {
                continue
            }

            var isDirectory: ObjCBool = false
            if fileManager.fileExists(atPath: itemURL.path, isDirectory: &isDirectory) {
                if isDirectory.boolValue {
                    // 하위 디렉토리 재귀 병합
                    mergeDirectories(from: itemURL, to: destinationItemURL)
                } else {
                    // 파일 복사
                    try? fileManager.copyItem(at: itemURL, to: destinationItemURL)
                }
            }
        }
    }
}
