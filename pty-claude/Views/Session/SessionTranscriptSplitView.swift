// MARK: - 파일 설명
// SessionTranscriptSplitView: 대화 내용 분할 뷰
// - 좌측: 대화 목록 (SessionTranscriptListView)
// - 우측: 선택된 대화 상세 (SessionTranscriptDetailView)
// - 실시간 대화 카드 지원 (liveEntryId)

import AppKit
import Foundation
import SwiftUI

// MARK: - Constants

/// 실시간 대화 카드의 고정 ID (UUID(0)으로 고정)
let liveEntryId = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!

// 좌측 목록 + 우측 상세 구성
struct SessionTranscriptSplitView: View {
    let entries: [TranscriptEntry]
    /// 전체 엔트리 (중간 응답 판별용)
    let allEntries: [TranscriptEntry]
    @Binding var selectedEntryId: UUID?
    @Binding var showDetail: Bool

    // 실시간 상태 (liveEntryId 카드에 인디케이터 표시용)
    var isRunning: Bool = false

    var body: some View {
        HStack(spacing: 16) {
            SessionTranscriptListView(
                entries: entries,
                allEntries: allEntries,
                selectedEntryId: $selectedEntryId,
                showDetail: $showDetail,
                isRunning: isRunning
            )
            Divider()
            SessionTranscriptDetailView(
                entries: entries,
                allEntries: allEntries,
                selectedEntryId: $selectedEntryId,
                showDetail: showDetail
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// 좌측 대화 목록 영역 (말풍선 형식)
struct SessionTranscriptListView: View {
    let entries: [TranscriptEntry]
    /// 전체 엔트리 (중간 응답 판별용)
    let allEntries: [TranscriptEntry]
    @Binding var selectedEntryId: UUID?
    @Binding var showDetail: Bool

    // 실시간 상태 (liveEntryId 카드에 인디케이터 표시용)
    var isRunning: Bool = false

    /// 초기 스크롤 완료 여부 (첫 스크롤은 애니메이션 없이)
    @State private var didInitialScroll = false

    var body: some View {
        VStack(spacing: 8) {
            // 토글 (스크롤 영역 밖 - 항상 보임)
            Toggle("상세보기", isOn: $showDetail)
                .toggleStyle(.switch)
                .frame(maxWidth: .infinity, alignment: .leading)

            // 메시지 목록 (말풍선 형식)
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(entries) { entry in
                            messageBubble(for: entry)
                                .id(entry.id)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .scrollIndicators(.never)
                .onAppear {
                    // 초기 스크롤: 마지막 항목으로 즉시 이동
                    scrollToBottom(proxy: proxy, animated: false)
                }
                .onChange(of: entries.count) { oldCount, newCount in
                    // entries가 로드되거나 변경되면 마지막으로 스크롤
                    // 초기 로드 시 (0 -> N) 또는 세션 전환 시
                    if oldCount == 0 && newCount > 0 {
                        scrollToBottom(proxy: proxy, animated: false)
                    }
                }
                .onChange(of: entries.first?.id) { oldValue, newValue in
                    // 첫 번째 엔트리 ID가 변경되면 새 세션으로 간주
                    if oldValue != nil && newValue != nil && oldValue != newValue {
                        didInitialScroll = false
                        scrollToBottom(proxy: proxy, animated: false)
                    }
                }
                .onChange(of: selectedEntryId) { oldValue, newValue in
                    // 사용자가 직접 선택 변경 시에만 스크롤 (자동 선택 제외)
                    guard let id = newValue, didInitialScroll else { return }
                    // 이전 값이 있고 새 값과 다르면 사용자 선택으로 간주
                    if oldValue != nil && oldValue != newValue {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            proxy.scrollTo(id, anchor: .center)
                        }
                    }
                }
            }
        }
        .frame(minWidth: 280, idealWidth: 320, maxWidth: 360)
    }

    /// 목록 최하단으로 스크롤
    private func scrollToBottom(proxy: ScrollViewProxy, animated: Bool) {
        guard let lastId = entries.last?.id else { return }

        if animated {
            withAnimation(.easeInOut(duration: 0.2)) {
                proxy.scrollTo(lastId, anchor: .bottom)
            }
        } else {
            proxy.scrollTo(lastId, anchor: .bottom)
        }

        // 초기 스크롤 완료 후 선택 동기화
        if !didInitialScroll {
            didInitialScroll = true
            // 선택이 없으면 마지막 항목 선택
            if selectedEntryId == nil {
                selectedEntryId = lastId
            }
        }
    }

    // MARK: - Message Bubble Factory

    @ViewBuilder
    private func messageBubble(for entry: TranscriptEntry) -> some View {
        let isLive = entry.id == liveEntryId && isRunning
        let isSelected = entry.id == selectedEntryId

        if entry.role == .system || entry.role == .unknown {
            // 시스템 메시지는 가운데 정렬
            SystemMessageView(
                entry: entry,
                isSelected: isSelected,
                onTap: { selectedEntryId = entry.id }
            )
        } else {
            // User/Assistant는 말풍선 형식
            MessageBubbleView(
                entry: entry,
                allEntries: allEntries,
                showDetail: showDetail,
                isSelected: isSelected,
                isLive: isLive,
                onTap: { selectedEntryId = entry.id }
            )
        }
    }
}

// 우측 상세 텍스트 영역
struct SessionTranscriptDetailView: View {
    let entries: [TranscriptEntry]
    /// 전체 엔트리 (중간 응답 판별용)
    let allEntries: [TranscriptEntry]
    @Binding var selectedEntryId: UUID?
    let showDetail: Bool
    @EnvironmentObject private var toastCenter: ToastCenter

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let selectedEntry = selectedEntry {
                let style = MessageBubbleStyle.from(
                    entry: selectedEntry,
                    allEntries: allEntries,
                    showDetail: showDetail
                )
                HStack {
                    MessageBubbleBadge(label: style.badgeLabel, color: style.badgeColor)
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
                                .fill(style.backgroundColor)
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

