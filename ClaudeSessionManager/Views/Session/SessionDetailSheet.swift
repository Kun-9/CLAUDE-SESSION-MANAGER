// MARK: - 파일 설명
// SessionDetailSheet: 세션 상세 시트
// - 아카이브된 대화 내용 표시 (SessionTranscriptSplitView)
// - 실시간 대화 상태 통합 (liveEntry)
// - 세션 삭제 기능

import AppKit
import SwiftUI

struct SessionDetailSheet: View {
    let session: SessionItem
    let onClose: (() -> Void)?
    @StateObject private var viewModel: SessionArchiveViewModel
    @State private var selectedEntryId: UUID?
    @State private var showDeleteConfirmation = false
    @State private var showDetail = false
    @Environment(\.dismiss) private var dismiss

    init(session: SessionItem, onClose: (() -> Void)? = nil) {
        self.session = session
        self.onClose = onClose
        _viewModel = StateObject(wrappedValue: SessionArchiveViewModel(sessionId: session.id))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            Divider()
            conversationContent
        }
        .padding(18)
        .background(Color(NSColor.windowBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: Color.black.opacity(0.15), radius: 16, x: 0, y: 8)
        .confirmationDialog(
            "세션 삭제",
            isPresented: $showDeleteConfirmation
        ) {
            Button("삭제", role: .destructive) {
                deleteSession()
            }
        } message: {
            Text(deleteConfirmationMessage)
        }
        .onExitCommand {
            close()
        }
    }

    // MARK: - Conversation Content

    /// 대화 컨텐츠 영역 - 항상 SplitView 사용 (레이아웃 변경으로 인한 깜빡임 방지)
    private var conversationContent: some View {
        SessionTranscriptSplitView(
            entries: combinedEntries,
            allEntries: allEntries,
            selectedEntryId: $selectedEntryId,
            showDetail: $showDetail,
            isRunning: viewModel.isRunning
        )
    }

    /// 전체 엔트리 (중간 응답 판별용)
    private var allEntries: [TranscriptEntry] {
        viewModel.transcript?.entries ?? []
    }

    /// 아카이브된 entries + 실시간 entry 통합 (필터링 적용)
    private var combinedEntries: [TranscriptEntry] {
        var entries = TranscriptFilter.filteredEntries(
            allEntries,
            showDetail: showDetail
        )
        if let liveEntry = viewModel.liveEntry {
            entries.append(liveEntry)
        }
        return entries
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                Text(session.name)
                    .font(.title3.weight(.semibold))
                Text(session.detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                HStack(spacing: 12) {
                    if let archiveSizeText = viewModel.archiveSizeText {
                        Text("아카이브 \(archiveSizeText)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    // 세션 전체 토큰 사용량
                    if let totalUsage = viewModel.transcript?.totalUsage {
                        TokenUsageBadge(usage: totalUsage)
                    }
                }
            }
            Spacer()
            SessionStatusBadge(status: viewModel.currentSession?.status ?? session.status)
            Button {
                TerminalService.resumeSession(sessionId: session.id, location: session.location)
            } label: {
                Label("대화 이어하기", systemImage: "terminal")
            }
            .buttonStyle(.bordered)
            Button(role: .destructive) {
                showDeleteConfirmation = true
            } label: {
                Label("삭제", systemImage: "trash")
            }
            .buttonStyle(.bordered)
        }
    }

    private var deleteConfirmationMessage: String {
        var message = "'\(session.name)' 세션을 삭제하시겠습니까?\n"
        message += "Claude Code 세션 파일과 아카이브가 모두 삭제되며 복구할 수 없습니다."
        if viewModel.isRunning {
            message += "\n\n⚠️ 현재 진행 중인 세션입니다."
        }
        return message
    }

    private func deleteSession() {
        viewModel.deleteSession()
        close()
    }

    private func close() {
        if let onClose {
            onClose()
        } else {
            dismiss()
        }
    }
}
