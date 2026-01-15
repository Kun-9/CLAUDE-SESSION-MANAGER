// MARK: - 파일 설명
// ClaudeSessionService: Claude Code 세션 파일 관리
// - ~/.claude/projects/ 디렉토리의 세션 파일 삭제
// - 경로 인코딩/디코딩 처리

import Foundation

enum ClaudeSessionService {
    // MARK: - Constants

    /// Claude Code 세션 저장 기본 경로
    private static var claudeProjectsPath: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/projects")
    }

    // MARK: - Public Methods

    /// Claude Code 세션 파일 삭제
    /// - Parameters:
    ///   - sessionId: 세션 UUID
    ///   - location: 프로젝트 경로 (cwd)
    /// - Returns: 삭제 성공 여부
    @discardableResult
    static func deleteSession(sessionId: String, location: String?) -> Bool {
        guard let location, !location.isEmpty else {
            return false
        }

        let encodedPath = encodeProjectPath(location)
        let projectDir = claudeProjectsPath.appendingPathComponent(encodedPath)

        var success = true

        // 세션 데이터 파일 삭제 (.jsonl)
        let sessionFile = projectDir.appendingPathComponent("\(sessionId).jsonl")
        if FileManager.default.fileExists(atPath: sessionFile.path) {
            do {
                try FileManager.default.removeItem(at: sessionFile)
            } catch {
                success = false
            }
        }

        // 세션 폴더 삭제 (있는 경우)
        let sessionDir = projectDir.appendingPathComponent(sessionId)
        if FileManager.default.fileExists(atPath: sessionDir.path) {
            do {
                try FileManager.default.removeItem(at: sessionDir)
            } catch {
                success = false
            }
        }

        return success
    }

    /// Claude Code 세션 파일 존재 여부 확인
    /// - Parameters:
    ///   - sessionId: 세션 UUID
    ///   - location: 프로젝트 경로 (cwd)
    /// - Returns: 파일 존재 여부
    static func sessionFileExists(sessionId: String, location: String?) -> Bool {
        guard let location, !location.isEmpty else {
            return false
        }

        let encodedPath = encodeProjectPath(location)
        let projectDir = claudeProjectsPath.appendingPathComponent(encodedPath)
        let sessionFile = projectDir.appendingPathComponent("\(sessionId).jsonl")

        return FileManager.default.fileExists(atPath: sessionFile.path)
    }

    // MARK: - Private Helpers

    /// 프로젝트 경로를 Claude Code 디렉토리명으로 인코딩
    /// - 예: /Users/kun-mini/project → -Users-kun-mini-project
    private static func encodeProjectPath(_ path: String) -> String {
        path.replacingOccurrences(of: "/", with: "-")
    }
}
