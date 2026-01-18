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
    /// 성능 최적화: 사전 계산된 엔트리 메타데이터 캐시
    let entryCache: TranscriptEntryCache
    let showDetail: Bool
    let isSelected: Bool
    let isLive: Bool
    let onTap: () -> Void

    /// 계산된 스타일 (캐시 사용)
    private var style: MessageBubbleStyle {
        MessageBubbleStyle.from(entry: entry, entryCache: entryCache, showDetail: showDetail)
    }

    /// User인지 여부
    private var isUser: Bool {
        style.alignment == .trailing
    }

    /// 중간 응답 여부 (캐시 조회, O(1))
    private var isIntermediate: Bool {
        entryCache.isIntermediate[entry.id] ?? false
    }

    /// 누적 토큰 사용량 (캐시 조회, O(1))
    private var cumulativeUsage: TokenUsage? {
        entryCache.cumulativeUsage[entry.id]
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

    /// 헤더 (배지 + 타임스탬프 + 토큰)
    private var headerView: some View {
        HStack(spacing: 6) {
            if isUser {
                // User: 시간 -> 배지 (오른쪽 정렬)
                timestampOrIndicator
                MessageBubbleBadge(label: style.badgeLabel, color: style.badgeColor)
            } else {
                // Assistant: 배지 -> 시간 -> 토큰 (왼쪽 정렬)
                MessageBubbleBadge(label: style.badgeLabel, color: style.badgeColor)
                timestampOrIndicator
                // 토큰 사용량 표시 (Assistant만)
                if let usage = entry.usage {
                    // 최종 응답 여부: 캐시에서 O(1) 조회
                    let isFinal = !isIntermediate
                    TokenUsageBadge(
                        usage: usage,
                        cumulativeUsage: isFinal ? cumulativeUsage : nil
                    )
                }
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

/// 토큰 사용량 배지 (말풍선 헤더용)
struct TokenUsageBadge: View {
    let usage: TokenUsage
    /// 누적 사용량 (최종 응답에만 표시)
    let cumulativeUsage: TokenUsage?
    @State private var isShowingDetail = false

    init(usage: TokenUsage, cumulativeUsage: TokenUsage? = nil) {
        self.usage = usage
        self.cumulativeUsage = cumulativeUsage
    }

    /// 누적 부분 텍스트 (Σ...)
    private var cumulativeText: String? {
        guard let cumulative = cumulativeUsage else { return nil }
        return "(Σ\(TokenUsage.formatTokenCount(cumulative.totalTokens)) · \(TokenUsage.formatTokenCount(Int(cumulative.actualTokenUsage))))"
    }

    var body: some View {
        HStack(spacing: 0) {
            Text(usage.formattedSummary)
                .foregroundStyle(.secondary)
            if let cumText = cumulativeText {
                Text(" " + cumText)
                    .foregroundStyle(.purple)
            }
        }
        .font(.caption2.monospacedDigit())
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(
            Capsule(style: .continuous)
                .fill(Color.secondary.opacity(0.1))
        )
        .onTapGesture {
            isShowingDetail.toggle()
        }
        .popover(isPresented: $isShowingDetail, arrowEdge: .bottom) {
            TokenUsageDetailPopover(usage: usage, cumulativeUsage: cumulativeUsage)
        }
    }
}

/// 토큰 사용량 상세 팝오버
private struct TokenUsageDetailPopover: View {
    let usage: TokenUsage
    let cumulativeUsage: TokenUsage?

    init(usage: TokenUsage, cumulativeUsage: TokenUsage? = nil) {
        self.usage = usage
        self.cumulativeUsage = cumulativeUsage
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Token Usage")
                .font(.caption.bold())
                .foregroundStyle(.primary)

            Divider()

            // 세부 값
            tokenRow(label: "Input", value: usage.inputTokens)
            tokenRow(label: "Output", value: usage.outputTokens)

            if let cacheCreation = usage.cacheCreationInputTokens, cacheCreation > 0 {
                tokenRow(label: "CacheWrite", value: cacheCreation)
            }

            if let cacheRead = usage.cacheReadInputTokens, cacheRead > 0 {
                tokenRow(label: "CacheRead", value: cacheRead)
            }

            Divider()

            // 총 토큰 & 실제 사용량
            tokenRow(label: "Total", value: usage.totalTokens, isBold: true)
            tokenRow(label: "Actual", value: Int(usage.actualTokenUsage), isBold: true, color: .blue)

            // 누적 (최종 응답에만)
            if let cumulative = cumulativeUsage {
                Divider()
                tokenRow(label: "Σ Total", value: cumulative.totalTokens, isBold: true, color: .purple)
                tokenRow(label: "Σ Actual", value: Int(cumulative.actualTokenUsage), isBold: true, color: .purple)
            }

            Divider()

            // 공식
            VStack(alignment: .leading, spacing: 2) {
                Text("Total = 총 토큰 수")
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundStyle(.primary)
                Text("Actual = 실제 비용 (캐시 가중치 적용)")
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundStyle(.blue)
                if cumulativeUsage != nil {
                    Text("Σ = 프롬프트 내 모든 응답 합계")
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundStyle(.purple)
                }
            }
        }
        .padding(12)
        .frame(minWidth: 200)
    }

    @ViewBuilder
    private func tokenRow(label: String, value: Int, isBold: Bool = false, color: Color = .primary) -> some View {
        HStack {
            Text(label)
                .font(isBold ? .caption.bold() : .caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text(formatNumber(value))
                .font(isBold ? .caption.bold().monospacedDigit() : .caption.monospacedDigit())
                .foregroundStyle(isBold ? color : .secondary)
        }
    }

    private func formatNumber(_ value: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }
}
