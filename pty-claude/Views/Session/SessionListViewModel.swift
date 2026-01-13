import Combine
import Foundation
import SwiftUI

@MainActor
final class SessionListViewModel: ObservableObject {
    @Published private(set) var sessions: [SessionItem] = []
    private var observer: NSObjectProtocol?

    init() {
        loadSessions()
        observer = DistributedNotificationCenter.default().addObserver(
            forName: SessionStore.sessionsDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.loadSessions()
        }
    }

    deinit {
        if let observer {
            DistributedNotificationCenter.default().removeObserver(observer)
        }
    }

    func loadSessions() {
        let records = SessionStore.loadSessions()
        sessions = records.map(SessionItem.init(record:))
    }
}
