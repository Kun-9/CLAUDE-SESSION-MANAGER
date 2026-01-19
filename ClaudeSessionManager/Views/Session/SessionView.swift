// MARK: - 파일 설명
// SessionView: 세션 탭 메인 뷰
// - 그룹핑 모드(All/By Location) 지원
// - 그리드 레이아웃 전용

import Foundation
import SwiftUI

struct SessionView: View {
    @StateObject private var viewModel = SessionListViewModel()
    @StateObject private var permissionViewModel = PermissionRequestViewModel()
    @Binding var selectedSession: SessionItem?
    @State private var sessionToDelete: SessionItem?

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // 컨트롤 영역: 그룹핑 모드 + 필터 + 프로세스 관리
                    HStack(spacing: 12) {
                        SessionListModeToggle(selection: $viewModel.listMode)
                        SessionStatusFilterToggle(selection: $viewModel.statusFilters)
                        Spacer()
                        ClaudeProcessManagerButton()
                    }

                    // 콘텐츠 영역: 그룹핑 모드에 따른 그리드 렌더링
                    sessionContent
                        .environmentObject(permissionViewModel)
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
    }

    // MARK: - Content Views

    @ViewBuilder
    private var sessionContent: some View {
        switch viewModel.listMode {
        case .all:
            // All: 전체 세션 격자
            SessionGridView(
                sessions: viewModel.filteredSessions,
                onSelect: { selectedSession = $0 },
                onDelete: { sessionToDelete = $0 },
                onRename: { session, newLabel in
                    viewModel.renameSession(session, to: newLabel)
                },
                onChangeStatus: { session, status in
                    viewModel.changeSessionStatus(session, to: status)
                }
            )
        case .byLocation:
            // By Location: 섹션별 격자
            SessionSectionGridView(
                sections: viewModel.sessionSections,
                collapsedIds: viewModel.collapsedSectionIds,
                onToggleSection: { viewModel.toggleSection($0) },
                onToggleFavorite: { viewModel.toggleFavorite($0) },
                onSelectSession: { selectedSession = $0 },
                onDeleteSession: { sessionToDelete = $0 },
                onRenameSession: { session, newLabel in
                    viewModel.renameSession(session, to: newLabel)
                },
                onChangeStatus: { session, status in
                    viewModel.changeSessionStatus(session, to: status)
                }
            )
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

