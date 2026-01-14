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

/// 세션 상태 필터
enum SessionStatusFilter: String, CaseIterable, Identifiable {
    case all = "전체"
    case running = "진행중"
    case finished = "완료"
    case ended = "종료"

    var id: String { rawValue }

    /// 해당 필터에 포함되는 상태들
    func matches(_ status: SessionStatus) -> Bool {
        switch self {
        case .all: return true
        case .running: return status == .running || status == .permission
        case .finished: return status == .finished
        case .ended: return status == .ended
        }
    }

    /// 필터 선택 시 색상
    var tint: Color {
        switch self {
        case .all: return .primary
        case .running: return .green
        case .finished: return .blue
        case .ended: return .red
        }
    }

    /// 필터 선택 시 배경색
    var background: Color {
        switch self {
        case .all: return Color(NSColor.controlBackgroundColor)
        case .running: return .green.opacity(0.15)
        case .finished: return .blue.opacity(0.15)
        case .ended: return .red.opacity(0.15)
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
    @Published var statusFilter: SessionStatusFilter = .all {
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

    /// 세션 삭제 (아카이브 + 세션 레코드 모두 삭제)
    func deleteSession(_ session: SessionItem) {
        TranscriptArchiveStore.delete(sessionId: session.id)
        SessionStore.deleteSession(sessionId: session.id)
        loadSessions()
    }

    /// 필터링된 세션 목록
    var filteredSessions: [SessionItem] {
        sessions.filter { statusFilter.matches($0.status) }
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
        let storedFilter = SettingsStore.defaults.string(forKey: SettingsKeys.sessionStatusFilter) ?? ""
        statusFilter = SessionStatusFilter(rawValue: storedFilter) ?? .all
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
        SettingsStore.defaults.set(statusFilter.rawValue, forKey: SettingsKeys.sessionStatusFilter)
    }

    private func saveCollapsedSections() {
        let json = SessionGroupingService.encodeCollapsedSections(collapsedSectionIds)
        SettingsStore.defaults.set(json, forKey: SettingsKeys.sessionCollapsedSections)
    }
}
