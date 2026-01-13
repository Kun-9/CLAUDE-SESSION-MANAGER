import SwiftUI

struct SessionTranscriptSplitView: View {
    let entries: [TranscriptEntry]
    @Binding var selectedEntryId: UUID?

    var body: some View {
        HStack(spacing: 16) {
            SessionTranscriptListView(
                entries: entries,
                selectedEntryId: $selectedEntryId
            )
            Divider()
            SessionTranscriptDetailView(
                entries: entries,
                selectedEntryId: $selectedEntryId
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct SessionTranscriptListView: View {
    let entries: [TranscriptEntry]
    @Binding var selectedEntryId: UUID?

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                ForEach(entries) { entry in
                    Button {
                        selectedEntryId = entry.id
                    } label: {
                        SessionTranscriptCard(
                            entry: entry,
                            isSelected: entry.id == selectedEntryId
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 4)
        }
        .frame(minWidth: 260, idealWidth: 280, maxWidth: 320)
    }
}

struct SessionTranscriptDetailView: View {
    let entries: [TranscriptEntry]
    @Binding var selectedEntryId: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let selectedEntry = selectedEntry {
                HStack {
                    SessionRoleBadge(role: selectedEntry.role)
                    if let timestampText = timestampText(for: selectedEntry) {
                        Text(timestampText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                ScrollView {
                    Text(selectedEntry.text)
                        .font(.body)
                        .foregroundStyle(.primary)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(roleColor(for: selectedEntry.role).opacity(0.12))
                        )
                }
            } else {
                Text("메시지를 선택하세요.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var selectedEntry: TranscriptEntry? {
        guard let selectedEntryId else {
            return nil
        }
        return entries.first { $0.id == selectedEntryId }
    }

    private func timestampText(for entry: TranscriptEntry) -> String? {
        guard let createdAt = entry.createdAt else {
            return nil
        }
        let date = Date(timeIntervalSince1970: createdAt)
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func roleColor(for role: TranscriptRole) -> Color {
        switch role {
        case .user:
            return Color.blue
        case .assistant:
            return Color.green
        case .system:
            return Color.gray
        case .unknown:
            return Color.gray
        }
    }
}

struct SessionTranscriptCard: View {
    let entry: TranscriptEntry
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                SessionRoleBadge(role: entry.role)
                Spacer()
                if let timestampText {
                    Text(timestampText)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            Text(entry.text)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .lineLimit(3)
                .truncationMode(.tail)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(isSelected ? Color.accentColor.opacity(0.14) : Color.primary.opacity(0.04))
        )
    }

    private var timestampText: String? {
        guard let createdAt = entry.createdAt else {
            return nil
        }
        let date = Date(timeIntervalSince1970: createdAt)
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct SessionRoleBadge: View {
    let role: TranscriptRole

    var body: some View {
        Text(roleLabel)
            .font(.caption.weight(.semibold))
            .foregroundStyle(roleColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                Capsule(style: .continuous)
                    .fill(roleColor.opacity(0.12))
            )
    }

    private var roleLabel: String {
        switch role {
        case .user:
            return "User"
        case .assistant:
            return "Assistant"
        case .system:
            return "System"
        case .unknown:
            return "Unknown"
        }
    }

    private var roleColor: Color {
        switch role {
        case .user:
            return Color.blue
        case .assistant:
            return Color.green
        case .system:
            return Color.gray
        case .unknown:
            return Color.gray
        }
    }
}
