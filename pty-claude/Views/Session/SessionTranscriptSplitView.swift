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
    @Binding var showFullTranscript: Bool

    var body: some View {
        HStack(spacing: 16) {
            SessionTranscriptListView(
                entries: entries,
                selectedEntryId: $selectedEntryId,
                showFullTranscript: $showFullTranscript
            )
            Divider()
            SessionTranscriptDetailView(
                entries: entries,
                selectedEntryId: $selectedEntryId,
                showFullTranscript: showFullTranscript
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// 좌측 대화 목록 영역
struct SessionTranscriptListView: View {
    let entries: [TranscriptEntry]
    @Binding var selectedEntryId: UUID?
    @Binding var showFullTranscript: Bool

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                Toggle("상세보기", isOn: $showFullTranscript)
                    .toggleStyle(.switch)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, 4)
                ForEach(entries) { entry in
                    Button {
                        selectedEntryId = entry.id
                    } label: {
                        SessionTranscriptCard(
                            entry: entry,
                            isSelected: entry.id == selectedEntryId,
                            showFullTranscript: showFullTranscript
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 4)
        }
        .scrollIndicators(.never)
        .frame(minWidth: 260, idealWidth: 280, maxWidth: 320)
    }
}

// 우측 상세 텍스트 영역
struct SessionTranscriptDetailView: View {
    let entries: [TranscriptEntry]
    @Binding var selectedEntryId: UUID?
    let showFullTranscript: Bool
    @EnvironmentObject private var toastCenter: ToastCenter

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let selectedEntry = selectedEntry {
                let badgeInfo = roleBadgeInfo(for: selectedEntry, showFullTranscript: showFullTranscript)
                HStack {
                    SessionRoleBadge(label: badgeInfo.label, color: badgeInfo.color)
                    Spacer()
                    if selectedEntry.role == .assistant || selectedEntry.role == .user {
                        // 질문/응답 복사 아이콘 버튼
                        Button {
                            ClipboardService.copy(selectedEntry.text)
                            toastCenter.show("클립보드에 복사됨")
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

}

// 좌측 목록의 요약 카드
struct SessionTranscriptCard: View {
    let entry: TranscriptEntry
    let isSelected: Bool
    let showFullTranscript: Bool

    var body: some View {
        let badgeInfo = roleBadgeInfo(for: entry, showFullTranscript: showFullTranscript)
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 6) {
                SessionRoleBadge(label: badgeInfo.label, color: badgeInfo.color)
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
        .hoverCardStyle(
            cornerRadius: 12,
            baseStrokeOpacity: 0.04,
            hoverStrokeOpacity: 0.12,
            baseShadowOpacity: 0.04,
            hoverShadowOpacity: 0.1,
            shadowRadius: 6,
            shadowYOffset: 3
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
    let label: String
    let color: Color

    init(role: TranscriptRole) {
        let info = roleBadgeInfo(for: role)
        self.label = info.label
        self.color = info.color
    }

    init(label: String, color: Color) {
        self.label = label
        self.color = color
    }

    var body: some View {
        Text(label)
            .font(.caption.weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                Capsule(style: .continuous)
                    .fill(color.opacity(0.12))
            )
    }
}

private func roleBadgeInfo(for entry: TranscriptEntry, showFullTranscript: Bool) -> (label: String, color: Color) {
    if showFullTranscript, entry.role == .user, !TranscriptFilter.isDirectUserInput(entry) {
        return (label: "Detail", color: Color.orange)
    }
    return roleBadgeInfo(for: entry.role)
}

private func roleBadgeInfo(for role: TranscriptRole) -> (label: String, color: Color) {
    switch role {
    case .user:
        return (label: "User", color: Color.blue)
    case .assistant:
        return (label: "Assistant", color: Color.green)
    case .system:
        return (label: "System", color: Color.gray)
    case .unknown:
        return (label: "Unknown", color: Color.gray)
    }
}
