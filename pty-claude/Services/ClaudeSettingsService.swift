import AppKit
import Foundation

// Claude 설정 파일 I/O와 훅 업데이트 로직을 전담
enum ClaudeSettingsService {
    // 설정 파일 경로 계산 (~/.claude/settings.json)
    private static var settingsURL: URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let claudeDir = home.appendingPathComponent(".claude", isDirectory: true)
        return claudeDir.appendingPathComponent("settings.json")
    }

    // hooks 항목을 덮어쓰기 업데이트
    static func updateHooks(command: String) -> String {
        let settingsURL = settingsURL
        let claudeDir = settingsURL.deletingLastPathComponent()

        do {
            try FileManager.default.createDirectory(at: claudeDir, withIntermediateDirectories: true)
        } catch {
            return "Failed to create ~/.claude directory: \(error.localizedDescription)"
        }

        var root: [String: Any] = [:]
        if FileManager.default.fileExists(atPath: settingsURL.path) {
            do {
                let data = try Data(contentsOf: settingsURL)
                if !data.isEmpty {
                    if let parsed = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        root = parsed
                    } else {
                        return "settings.json is not a JSON object."
                    }
                }
            } catch {
                return "Failed to read settings.json: \(error.localizedDescription)"
            }
        }

        root.removeValue(forKey: "hook")
        root["hooks"] = hookSection(command: command)

        do {
            let data = try JSONSerialization.data(withJSONObject: root, options: [.prettyPrinted, .sortedKeys])
            try data.write(to: settingsURL, options: .atomic)
        } catch {
            return "Failed to write settings.json: \(error.localizedDescription)"
        }

        return "Claude hooks updated."
    }

    // 업데이트 전/후 diff 미리보기 생성
    static func buildHooksPreview(command: String) -> (after: [PreviewLine], canApply: Bool, statusMessage: String?, error: String?) {
        let before = loadSettings(url: settingsURL)
        let after = updatedSettings(from: before, command: command)

        let beforeText = prettyJSON(from: before) ?? "{}"
        let afterText = prettyJSON(from: after) ?? "{}"

        let diff = buildLineDiff(before: beforeText, after: afterText)
        let canApply = hooksNeedUpdate(command: command)
        if !canApply {
            return (diff.lines, false, "No changes detected.", nil)
        }
        return (diff.lines, true, nil, nil)
    }

    // 설정 파일이 없으면 생성한 뒤 Finder에서 열기
    static func openSettings() -> String {
        let settingsURL = settingsURL
        let claudeDir = settingsURL.deletingLastPathComponent()

        do {
            try FileManager.default.createDirectory(at: claudeDir, withIntermediateDirectories: true)
            if !FileManager.default.fileExists(atPath: settingsURL.path) {
                try Data("{}".utf8).write(to: settingsURL, options: .atomic)
            }
            NSWorkspace.shared.open(settingsURL)
            return "Opened settings.json."
        } catch {
            return "Failed to open settings.json: \(error.localizedDescription)"
        }
    }

    // hook 섹션만 포함한 JSON 스니펫 생성
    static func hooksJSONSnippet(command: String) -> String? {
        let before = loadSettings(url: settingsURL)
        let updated = updatedSettings(from: before, command: command)
        let hooks = updated["hooks"] as? [String: Any] ?? [:]
        let root: [String: Any] = ["hooks": hooks]
        return prettyJSON(from: root)
    }

    static func hooksNeedUpdate(command: String) -> Bool {
        let before = loadSettings(url: settingsURL)
        let currentHooks = before["hooks"] as? [String: Any] ?? [:]
        let desiredHooks = hookSection(command: command)
        guard let currentJSON = canonicalJSON(from: currentHooks),
              let desiredJSON = canonicalJSON(from: desiredHooks) else {
            return true
        }
        return currentJSON != desiredJSON
    }

    // JSON 파일을 딕셔너리로 로드
    private static func loadSettings(url: URL) -> [String: Any] {
        guard FileManager.default.fileExists(atPath: url.path) else {
            return [:]
        }
        do {
            let data = try Data(contentsOf: url)
            guard !data.isEmpty else { return [:] }
            if let parsed = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                return parsed
            }
        } catch {
            return [:]
        }
        return [:]
    }

    // 훅 명령을 반영한 설정 구조 생성
    private static func updatedSettings(from root: [String: Any], command: String) -> [String: Any] {
        var updated = root
        updated.removeValue(forKey: "hook")
        updated["hooks"] = hookSection(command: command)
        return updated
    }

    // 새 hook 섹션 생성 (기존 hook이 있으면 대체)
    private static func hookSection(command: String) -> [String: Any] {
        let hookEntry: [[String: Any]] = [
            [
                "matcher": "",
                "hooks": [
                    [
                        "type": "command",
                        "command": command,
                    ],
                ],
            ],
        ]

        return [
            "PreToolUse": hookEntry,
            "Stop": hookEntry,
            "PermissionRequest": hookEntry,
            "SessionStart": hookEntry,
            "SessionEnd": hookEntry,
            "UserPromptSubmit": hookEntry,
        ]
    }

    // JSON 객체를 보기 좋은 문자열로 변환
    private static func prettyJSON(from object: [String: Any]) -> String? {
        guard let data = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys]) else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    private static func canonicalJSON(from object: [String: Any]) -> String? {
        guard let data = try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]) else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    // before/after 라인을 비교해 변경 여부 표시
    private static func buildLineDiff(before: String, after: String) -> (lines: [PreviewLine], hasChanges: Bool) {
        let beforeLines = before.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let afterLines = after.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        var diffLines: [PreviewLine] = []
        var hasChanges = false

        let beforeCount = beforeLines.count
        let afterCount = afterLines.count
        var lcs = Array(repeating: Array(repeating: 0, count: afterCount + 1), count: beforeCount + 1)

        if beforeCount > 0 && afterCount > 0 {
            for i in stride(from: beforeCount - 1, through: 0, by: -1) {
                for j in stride(from: afterCount - 1, through: 0, by: -1) {
                    if beforeLines[i] == afterLines[j] {
                        lcs[i][j] = lcs[i + 1][j + 1] + 1
                    } else {
                        lcs[i][j] = max(lcs[i + 1][j], lcs[i][j + 1])
                    }
                }
            }
        }

        var i = 0
        var j = 0
        while i < beforeCount || j < afterCount {
            if i < beforeCount && j < afterCount && beforeLines[i] == afterLines[j] {
                diffLines.append(PreviewLine(text: beforeLines[i], kind: .unchanged))
                i += 1
                j += 1
            } else if j < afterCount && (i == beforeCount || lcs[i][j + 1] >= lcs[i + 1][j]) {
                diffLines.append(PreviewLine(text: afterLines[j], kind: .added))
                hasChanges = true
                j += 1
            } else if i < beforeCount {
                diffLines.append(PreviewLine(text: beforeLines[i], kind: .removed))
                hasChanges = true
                i += 1
            }
        }

        return (diffLines, hasChanges)
    }
}
