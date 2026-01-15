// MARK: - 파일 설명
// SessionView: 세션 탭 메인 뷰
// - 그룹핑 모드(All/By Location)와 레이아웃 모드(List/Grid) 조합
// - 4가지 모드 조합 지원: All+List, All+Grid, ByLocation+List, ByLocation+Grid

import Foundation
import SwiftUI

struct SessionView: View {
    @StateObject private var viewModel = SessionListViewModel()
    @StateObject private var permissionViewModel = PermissionRequestViewModel()
    @Binding var selectedSession: SessionItem?
    @State private var sessionToDelete: SessionItem?
    @State private var sessionToRename: SessionItem?

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // 컨트롤 영역: 그룹핑 모드 + 필터 + 레이아웃 모드
                    HStack(spacing: 12) {
                        SessionListModeToggle(selection: $viewModel.listMode)
                        SessionStatusFilterToggle(selection: $viewModel.statusFilters)
                        Spacer()
                        SessionLayoutToggle(selection: $viewModel.layoutMode)
                    }

                    // 콘텐츠 영역: 모드 조합에 따른 렌더링
                    sessionContent
                }
                .padding(24)
            }
        }
        .confirmationDialog(
            "세션 삭제",
            isPresented: .init(
                get: { sessionToDelete != nil },
                set: { if !$0 { sessionToDelete = nil } }
            ),
            presenting: sessionToDelete
        ) { session in
            Button("삭제", role: .destructive) {
                viewModel.deleteSession(session)
            }
        } message: { session in
            Text("'\(session.name)' 세션을 삭제하시겠습니까?\n아카이브된 대화 기록도 함께 삭제됩니다.")
        }
        .sheet(item: $sessionToRename) { session in
            SessionLabelEditSheet(session: session) { newLabel in
                viewModel.renameSession(session, to: newLabel)
            }
        }
    }

    // MARK: - Content Views

    @ViewBuilder
    private var sessionContent: some View {
        switch (viewModel.listMode, viewModel.layoutMode) {
        case (.all, .list):
            // All + List: 전체 세션 리스트
            allListView
        case (.all, .grid):
            // All + Grid: 전체 세션 격자
            allGridView
        case (.byLocation, .list):
            // By Location + List: 섹션별 리스트
            sectionListView
        case (.byLocation, .grid):
            // By Location + Grid: 섹션별 격자
            sectionGridView
        }
    }

    @ViewBuilder
    private var allListView: some View {
        LazyVStack(spacing: 12) {
            ForEach(viewModel.filteredSessions) { session in
                sessionButton(for: session)
            }
        }
    }

    @ViewBuilder
    private var allGridView: some View {
        SessionGridView(
            sessions: viewModel.filteredSessions,
            onSelect: { selectedSession = $0 },
            onDelete: { sessionToDelete = $0 },
            onRename: { sessionToRename = $0 },
            onChangeStatus: { session, status in
                viewModel.changeSessionStatus(session, to: status)
            }
        )
    }

    @ViewBuilder
    private var sectionListView: some View {
        LazyVStack(spacing: 16) {
            ForEach(viewModel.sessionSections) { section in
                VStack(alignment: .leading, spacing: 10) {
                    Button {
                        viewModel.toggleSection(section.id)
                    } label: {
                        SessionSectionHeader(
                            title: section.title,
                            subtitle: section.subtitle,
                            count: section.sessions.count,
                            isCollapsed: viewModel.isSectionCollapsed(section.id),
                            isFavorite: section.isFavorite,
                            onFavoriteTap: {
                                viewModel.toggleFavorite(section.id)
                            }
                        )
                    }
                    .buttonStyle(.plain)

                    if !viewModel.isSectionCollapsed(section.id) {
                        ForEach(section.sessions) { session in
                            sessionButton(for: session)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var sectionGridView: some View {
        SessionSectionGridView(
            sections: viewModel.sessionSections,
            collapsedIds: viewModel.collapsedSectionIds,
            onToggleSection: { viewModel.toggleSection($0) },
            onToggleFavorite: { viewModel.toggleFavorite($0) },
            onSelectSession: { selectedSession = $0 },
            onDeleteSession: { sessionToDelete = $0 },
            onRenameSession: { sessionToRename = $0 },
            onChangeStatus: { session, status in
                viewModel.changeSessionStatus(session, to: status)
            }
        )
    }

    /// 해당 세션에 대한 권한 요청 찾기
    private func permissionRequest(for session: SessionItem) -> PermissionRequest? {
        permissionViewModel.pendingRequests.first { $0.sessionId == session.id }
    }

    @ViewBuilder
    private func sessionButton(for session: SessionItem) -> some View {
        let request = permissionRequest(for: session)

        VStack(spacing: 0) {
            // 세션 카드
            Button {
                // 클릭 시 확인됨으로 표시
                if session.isUnseen {
                    SessionStore.markSessionAsSeen(sessionId: session.id)
                }
                selectedSession = session
            } label: {
                SessionCardView(session: session, style: .full)
            }
            .buttonStyle(.plain)
            .contextMenu {
                sessionStatusMenu(for: session)
            }

            // 권한 요청이 있으면 인라인 표시
            if let request = request {
                InlinePermissionRequestView(
                    request: request,
                    onAllow: { answers in permissionViewModel.allow(request: request, answers: answers) },
                    onDeny: { permissionViewModel.deny(request: request) },
                    onAsk: { permissionViewModel.askClaudeCode(request: request) }
                )
                .transition(.asymmetric(
                    insertion: .push(from: .top).combined(with: .opacity),
                    removal: .push(from: .bottom).combined(with: .opacity)
                ))
            }
        }
        .animation(.spring(response: 0.3), value: request?.id)
    }

    @ViewBuilder
    private func sessionStatusMenu(for session: SessionItem) -> some View {
        Button {
            viewModel.changeSessionStatus(session, to: .finished)
        } label: {
            Label("완료로 변경", systemImage: "checkmark.circle")
        }
        .disabled(session.status == .finished)

        Button {
            viewModel.changeSessionStatus(session, to: .ended)
        } label: {
            Label("종료로 변경", systemImage: "xmark.circle")
        }
        .disabled(session.status == .ended)

        Divider()

        Button {
            sessionToRename = session
        } label: {
            Label("이름 변경", systemImage: "pencil")
        }

        Button {
            TerminalService.resumeSession(sessionId: session.id, location: session.location)
        } label: {
            Label("대화 이어하기", systemImage: "terminal")
        }

        Divider()

        Button(role: .destructive) {
            sessionToDelete = session
        } label: {
            Label("삭제", systemImage: "trash")
        }
    }
}

// MARK: - 상태 필터 토글 (다중 선택)

private struct SessionStatusFilterToggle: View {
    @Binding var selection: Set<SessionStatusFilter>

    var body: some View {
        HStack(spacing: 2) {
            ForEach(SessionStatusFilter.allCases) { filter in
                filterButton(for: filter)
            }
        }
        .padding(3)
        .background {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Color(NSColor.controlBackgroundColor).opacity(0.5))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
        }
    }

    @ViewBuilder
    private func filterButton(for filter: SessionStatusFilter) -> some View {
        let isSelected = selection.contains(filter)
        Button {
            // 토글 동작: 선택/해제
            if selection.contains(filter) {
                selection.remove(filter)
            } else {
                selection.insert(filter)
            }
        } label: {
            Text(filter.rawValue)
                .font(.system(size: 12, weight: .medium))
                .frame(height: 28)
                .padding(.horizontal, 10)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundColor(isSelected ? filter.tint : Color.secondary.opacity(0.5))
    }
}

// MARK: - 그룹핑 모드 토글

private struct SessionListModeToggle: View {
    @Binding var selection: SessionListMode

    var body: some View {
        HStack(spacing: 2) {
            ForEach(SessionListMode.allCases) { mode in
                Button {
                    selection = mode
                } label: {
                    Text(mode.rawValue)
                        .font(.system(size: 12, weight: .medium))
                        .frame(height: 28)
                        .padding(.horizontal, 12)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .background(
                    selection == mode
                        ? Color(NSColor.controlBackgroundColor)
                        : Color.clear
                )
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .foregroundStyle(selection == mode ? .primary : .tertiary)
            }
        }
        .padding(3)
        .background {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Color(NSColor.controlBackgroundColor).opacity(0.5))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
        }
    }
}

// MARK: - 레이아웃 모드 토글

private struct SessionLayoutToggle: View {
    @Binding var selection: SessionLayoutMode

    var body: some View {
        HStack(spacing: 2) {
            ForEach(SessionLayoutMode.allCases) { mode in
                Button {
                    selection = mode
                } label: {
                    Image(systemName: mode.icon)
                        .font(.system(size: 12, weight: .medium))
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .background(
                    selection == mode
                        ? Color(NSColor.controlBackgroundColor)
                        : Color.clear
                )
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .foregroundStyle(selection == mode ? .primary : .tertiary)
            }
        }
        .padding(3)
        .background {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Color(NSColor.controlBackgroundColor).opacity(0.5))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
        }
    }
}
