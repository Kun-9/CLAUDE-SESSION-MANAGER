import Combine
import Foundation
import SwiftUI

// MARK: - 파일 설명
// SessionArchiveViewModel: 세션 아카이브 상세 데이터 로더
// - 아카이브된 transcript 로드
// - 실시간 세션 상태(currentSession) 관리
// - .running 상태 감지 및 전환 처리

@MainActor
final class SessionArchiveViewModel: ObservableObject {
    // MARK: - Published Properties

    @Published private(set) var transcript: SessionTranscript?
    @Published private(set) var archiveSizeText: String?
    @Published private(set) var currentSession: SessionItem?

    /// 현재 세션이 진행 중인지 여부 (running 또는 permission 대기)
    var isRunning: Bool {
        guard let status = currentSession?.status else { return false }
        return status == .running || status == .permission
    }

    /// 실시간 질문을 TranscriptEntry 형태로 반환 (running 상태일 때만)
    var liveEntry: TranscriptEntry? {
        guard isRunning,
              let prompt = currentSession?.lastPrompt,
              !prompt.isEmpty else {
            return nil
        }
        return TranscriptEntry(
            id: liveEntryId,
            role: .user,
            text: prompt,
            createdAt: Date().timeIntervalSince1970,
            entryType: nil,
            messageRole: "user",
            isMeta: false,
            messageContentIsString: true
        )
    }

    // MARK: - Private Properties

    private let sessionId: String
    private var observer: NSObjectProtocol?

    // MARK: - Lifecycle

    init(sessionId: String) {
        self.sessionId = sessionId
        Task { @MainActor in
            load()
            loadCurrentSession()
        }
        observer = DistributedNotificationCenter.default().addObserver(
            forName: SessionStore.sessionsDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor [weak self] in
                self?.handleSessionUpdate()
            }
        }
    }

    deinit {
        if let observer {
            DistributedNotificationCenter.default().removeObserver(observer)
        }
    }

    // 아카이브 데이터 로드
    func load() {
        transcript = TranscriptArchiveStore.load(sessionId: sessionId)
        archiveSizeText = formattedArchiveSize()
    }

    // 세션 삭제 (Claude Code 세션 파일 + 아카이브 + 세션 레코드 모두 삭제)
    func deleteSession() {
        ClaudeSessionService.deleteSession(sessionId: sessionId, location: currentSession?.location)
        TranscriptArchiveStore.delete(sessionId: sessionId)
        SessionStore.deleteSession(sessionId: sessionId)
    }

    // MARK: - Private Helpers

    /// 파일 크기를 사람이 읽기 쉬운 포맷으로 변환
    private func formattedArchiveSize() -> String? {
        guard let size = TranscriptArchiveStore.archiveSize(sessionId: sessionId) else {
            return nil
        }
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }

    /// 현재 세션 상태 로드
    private func loadCurrentSession() {
        let sessions = SessionStore.loadSessions()
        if let record = sessions.first(where: { $0.id == sessionId }) {
            currentSession = SessionItem(record: record)
        }
    }

    /// 세션 업데이트 핸들러 (DistributedNotification 수신 시)
    private func handleSessionUpdate() {
        let previousStatus = currentSession?.status
        loadCurrentSession()

        // 진행 상태(.running/.permission) → 완료(.finished) 전환 시 transcript 리로드
        let wasActive = previousStatus == .running || previousStatus == .permission
        let isNowFinished = currentSession?.status == .finished
        if wasActive, isNowFinished {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                self?.load()
            }
        }
    }
}
