import Combine
import Foundation
import SwiftUI

enum SessionListMode: String, CaseIterable, Identifiable {
    case all = "All"
    case byLocation = "By Location"

    var id: String { rawValue }
}

@MainActor
final class SessionListViewModel: ObservableObject {
    @Published private(set) var sessions: [SessionItem] = []
    @Published var listMode: SessionListMode = .byLocation {
        didSet { saveListMode() }
    }
    @Published var collapsedSectionIds: Set<String> = [] {
        didSet { saveCollapsedSections() }
    }

    private var observer: NSObjectProtocol?

    init() {
        loadSessions()
        loadPreferences()
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
        sessions = records
            .map(SessionItem.init(record:))
            .filter { $0.status != .normal }
    }

    /// 세션 삭제 (아카이브 + 세션 레코드 모두 삭제)
    func deleteSession(_ session: SessionItem) {
        TranscriptArchiveStore.delete(sessionId: session.id)
        SessionStore.deleteSession(sessionId: session.id)
        loadSessions()
    }

    /// 위치별 세션 섹션 반환
    var sessionSections: [SessionSection] {
        SessionGroupingService.groupByLocation(sessions)
    }

    /// 섹션 접힘 상태 확인
    func isSectionCollapsed(_ id: String) -> Bool {
        collapsedSectionIds.contains(id)
    }

    /// 섹션 접힘 토글
    func toggleSection(_ id: String) {
        if collapsedSectionIds.contains(id) {
            collapsedSectionIds.remove(id)
        } else {
            collapsedSectionIds.insert(id)
        }
    }

    // MARK: - Private

    private func loadPreferences() {
        let storedMode = SettingsStore.defaults.string(forKey: SettingsKeys.sessionListMode) ?? ""
        listMode = SessionListMode(rawValue: storedMode) ?? .byLocation
        let storedCollapsed = SettingsStore.defaults.string(forKey: SettingsKeys.sessionCollapsedSections) ?? "[]"
        collapsedSectionIds = SessionGroupingService.decodeCollapsedSections(storedCollapsed)
    }

    private func saveListMode() {
        SettingsStore.defaults.set(listMode.rawValue, forKey: SettingsKeys.sessionListMode)
    }

    private func saveCollapsedSections() {
        let json = SessionGroupingService.encodeCollapsedSections(collapsedSectionIds)
        SettingsStore.defaults.set(json, forKey: SettingsKeys.sessionCollapsedSections)
    }
}
