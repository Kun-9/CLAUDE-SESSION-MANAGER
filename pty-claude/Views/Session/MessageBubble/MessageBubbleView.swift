// MARK: - 파일 설명
// MessageBubbleView: 메인 말풍선 컴포넌트
// - User/Assistant 메시지를 말풍선 형태로 표시
// - 역할별 정렬 및 색상 적용
// - 선택/호버/실시간 상태 지원

import SwiftUI

/// 타임스탬프 표시용 포맷터
private let bubbleTimestampFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy.MM.dd HH:mm"
    return formatter
}()

/// 메시지 말풍선 뷰 (User/Assistant용)
struct MessageBubbleView: View {
    let entry: TranscriptEntry
    let allEntries: [TranscriptEntry]
    let showDetail: Bool
    let isSelected: Bool
    let isLive: Bool
    let onTap: () -> Void

    /// 계산된 스타일
    private var style: MessageBubbleStyle {
        MessageBubbleStyle.from(entry: entry, allEntries: allEntries, showDetail: showDetail)
    }

    /// User인지 여부
    private var isUser: Bool {
        style.alignment == .trailing
    }

    var body: some View {
        Button(action: onTap) {
            HStack {
                // 왼쪽 여백 (User만)
                if isUser {
                    Spacer(minLength: 40)
                }

                // 말풍선 본체
                VStack(alignment: style.alignment, spacing: 4) {
                    // 배지 + 시간
                    headerView

                    // 메시지 본문 (말풍선)
                    bubbleContent
                }

                // 오른쪽 여백 (Assistant만)
                if !isUser {
                    Spacer(minLength: 40)
                }
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Subviews

    /// 헤더 (배지 + 타임스탬프)
    private var headerView: some View {
        HStack(spacing: 6) {
            if isUser {
                // User: 시간 -> 배지 (오른쪽 정렬)
                timestampOrIndicator
                MessageBubbleBadge(label: style.badgeLabel, color: style.badgeColor)
            } else {
                // Assistant: 배지 -> 시간 (왼쪽 정렬)
                MessageBubbleBadge(label: style.badgeLabel, color: style.badgeColor)
                timestampOrIndicator
            }
        }
    }

    /// 말풍선 내용
    private var bubbleContent: some View {
        Text(entry.text)
            .font(.subheadline)
            .foregroundStyle(.primary)
            .lineLimit(3)
            .truncationMode(.tail)
            .multilineTextAlignment(isUser ? .trailing : .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(style.backgroundColor)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(isSelected ? Color.accentColor.opacity(0.5) : Color.clear, lineWidth: 2)
            )
            .overlay {
                if isLive {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.green.opacity(0.4), lineWidth: 1.5)
                }
            }
    }

    @ViewBuilder
    private var timestampOrIndicator: some View {
        if isLive {
            TypingIndicatorView(dotColor: .green, dotSize: 6)
        } else if let timestamp = timestampText {
            Text(timestamp)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Helpers

    private var timestampText: String? {
        guard let createdAt = entry.createdAt else {
            return nil
        }
        let date = Date(timeIntervalSince1970: createdAt)
        return bubbleTimestampFormatter.string(from: date)
    }
}

/// 역할 배지 (말풍선용)
struct MessageBubbleBadge: View {
    let label: String
    let color: Color

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
