import AppKit
import Foundation
import SwiftUI

// 타임스탬프 표시용 포맷터 (가독성 우선)
private let transcriptTimestampFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy.MM.dd HH:mm"
    return formatter
}()

// 좌측 목록 + 우측 상세 구성
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

// 좌측 대화 목록 영역
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

// 우측 상세 텍스트 영역
struct SessionTranscriptDetailView: View {
    let entries: [TranscriptEntry]
    @Binding var selectedEntryId: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let selectedEntry = selectedEntry {
                HStack {
                    SessionRoleBadge(role: selectedEntry.role)
                    Spacer()
                    if selectedEntry.role == .assistant || selectedEntry.role == .user {
                        // 질문/응답 복사 아이콘 버튼
                        Button {
                            copyToClipboard(selectedEntry.text)
                        } label: {
                            Image(systemName: "doc.on.doc")
                                .font(.system(size: 12, weight: .semibold))
                                .padding(6)
                        }
                        .buttonStyle(.plain)
                        .help("복사")
                        .accessibilityLabel("복사")
                    }
                }
                ScrollView {
                    detailBody(for: selectedEntry)
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

    @ViewBuilder
    private func detailBody(for entry: TranscriptEntry) -> some View {
        if entry.role == .assistant {
            // 응답은 마크다운 렌더링
            MarkdownMessageView(text: entry.text)
        } else {
            // 나머지는 일반 텍스트 렌더링
            Text(entry.text)
                .font(.body)
                .foregroundStyle(.primary)
                .textSelection(.enabled)
        }
    }

    // 클립보드 복사
    private func copyToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
}

// 좌측 목록의 요약 카드
struct SessionTranscriptCard: View {
    let entry: TranscriptEntry
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 6) {
                SessionRoleBadge(role: entry.role)
                Spacer()
                // 배지 오른쪽 상단에 시간 표시
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

    // 목록 카드 타임스탬프 생성
    private var timestampText: String? {
        guard let createdAt = entry.createdAt else {
            return nil
        }
        let date = Date(timeIntervalSince1970: createdAt)
        return transcriptTimestampFormatter.string(from: date)
    }
}

// 역할 라벨 배지
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
