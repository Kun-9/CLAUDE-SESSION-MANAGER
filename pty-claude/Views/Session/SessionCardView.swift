// MARK: - 파일 설명
// SessionCardView: 세션 카드 UI 컴포넌트
// - full: 기존 가로형 카드 (Q/A 요약 포함)
// - compact: 격자용 컴팩트 카드 (세션명, 상태, 시간만 표시)

import AppKit
import Combine
import SwiftUI

/// 세션 카드 표시 스타일
enum SessionCardStyle {
    case full      // 기존 리스트용 (Q/A 요약 포함)
    case compact   // 격자용 컴팩트 (세션명, 상태, 시간만)
}

struct SessionCardView: View {
    let session: SessionItem
    let style: SessionCardStyle
    @State private var cardWidth: CGFloat = 0

    /// 기본 생성자 (기존 코드 호환성)
    init(session: SessionItem, style: SessionCardStyle = .full) {
        self.session = session
        self.style = style
    }

    /// 소요 시간 포맷 (분:초)
    private func formatDuration(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds))
        let mins = total / 60
        let secs = total % 60
        return String(format: "%d:%02d", mins, secs)
    }

    var body: some View {
        switch style {
        case .full:
            fullCardContent
        case .compact:
            compactCardContent
        }
    }

    // MARK: - Full Card (기존 레이아웃)

    @ViewBuilder
    private var fullCardContent: some View {
        HStack(spacing: 14) {
            SessionStatusBar(status: session.status)
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(session.name)
                        .font(.headline)
                    Spacer()
                    SessionStatusBadge(status: session.status)
                }
                Text(session.detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                if session.lastPrompt != nil || session.lastResponse != nil {
                    SessionSummaryView(
                        prompt: session.lastPrompt,
                        response: session.lastResponse
                    )
                    .frame(
                        width: cardWidth > 0 ? cardWidth * 0.85 : nil,
                        alignment: .leading
                    )
                }
                if session.status == .running, let startedAt = session.startedAt {
                    ElapsedTimeText(startedAt: startedAt)
                        .font(.caption)
                } else {
                    HStack {
                        Text("Updated \(session.updatedText)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if let duration = session.duration {
                            Spacer()
                            Text(formatDuration(duration))
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
        .background { fullCardBackground }
        .onPreferenceChange(SessionCardWidthKey.self) { cardWidth = $0 }
        .overlay(alignment: .bottomTrailing) {
            if session.status == .running {
                RunningProgressIndicator(tint: session.status.tint)
                    .padding(.trailing, 12)
                    .padding(.bottom, 10)
            }
        }
        .hoverCardStyle(cornerRadius: 18)
    }

    @ViewBuilder
    private var fullCardBackground: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(LinearGradient(
                    colors: [
                        session.status.background,
                        Color(NSColor.windowBackgroundColor),
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                ))
            GeometryReader { proxy in
                Color.clear
                    .preference(key: SessionCardWidthKey.self, value: proxy.size.width)
            }
        }
    }

    // MARK: - Compact Card (격자용)

    @ViewBuilder
    private var compactCardContent: some View {
        VStack(alignment: .leading, spacing: 4) {
            // 세션명 (메인)
            Text(session.name)
                .font(.system(size: 12, weight: .medium))
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)

            // 키워드/요약 (lastPrompt에서 추출)
            if let prompt = session.lastPrompt, !prompt.isEmpty {
                Text(prompt)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Spacer(minLength: 0)

            // 하단: 시간 + 상태 인디케이터
            HStack(spacing: 4) {
                if session.status == .running, let startedAt = session.startedAt {
                    ElapsedTimeText(startedAt: startedAt)
                } else {
                    VStack(alignment: .leading, spacing: 2) {
                        if let duration = session.duration {
                            Text(formatDuration(duration))
                                .font(.system(size: 10, weight: .medium).monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                        Text(session.updatedText)
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                    }
                }
                Spacer()
                CompactStatusIndicator(status: session.status)
            }
        }
        .padding(10)
        .aspectRatio(1, contentMode: .fill)
        .background {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(session.status.background)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(session.status.tint.opacity(0.3), lineWidth: 1)
        }
        .hoverCardStyle(cornerRadius: 10)
    }
}

// MARK: - 경과 시간 텍스트 (실시간 업데이트)

private struct ElapsedTimeText: View {
    let startedAt: TimeInterval
    @State private var elapsed: TimeInterval = 0

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        Text(formatElapsed(elapsed))
            .font(.system(size: 10, weight: .medium).monospacedDigit())
            .foregroundStyle(.secondary)
            .onAppear {
                elapsed = Date().timeIntervalSince1970 - startedAt
            }
            .onReceive(timer) { _ in
                elapsed = Date().timeIntervalSince1970 - startedAt
            }
    }

    private func formatElapsed(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds))
        let mins = total / 60
        let secs = total % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

// MARK: - 컴팩트 상태 인디케이터

private struct CompactStatusIndicator: View {
    let status: SessionStatus
    @State private var isPulsing = false

    var body: some View {
        Circle()
            .fill(status.tint)
            .frame(width: 6, height: 6)
            .overlay {
                if status == .running {
                    Circle()
                        .stroke(status.tint, lineWidth: 1.5)
                        .frame(width: 6, height: 6)
                        .scaleEffect(isPulsing ? 2.2 : 1)
                        .opacity(isPulsing ? 0 : 0.8)
                        .animation(
                            .easeOut(duration: 1.0).repeatForever(autoreverses: false),
                            value: isPulsing
                        )
                }
            }
            .onAppear {
                if status == .running {
                    isPulsing = true
                }
            }
    }
}

private struct SessionCardWidthKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}
