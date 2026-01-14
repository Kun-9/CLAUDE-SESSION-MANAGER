// MARK: - 파일 설명
// SessionView: 세션 탭 메인 뷰
// - 그룹핑 모드(All/By Location)와 레이아웃 모드(List/Grid) 조합
// - 4가지 모드 조합 지원: All+List, All+Grid, ByLocation+List, ByLocation+Grid

import Foundation
import SwiftUI

struct SessionView: View {
    @StateObject private var viewModel = SessionListViewModel()
    @Binding var selectedSession: SessionItem?
    @State private var sessionToDelete: SessionItem?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // 컨트롤 영역: 그룹핑 모드 + 레이아웃 모드
                HStack(spacing: 12) {
                    SessionListModeToggle(selection: $viewModel.listMode)
                    Spacer()
                    SessionLayoutToggle(selection: $viewModel.layoutMode)
                }

                // 콘텐츠 영역: 모드 조합에 따른 렌더링
                sessionContent
            }
            .padding(24)
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
            ForEach(viewModel.sessions) { session in
                sessionButton(for: session)
            }
        }
    }

    @ViewBuilder
    private var allGridView: some View {
        SessionGridView(
            sessions: viewModel.sessions,
            onSelect: { selectedSession = $0 },
            onDelete: { sessionToDelete = $0 }
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
                            isCollapsed: viewModel.isSectionCollapsed(section.id)
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
            onSelectSession: { selectedSession = $0 },
            onDeleteSession: { sessionToDelete = $0 }
        )
    }

    @ViewBuilder
    private func sessionButton(for session: SessionItem) -> some View {
        Button {
            selectedSession = session
        } label: {
            SessionCardView(session: session, style: .full)
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(role: .destructive) {
                sessionToDelete = session
            } label: {
                Label("삭제", systemImage: "trash")
            }
        }
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
