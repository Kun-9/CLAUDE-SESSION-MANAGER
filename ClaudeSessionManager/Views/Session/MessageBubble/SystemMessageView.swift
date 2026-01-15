// MARK: - 파일 설명
// SystemMessageView: 시스템 메시지 전용 뷰
// - 가운데 정렬, 작은 박스
// - 꼬리 없음, 회색 배경

import SwiftUI

/// 타임스탬프 표시용 포맷터
private let systemTimestampFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy.MM.dd HH:mm"
    return formatter
}()

/// 시스템 메시지 뷰 (가운데 정렬, 작은 박스)
struct SystemMessageView: View {
    let entry: TranscriptEntry
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                // 배지 + 시간
                HStack(spacing: 6) {
                    MessageBubbleBadge(label: "System", color: .gray)
                    if let timestamp = timestampText {
                        Text(timestamp)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                // 메시지 본문
                Text(entry.text)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .truncationMode(.tail)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.gray.opacity(0.08))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(isSelected ? Color.accentColor.opacity(0.5) : Color.clear, lineWidth: 2)
                    )
            }
            .frame(maxWidth: 280)
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, alignment: .center)
    }

    // MARK: - Helpers

    private var timestampText: String? {
        guard let createdAt = entry.createdAt else {
            return nil
        }
        let date = Date(timeIntervalSince1970: createdAt)
        return systemTimestampFormatter.string(from: date)
    }
}
