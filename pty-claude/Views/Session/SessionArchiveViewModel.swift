import Combine
import Foundation
import SwiftUI

@MainActor
final class SessionArchiveViewModel: ObservableObject {
    @Published private(set) var transcript: SessionTranscript?
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

    func load() {
        transcript = TranscriptArchiveStore.load(sessionId: sessionId)
    }
}
