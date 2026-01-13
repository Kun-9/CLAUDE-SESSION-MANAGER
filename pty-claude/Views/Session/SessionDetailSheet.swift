import SwiftUI

struct SessionDetailSheet: View {
    let session: SessionItem
    @StateObject private var viewModel: SessionArchiveViewModel
    @State private var selectedEntryId: UUID?

    init(session: SessionItem) {
        self.session = session
        _viewModel = StateObject(wrappedValue: SessionArchiveViewModel(sessionId: session.id))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            Divider()
            if let transcript = viewModel.transcript, !transcript.entries.isEmpty {
                SessionTranscriptSplitView(
                    entries: transcript.entries,
                    selectedEntryId: $selectedEntryId
                )
            } else {
                if session.lastPrompt != nil || session.lastResponse != nil {
                    SessionSummaryView(prompt: session.lastPrompt, response: session.lastResponse)
                }
                Text("아직 아카이빙된 대화가 없습니다.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(20)
        .frame(minWidth: 760, minHeight: 520)
        .onAppear {
            if let entry = viewModel.transcript?.entries.last {
                selectedEntryId = entry.id
            }
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
            }
            Spacer()
            SessionStatusBadge(status: session.status)
        }
    }
}
