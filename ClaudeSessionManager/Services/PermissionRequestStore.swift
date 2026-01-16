// MARK: - 파일 설명
// PermissionRequestStore: 권한 요청 IPC 관리
// - 파일 기반 IPC로 hook CLI와 앱 간 통신
// - 요청/응답 파일 관리

import Foundation

/// 권한 요청 정보
struct PermissionRequest: Codable, Identifiable {
    let id: String
    let sessionId: String
    let sessionName: String?  // 프로젝트 이름 (cwd에서 추출)
    let toolName: String
    let cwd: String?
    let createdAt: TimeInterval
    let questions: [PermissionQuestion]?

    /// 선택지가 있는 질문인지 여부
    var hasQuestions: Bool {
        guard let questions = questions, !questions.isEmpty else { return false }
        return true
    }

    /// 표시용 세션 이름 (sessionName 또는 cwd에서 추출)
    var displayName: String {
        if let name = sessionName, !name.isEmpty {
            return name
        }
        if let cwd = cwd {
            return cwd.split(separator: "/").last.map(String.init) ?? "Unknown"
        }
        return "Unknown"
    }

    /// 타임아웃 여부 확인
    func isExpired(timeout: TimeInterval) -> Bool {
        Date().timeIntervalSince1970 - createdAt > timeout
    }
}

/// 권한 요청 내 질문 (AskUserQuestion 등)
struct PermissionQuestion: Codable, Identifiable {
    let header: String?
    let question: String?
    let multiSelect: Bool
    let options: [PermissionOption]

    var id: String { header ?? UUID().uuidString }
}

/// 질문 선택지
struct PermissionOption: Codable, Identifiable {
    let label: String
    let description: String?

    var id: String { label }
}

/// 권한 응답 결정
enum PermissionDecision: String, Codable {
    case allow
    case deny
    case ask  // 사용자에게 물어보기 (Claude Code 기본 UI 사용)
}

/// 권한 응답 정보
struct PermissionResponse: Codable {
    let requestId: String
    let decision: PermissionDecision
    let message: String?
    let answers: [String: String]?  // 질문 인덱스 -> 선택된 label
    let respondedAt: TimeInterval
}

enum PermissionRequestStore {
    // MARK: - Constants

    /// IPC 디렉토리 경로
    private static var baseDirectory: URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home.appendingPathComponent(".claude-session-manager/permission")
    }

    private static var pendingDirectory: URL {
        baseDirectory.appendingPathComponent("pending")
    }

    private static var responseDirectory: URL {
        baseDirectory.appendingPathComponent("response")
    }

    /// Polling 간격 (초)
    static let pollingInterval: TimeInterval = 0.5

    // MARK: - Directory Setup

    /// IPC 디렉토리 생성
    static func ensureDirectories() {
        let fm = FileManager.default
        try? fm.createDirectory(at: pendingDirectory, withIntermediateDirectories: true)
        try? fm.createDirectory(at: responseDirectory, withIntermediateDirectories: true)
    }

    // MARK: - Request Management (Hook CLI -> App)

    /// 권한 요청 저장 (hook CLI에서 호출)
    /// - Returns: 생성된 요청 ID
    @discardableResult
    static func savePendingRequest(
        sessionId: String?,
        sessionName: String? = nil,
        toolName: String?,
        cwd: String?,
        questions: [PermissionQuestion]? = nil
    ) -> String {
        ensureDirectories()

        // 세션 이름: 전달받은 값 또는 cwd에서 추출
        let resolvedSessionName = sessionName ?? cwd?.split(separator: "/").last.map(String.init)

        let requestId = UUID().uuidString
        let request = PermissionRequest(
            id: requestId,
            sessionId: sessionId ?? "",
            sessionName: resolvedSessionName,
            toolName: toolName ?? "Unknown",
            cwd: cwd,
            createdAt: Date().timeIntervalSince1970,
            questions: questions
        )

        let filePath = pendingDirectory.appendingPathComponent("\(requestId).json")
        if let data = try? JSONEncoder().encode(request) {
            try? data.write(to: filePath)
        }

        // 알림 전송 (앱이 감지하도록)
        notifyPendingRequestAdded()

        return requestId
    }

    /// 대기 중인 요청 목록 로드 (앱에서 호출)
    static func loadPendingRequests() -> [PermissionRequest] {
        ensureDirectories()

        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(
            at: pendingDirectory,
            includingPropertiesForKeys: nil
        ) else {
            return []
        }

        return files
            .filter { $0.pathExtension == "json" }
            .compactMap { url -> PermissionRequest? in
                guard let data = try? Data(contentsOf: url),
                      let request = try? JSONDecoder().decode(PermissionRequest.self, from: data) else {
                    return nil
                }
                return request
            }
            .sorted { $0.createdAt > $1.createdAt }
    }

    /// 특정 요청 삭제 (처리 완료 후)
    static func deletePendingRequest(requestId: String) {
        let filePath = pendingDirectory.appendingPathComponent("\(requestId).json")
        try? FileManager.default.removeItem(at: filePath)
    }

    /// 특정 세션의 모든 pending 요청 삭제 (터미널에서 직접 처리된 경우)
    static func deletePendingRequests(forSessionId sessionId: String?) {
        guard let sessionId = sessionId, !sessionId.isEmpty else { return }

        let requests = loadPendingRequests()
        for request in requests where request.sessionId == sessionId {
            deletePendingRequest(requestId: request.id)
        }
    }

    // MARK: - Response Management (App -> Hook CLI)

    /// 응답 저장 (앱에서 호출)
    static func saveResponse(
        requestId: String,
        decision: PermissionDecision,
        message: String? = nil,
        answers: [String: String]? = nil
    ) {
        ensureDirectories()

        let response = PermissionResponse(
            requestId: requestId,
            decision: decision,
            message: message,
            answers: answers,
            respondedAt: Date().timeIntervalSince1970
        )

        let filePath = responseDirectory.appendingPathComponent("\(requestId).json")
        if let data = try? JSONEncoder().encode(response) {
            try? data.write(to: filePath)
        }

        // 요청 파일 삭제
        deletePendingRequest(requestId: requestId)
    }

    /// 응답 로드 (hook CLI에서 polling)
    static func loadResponse(requestId: String) -> PermissionResponse? {
        let filePath = responseDirectory.appendingPathComponent("\(requestId).json")
        guard let data = try? Data(contentsOf: filePath),
              let response = try? JSONDecoder().decode(PermissionResponse.self, from: data) else {
            return nil
        }
        return response
    }

    /// 응답 삭제 (처리 완료 후)
    static func deleteResponse(requestId: String) {
        let filePath = responseDirectory.appendingPathComponent("\(requestId).json")
        try? FileManager.default.removeItem(at: filePath)
    }

    /// pending 요청 파일 존재 여부 확인
    static func pendingRequestExists(requestId: String) -> Bool {
        let filePath = pendingDirectory.appendingPathComponent("\(requestId).json")
        return FileManager.default.fileExists(atPath: filePath.path)
    }

    /// 응답 대기 (hook CLI에서 호출, blocking, 무한 대기)
    /// - Parameter requestId: 요청 ID
    /// - Returns: 응답 (pending 삭제 시 nil)
    static func waitForResponse(requestId: String) -> PermissionResponse? {
        while true {
            // 응답이 있으면 반환
            if let response = loadResponse(requestId: requestId) {
                deleteResponse(requestId: requestId)
                return response
            }

            // pending 파일이 삭제되면 종료 (세션 종료, 터미널에서 처리 등)
            if !pendingRequestExists(requestId: requestId) {
                return nil
            }

            Thread.sleep(forTimeInterval: pollingInterval)
        }
    }

    // MARK: - Notification

    /// 권한 요청 추가 알림 이름
    static let permissionRequestAddedNotification = Notification.Name(
        "ClaudeSessionManager.permission.request.added"
    )

    /// 권한 요청 추가 알림 전송
    private static func notifyPendingRequestAdded() {
        DistributedNotificationCenter.default().postNotificationName(
            permissionRequestAddedNotification,
            object: nil,
            userInfo: nil,
            deliverImmediately: true
        )
    }

    // MARK: - Cleanup

    /// 만료된 요청/응답 정리 (기본 24시간 후 삭제)
    static func cleanupExpiredFiles(timeout: TimeInterval = 86400) {
        let fm = FileManager.default
        let now = Date().timeIntervalSince1970

        // 만료된 요청 삭제
        if let files = try? fm.contentsOfDirectory(at: pendingDirectory, includingPropertiesForKeys: nil) {
            for file in files where file.pathExtension == "json" {
                if let data = try? Data(contentsOf: file),
                   let request = try? JSONDecoder().decode(PermissionRequest.self, from: data),
                   now - request.createdAt > timeout {
                    try? fm.removeItem(at: file)
                }
            }
        }

        // 만료된 응답 삭제
        if let files = try? fm.contentsOfDirectory(at: responseDirectory, includingPropertiesForKeys: nil) {
            for file in files where file.pathExtension == "json" {
                if let data = try? Data(contentsOf: file),
                   let response = try? JSONDecoder().decode(PermissionResponse.self, from: data),
                   now - response.respondedAt > timeout {
                    try? fm.removeItem(at: file)
                }
            }
        }
    }
}

// MARK: - Hook Response Formatter

extension PermissionRequestStore {
    /// Claude Code에 보낼 hookSpecificOutput JSON 생성
    static func formatHookResponse(
        decision: PermissionDecision,
        message: String? = nil,
        answers: [String: String]? = nil
    ) -> Data? {
        var decisionDict: [String: Any] = ["behavior": decision.rawValue]
        if let message = message, decision == .deny {
            decisionDict["message"] = message
        }

        // 선택지 응답이 있으면 updatedInput에 추가
        if let answers = answers, !answers.isEmpty {
            decisionDict["updatedInput"] = ["answers": answers]
        }

        let response: [String: Any] = [
            "hookSpecificOutput": [
                "hookEventName": "PermissionRequest",
                "decision": decisionDict
            ]
        ]

        return try? JSONSerialization.data(withJSONObject: response, options: [])
    }

    /// 기존 allow 응답 (fallback용)
    static func formatLegacyAllowResponse() -> Data? {
        let response = ["allow": true]
        return try? JSONSerialization.data(withJSONObject: response, options: [])
    }
}
