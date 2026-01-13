import Combine
import Foundation
import SwiftUI

// 세션 아카이브 상세 데이터 로더

@MainActor
final class SessionArchiveViewModel: ObservableObject {
    @Published private(set) var transcript: SessionTranscript?
    @Published private(set) var archiveSizeText: String?
    private let sessionId: String
    private var observer: NSObjectProtocol?

    init(sessionId: String) {
        self.sessionId = sessionId
        load()
        observer = DistributedNotificationCenter.default().addObserver(
            forName: SessionStore.sessionsDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.load()
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

    // 파일 크기를 사람이 읽기 쉬운 포맷으로 변환
    private func formattedArchiveSize() -> String? {
        guard let size = TranscriptArchiveStore.archiveSize(sessionId: sessionId) else {
            return nil
        }
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
}
