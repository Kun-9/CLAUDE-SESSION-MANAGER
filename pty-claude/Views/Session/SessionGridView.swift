// MARK: - 파일 설명
// SessionGridView: 세션 목록 격자 레이아웃 컴포넌트
// - LazyVGrid 기반 적응형 열 배치
// - 창 크기에 따라 2~4열 자동 조절
// - 그룹핑 모드(All/By Location)와 조합 가능

import SwiftUI

/// 전체 세션 격자 뷰
struct SessionGridView: View {
    let sessions: [SessionItem]
    let onSelect: (SessionItem) -> Void
    var onDelete: ((SessionItem) -> Void)?

    /// 적응형 격자 열 정의 (최소 120pt, 최대 160pt)
    private let columns = [
        GridItem(.adaptive(minimum: 120, maximum: 160), spacing: 10)
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(sessions) { session in
                Button {
                    onSelect(session)
                } label: {
                    SessionCardView(session: session, style: .compact)
                }
                .buttonStyle(.plain)
                .contextMenu {
                    Button(role: .destructive) {
                        onDelete?(session)
                    } label: {
                        Label("삭제", systemImage: "trash")
                    }
                }
            }
        }
    }
}

/// 섹션별 격자 뷰 (By Location 모드용)
struct SessionSectionGridView: View {
    let sections: [SessionSection]
    let collapsedIds: Set<String>
    let onToggleSection: (String) -> Void
    let onSelectSession: (SessionItem) -> Void
    var onDeleteSession: ((SessionItem) -> Void)?

    private let columns = [
        GridItem(.adaptive(minimum: 120, maximum: 160), spacing: 10)
    ]

    var body: some View {
        LazyVStack(spacing: 16) {
            ForEach(sections) { section in
                VStack(alignment: .leading, spacing: 10) {
                    // 섹션 헤더 (접기/펼치기)
                    Button {
                        onToggleSection(section.id)
                    } label: {
                        SessionSectionHeader(
                            title: section.title,
                            subtitle: section.subtitle,
                            count: section.sessions.count,
                            isCollapsed: collapsedIds.contains(section.id)
                        )
                    }
                    .buttonStyle(.plain)

                    // 펼쳐진 경우 격자로 세션 표시
                    if !collapsedIds.contains(section.id) {
                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(section.sessions) { session in
                                Button {
                                    onSelectSession(session)
                                } label: {
                                    SessionCardView(session: session, style: .compact)
                                }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    Button(role: .destructive) {
                                        onDeleteSession?(session)
                                    } label: {
                                        Label("삭제", systemImage: "trash")
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
