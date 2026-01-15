// MARK: - 파일 설명
// SessionListViewModel: 세션 목록 화면의 ViewModel
// - 세션 목록 로드 및 상태 관리
// - 그룹핑 모드(All/By Location) 및 레이아웃 모드(List/Grid) 관리
// - 섹션 접힘 상태 관리

import Combine
import Foundation
import SwiftUI

// MARK: - Types

/// 세션 목록 그룹핑 모드
enum SessionListMode: String, CaseIterable, Identifiable {
    case all = "All"
    case byLocation = "By Location"

    var id: String { rawValue }
}

/// 세션 목록 레이아웃 모드
enum SessionLayoutMode: String, CaseIterable, Identifiable {
    case list = "List"
    case grid = "Grid"

    var id: String { rawValue }

    /// SF Symbol 아이콘 이름
    var icon: String {
        switch self {
        case .list: return "list.bullet"
        case .grid: return "square.grid.2x2"
        }
    }
}

/// 세션 상태 필터 (다중 선택 가능)
enum SessionStatusFilter: String, CaseIterable, Identifiable, Codable {
    case running = "진행중"
    case finished = "완료"
    case ended = "종료"

    var id: String { rawValue }

    /// 해당 필터에 포함되는 상태들
    func matches(_ status: SessionStatus) -> Bool {
        switch self {
        case .running: return status == .running || status == .permission
        case .finished: return status == .finished
        case .ended: return status == .ended
        }
    }

    /// 필터 고유 색상
    var tint: Color {
        switch self {
        case .running: return .green
        case .finished: return .blue
        case .ended: return .red
        }
    }
}

// MARK: - ViewModel

@MainActor
final class SessionListViewModel: ObservableObject {
    // MARK: - Published Properties

    @Published private(set) var sessions: [SessionItem] = []
    @Published var listMode: SessionListMode = .byLocation {
        didSet { saveListMode() }
    }
    @Published var layoutMode: SessionLayoutMode = .list {
        didSet { saveLayoutMode() }
    }
    /// 선택된 상태 필터들 (빈 Set = 전체 표시)
    @Published var statusFilters: Set<SessionStatusFilter> = [] {
        didSet { saveStatusFilter() }
    }
    @Published var collapsedSectionIds: Set<String> = [] {
        didSet { saveCollapsedSections() }
    }

    // MARK: - Private Properties

    private var observer: NSObjectProtocol?

    // MARK: - Lifecycle

    init() {
        Task { @MainActor in
            loadSessions()
            loadPreferences()
        }
        observer = DistributedNotificationCenter.default().addObserver(
            forName: SessionStore.sessionsDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor [weak self] in
                self?.loadSessions()
            }
        }
    }

    deinit {
        if let observer {
            DistributedNotificationCenter.default().removeObserver(observer)
        }
    }

    // MARK: - Public Methods

    /// 세션 목록 새로고침
    func loadSessions() {
        let records = SessionStore.loadSessions()
        sessions = records
            .map(SessionItem.init(record:))
            .filter { $0.status != .normal }
    }

    /// 세션 삭제 (Claude Code 세션 파일 + 아카이브 + 세션 레코드 모두 삭제)
    func deleteSession(_ session: SessionItem) {
        ClaudeSessionService.deleteSession(sessionId: session.id, location: session.location)
        TranscriptArchiveStore.delete(sessionId: session.id)
        SessionStore.deleteSession(sessionId: session.id)
        loadSessions()
    }

    /// 세션 상태 수동 변경 (완료/종료만 가능, 진행중은 HOOK 전용)
    func changeSessionStatus(_ session: SessionItem, to status: SessionStatus) {
        guard status == .finished || status == .ended else { return }
        let recordStatus = SessionStore.SessionRecordStatus(rawValue: status.rawValue) ?? .finished
        SessionStore.updateSessionStatus(sessionId: session.id, status: recordStatus, reorder: false)
        loadSessions()
    }

    /// 필터링된 세션 목록 (빈 필터 = 전체 표시)
    var filteredSessions: [SessionItem] {
        if statusFilters.isEmpty {
            return sessions
        }
        return sessions.filter { session in
            statusFilters.contains { $0.matches(session.status) }
        }
    }

    /// 위치별 세션 섹션 반환 (필터 적용)
    var sessionSections: [SessionSection] {
        SessionGroupingService.groupByLocation(filteredSessions)
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

    // MARK: - Private Helpers

    /// 사용자 설정 로드 (그룹핑 모드, 레이아웃 모드, 필터, 접힘 상태)
    private func loadPreferences() {
        let storedMode = SettingsStore.defaults.string(forKey: SettingsKeys.sessionListMode) ?? ""
        listMode = SessionListMode(rawValue: storedMode) ?? .byLocation
        let storedLayout = SettingsStore.defaults.string(forKey: SettingsKeys.sessionLayoutMode) ?? ""
        layoutMode = SessionLayoutMode(rawValue: storedLayout) ?? .list
        // 다중 선택 필터 로드 (JSON 배열)
        if let storedFilter = SettingsStore.defaults.string(forKey: SettingsKeys.sessionStatusFilter),
           let data = storedFilter.data(using: .utf8),
           let filters = try? JSONDecoder().decode([SessionStatusFilter].self, from: data) {
            statusFilters = Set(filters)
        } else {
            statusFilters = []
        }
        let storedCollapsed = SettingsStore.defaults.string(forKey: SettingsKeys.sessionCollapsedSections) ?? "[]"
        collapsedSectionIds = SessionGroupingService.decodeCollapsedSections(storedCollapsed)
    }

    private func saveListMode() {
        SettingsStore.defaults.set(listMode.rawValue, forKey: SettingsKeys.sessionListMode)
    }

    private func saveLayoutMode() {
        SettingsStore.defaults.set(layoutMode.rawValue, forKey: SettingsKeys.sessionLayoutMode)
    }

    private func saveStatusFilter() {
        // 다중 선택 필터 저장 (JSON 배열)
        let filters = Array(statusFilters)
        if let data = try? JSONEncoder().encode(filters),
           let json = String(data: data, encoding: .utf8) {
            SettingsStore.defaults.set(json, forKey: SettingsKeys.sessionStatusFilter)
        }
    }

    private func saveCollapsedSections() {
        let json = SessionGroupingService.encodeCollapsedSections(collapsedSectionIds)
        SettingsStore.defaults.set(json, forKey: SettingsKeys.sessionCollapsedSections)
    }
}
