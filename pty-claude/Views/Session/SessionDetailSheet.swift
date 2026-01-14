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
    @State private var showFullTranscript = false
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
            Text("'\(session.name)' 세션을 삭제하시겠습니까?\n아카이브된 대화 기록도 함께 삭제됩니다.")
        }
        .onAppear {
            selectDefaultEntryIfNeeded()
        }
        .onExitCommand {
            close()
        }
        .onChange(of: viewModel.transcript?.entries.count) { _, _ in
            // transcript 업데이트 시 적절한 항목 선택
            selectDefaultEntryIfNeeded()
        }
        .onChange(of: viewModel.isRunning) { _, _ in
            // running 상태 변경 시 적절한 항목 선택
            selectDefaultEntryIfNeeded()
        }
    }

    // MARK: - Conversation Content

    /// 대화 컨텐츠 영역 - 항상 SplitView 사용 (레이아웃 변경으로 인한 깜빡임 방지)
    private var conversationContent: some View {
        SessionTranscriptSplitView(
            entries: combinedEntries,
            selectedEntryId: $selectedEntryId,
            showFullTranscript: $showFullTranscript,
            isRunning: viewModel.isRunning
        )
    }

    /// 아카이브된 entries + 실시간 entry 통합
    private var combinedEntries: [TranscriptEntry] {
        var entries = TranscriptFilter.filteredEntries(
            viewModel.transcript?.entries ?? [],
            showFullTranscript: showFullTranscript
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
                if let archiveSizeText = viewModel.archiveSizeText {
                    Text("아카이브 \(archiveSizeText)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            SessionStatusBadge(status: viewModel.currentSession?.status ?? session.status)
            Button(role: .destructive) {
                showDeleteConfirmation = true
            } label: {
                Label("삭제", systemImage: "trash")
            }
            .buttonStyle(.bordered)
        }
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

    /// 적절한 항목이 선택되도록 보장 (combinedEntries 기반)
    private func selectDefaultEntryIfNeeded() {
        let allEntries = combinedEntries

        // 현재 선택이 유효한지 확인
        let isCurrentSelectionValid = selectedEntryId.map { id in
            allEntries.contains { $0.id == id }
        } ?? false

        // 유효하지 않으면 마지막 항목 선택
        if !isCurrentSelectionValid {
            withAnimation {
                selectedEntryId = allEntries.last?.id
            }
        }
    }
}
