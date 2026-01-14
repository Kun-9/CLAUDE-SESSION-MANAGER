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
            if let transcript = viewModel.transcript, !transcript.entries.isEmpty {
                let filteredEntries = TranscriptFilter.filteredEntries(
                    transcript.entries,
                    showFullTranscript: showFullTranscript
                )
                SessionTranscriptSplitView(
                    entries: filteredEntries,
                    selectedEntryId: $selectedEntryId,
                    showFullTranscript: $showFullTranscript
                )
            } else {
                if session.lastPrompt != nil || session.lastResponse != nil {
                    SessionSummaryView(prompt: session.lastPrompt, response: session.lastResponse)
                }
                Text("아직 아카이빙된 대화가 없습니다.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
            }
        }
        .padding(18)
        .background(Color(NSColor.windowBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: Color.black.opacity(0.15), radius: 16, x: 0, y: 8)
        .alert("세션을 삭제할까요?", isPresented: $showDeleteConfirmation) {
            Button("취소", role: .cancel) {}
            Button("삭제", role: .destructive) {
                deleteSession()
            }
        } message: {
            Text("이 세션과 대화 기록을 영구히 삭제합니다.")
        }
        .onAppear {
            if let entry = viewModel.transcript?.entries.last {
                selectedEntryId = entry.id
            }
        }
        .onExitCommand {
            close()
        }
        .onChange(of: viewModel.transcript?.entries.count) { _, _ in
            if selectedEntryId == nil, let entry = viewModel.transcript?.entries.last {
                selectedEntryId = entry.id
            }
        }
    }

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
            SessionStatusBadge(status: session.status)
            Button(role: .destructive) {
                showDeleteConfirmation = true
            } label: {
                Label("삭제", systemImage: "trash")
            }
            .buttonStyle(.bordered)
        }
    }

    private func deleteSession() {
        TranscriptArchiveStore.delete(sessionId: session.id)
        SessionStore.deleteSession(sessionId: session.id)
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
