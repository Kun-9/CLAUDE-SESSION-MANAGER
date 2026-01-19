// MARK: - 파일 설명
// SessionGridView: 세션 목록 격자 레이아웃 컴포넌트
// - LazyVGrid 기반 적응형 열 배치
// - 창 크기에 따라 2~4열 자동 조절
// - 그룹핑 모드(All/By Location)와 조합 가능
// - 권한 요청 변경 시 해당 세션 카드만 업데이트 (SessionGridCell 분리)

import SwiftUI

/// 전체 세션 격자 뷰
struct SessionGridView: View {
    let sessions: [SessionItem]
    let onSelect: (SessionItem) -> Void
    var onDelete: ((SessionItem) -> Void)?
    var onRename: ((SessionItem, String) -> Void)?
    var onChangeStatus: ((SessionItem, SessionStatus) -> Void)?

    @EnvironmentObject private var permissionViewModel: PermissionRequestViewModel
    @State private var renamingSession: SessionItem?

    /// 적응형 격자 열 정의 (최소 120pt, 최대 160pt)
    private let columns = [
        GridItem(.adaptive(minimum: 120, maximum: 160), spacing: 10)
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(sessions) { session in
                // 직접 딕셔너리 접근으로 SwiftUI 변경 감지 보장
                let request = permissionViewModel.requestsBySessionId[session.id]
                let isRenaming = renamingSession?.id == session.id

                Button {
                    if session.isUnseen {
                        SessionStore.markSessionAsSeen(sessionId: session.id)
                    }
                    onSelect(session)
                } label: {
                    SessionCardView(session: session, style: .compact)
                }
                .buttonStyle(.plain)
                // 권한 요청이 있고 permission 상태일 때만 오버레이 표시
                .overlay(alignment: .bottom) {
                    if let request = request, session.status == .permission {
                        GridPermissionOverlay(
                            request: request,
                            onAllow: { answers in permissionViewModel.allow(request: request, answers: answers) },
                            onDeny: { permissionViewModel.deny(request: request) },
                            onAsk: { permissionViewModel.askClaudeCode(request: request) }
                        )
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                // 권한/선택 요청이 있고 permission 상태일 때 테두리 강조
                .overlay {
                    if request != nil && session.status == .permission {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(Color.orange, lineWidth: 1.5)
                    }
                }
                .commandHoverResume(session: session, cornerRadius: 10)
                .contextMenu {
                    SessionContextMenu(
                        session: session,
                        onChangeStatus: onChangeStatus,
                        onRename: { renamingSession = $0 },
                        onDelete: onDelete
                    )
                }
                .background {
                    // popover를 레이아웃에 영향 없이 표시
                    Color.clear
                        .popover(isPresented: .init(
                            get: { isRenaming },
                            set: { if !$0 { renamingSession = nil } }
                        ), arrowEdge: .top) {
                            SessionLabelEditPopover(
                                session: session,
                                onSave: { newLabel in
                                    onRename?(session, newLabel)
                                    renamingSession = nil
                                },
                                onCancel: {
                                    renamingSession = nil
                                }
                            )
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
    var onToggleFavorite: ((String) -> Void)?
    let onSelectSession: (SessionItem) -> Void
    var onDeleteSession: ((SessionItem) -> Void)?
    var onRenameSession: ((SessionItem, String) -> Void)?
    var onChangeStatus: ((SessionItem, SessionStatus) -> Void)?

    @EnvironmentObject private var permissionViewModel: PermissionRequestViewModel
    @State private var renamingSession: SessionItem?

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
                            isCollapsed: collapsedIds.contains(section.id),
                            isFavorite: section.isFavorite,
                            onFavoriteTap: onToggleFavorite != nil ? {
                                onToggleFavorite?(section.id)
                            } : nil,
                            onTerminalTap: {
                                // section.id가 실제 location 경로 (unknown이 아닌 경우)
                                let location = section.id == "unknown" ? nil : section.id
                                TerminalService.openDirectory(location: location)
                            }
                        )
                    }
                    .buttonStyle(.plain)

                    // 펼쳐진 경우 격자로 세션 표시
                    if !collapsedIds.contains(section.id) {
                        LazyVGrid(columns: columns, spacing: 12) {
                            // 새 세션 추가 카드 (section.id가 실제 location 경로)
                            NewSessionCard(location: section.id == "unknown" ? nil : section.id)

                            // 모든 세션 표시 (권한 요청 있으면 오버레이 추가)
                            ForEach(section.sessions) { session in
                                // 직접 딕셔너리 접근으로 SwiftUI 변경 감지 보장
                                let request = permissionViewModel.requestsBySessionId[session.id]
                                let isRenaming = renamingSession?.id == session.id

                                Button {
                                    if session.isUnseen {
                                        SessionStore.markSessionAsSeen(sessionId: session.id)
                                    }
                                    onSelectSession(session)
                                } label: {
                                    SessionCardView(session: session, style: .compact)
                                }
                                .buttonStyle(.plain)
                                // 권한 요청이 있고 permission 상태일 때만 오버레이 표시
                                .overlay(alignment: .bottom) {
                                    if let request = request, session.status == .permission {
                                        GridPermissionOverlay(
                                            request: request,
                                            onAllow: { answers in permissionViewModel.allow(request: request, answers: answers) },
                                            onDeny: { permissionViewModel.deny(request: request) },
                                            onAsk: { permissionViewModel.askClaudeCode(request: request) }
                                        )
                                    }
                                }
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                // 권한/선택 요청이 있고 permission 상태일 때 테두리 강조
                                .overlay {
                                    if request != nil && session.status == .permission {
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .strokeBorder(Color.orange, lineWidth: 1.5)
                                    }
                                }
                                .commandHoverResume(session: session, cornerRadius: 10)
                                .contextMenu {
                                    SessionContextMenu(
                                        session: session,
                                        onChangeStatus: onChangeStatus,
                                        onRename: { renamingSession = $0 },
                                        onDelete: onDeleteSession
                                    )
                                }
                                .background {
                                    // popover를 레이아웃에 영향 없이 표시
                                    Color.clear
                                        .popover(isPresented: .init(
                                            get: { isRenaming },
                                            set: { if !$0 { renamingSession = nil } }
                                        ), arrowEdge: .top) {
                                            SessionLabelEditPopover(
                                                session: session,
                                                onSave: { newLabel in
                                                    onRenameSession?(session, newLabel)
                                                    renamingSession = nil
                                                },
                                                onCancel: {
                                                    renamingSession = nil
                                                }
                                            )
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

// MARK: - 세션 컨텍스트 메뉴

/// 세션 카드 우클릭 컨텍스트 메뉴 (상태 변경 + 이름 변경 + 삭제)
struct SessionContextMenu: View {
    let session: SessionItem
    var onChangeStatus: ((SessionItem, SessionStatus) -> Void)?
    var onRename: ((SessionItem) -> Void)?
    var onDelete: ((SessionItem) -> Void)?

    var body: some View {
        Button {
            onChangeStatus?(session, .finished)
        } label: {
            Label("완료로 변경", systemImage: "checkmark.circle")
        }
        .disabled(session.status == .finished)

        Button {
            onChangeStatus?(session, .ended)
        } label: {
            Label("종료로 변경", systemImage: "xmark.circle")
        }
        .disabled(session.status == .ended)

        Divider()

        Button {
            onRename?(session)
        } label: {
            Label("이름 변경", systemImage: "pencil")
        }

        Button {
            TerminalService.resumeSession(sessionId: session.id, location: session.locationPath)
        } label: {
            Label("대화 이어하기", systemImage: "terminal")
        }

        Divider()

        Button(role: .destructive) {
            onDelete?(session)
        } label: {
            Label("삭제", systemImage: "trash")
        }
    }
}

// MARK: - 새 세션 카드

/// 새 세션 시작 카드 (+ 버튼) - SessionCardView compact 스타일과 동일한 레이아웃
struct NewSessionCard: View {
    let location: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Spacer(minLength: 0)
            HStack {
                Spacer()
                VStack(spacing: 6) {
                    Image(systemName: "plus")
                        .font(.title2.weight(.medium))
                        .foregroundStyle(.secondary)
                    Text("새 세션")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .aspectRatio(1, contentMode: .fill)
        .background {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.primary.opacity(0.03))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.secondary.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [5]))
        }
        .hoverCardStyle(cornerRadius: 10)
        .onTapGesture {
            TerminalService.startNewSession(location: location)
        }
    }
}

