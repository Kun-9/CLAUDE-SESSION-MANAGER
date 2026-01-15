// MARK: - 파일 설명
// PermissionRequestView: 권한 요청 선택 UI
// - 대기 중인 권한 요청 목록 표시
// - Allow/Deny 버튼으로 사용자 선택

import Combine
import SwiftUI

// MARK: - PermissionRequestViewModel

/// 권한 요청 UI 상태 관리
@MainActor
final class PermissionRequestViewModel: ObservableObject {
    @Published var pendingRequests: [PermissionRequest] = []

    private var observer: NSObjectProtocol?
    private var refreshTimer: Timer?

    init() {
        loadPendingRequests()
        startObserving()
        startPeriodicRefresh()
    }

    deinit {
        if let observer = observer {
            DistributedNotificationCenter.default().removeObserver(observer)
        }
        refreshTimer?.invalidate()
    }

    /// 대기 중인 요청 로드
    func loadPendingRequests() {
        pendingRequests = PermissionRequestStore.loadPendingRequests()
    }

    /// 요청 허용 (선택지 응답 포함)
    func allow(request: PermissionRequest, answers: [String: String]? = nil) {
        PermissionRequestStore.saveResponse(
            requestId: request.id,
            decision: .allow,
            answers: answers
        )
        loadPendingRequests()
    }

    /// 요청 거부
    func deny(request: PermissionRequest, message: String? = nil) {
        PermissionRequestStore.saveResponse(
            requestId: request.id,
            decision: .deny,
            message: message ?? "사용자가 거부함"
        )
        loadPendingRequests()
    }

    /// Claude Code UI로 위임 (아무 응답 안 함)
    func askClaudeCode(request: PermissionRequest) {
        PermissionRequestStore.saveResponse(
            requestId: request.id,
            decision: .ask
        )
        loadPendingRequests()
    }

    /// 알림 감시 시작
    private func startObserving() {
        observer = DistributedNotificationCenter.default().addObserver(
            forName: PermissionRequestStore.permissionRequestAddedNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor [weak self] in
                self?.loadPendingRequests()
            }
        }
    }

    /// 주기적 새로고침 (터미널에서 처리된 경우 감지)
    private func startPeriodicRefresh() {
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor [weak self] in
                self?.loadPendingRequests()
            }
        }
    }
}

// MARK: - PermissionRequestBannerView

/// 권한 요청 배너 (메인 뷰 상단에 표시)
struct PermissionRequestBannerView: View {
    @StateObject private var viewModel = PermissionRequestViewModel()
    @State private var expandedRequestId: String?

    var body: some View {
        if !viewModel.pendingRequests.isEmpty {
            VStack(spacing: 8) {
                ForEach(viewModel.pendingRequests) { request in
                    PermissionRequestCard(
                        request: request,
                        isExpanded: expandedRequestId == request.id,
                        onToggleExpand: {
                            withAnimation(.spring(response: 0.3)) {
                                if expandedRequestId == request.id {
                                    expandedRequestId = nil
                                } else {
                                    expandedRequestId = request.id
                                }
                            }
                        },
                        onAllow: { answers in viewModel.allow(request: request, answers: answers) },
                        onDeny: { viewModel.deny(request: request) },
                        onAsk: { viewModel.askClaudeCode(request: request) }
                    )
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.8))
        }
    }
}

// MARK: - PermissionRequestCard

/// 개별 권한 요청 카드
private struct PermissionRequestCard: View {
    let request: PermissionRequest
    let isExpanded: Bool
    let onToggleExpand: () -> Void
    let onAllow: ([String: String]?) -> Void
    let onDeny: () -> Void
    let onAsk: () -> Void

    @State private var selectedOptions: [Int: String] = [:]  // 질문 인덱스 -> 선택된 label
    @State private var customInputs: [Int: String] = [:]  // 질문 인덱스 -> 직접 입력 텍스트
    @State private var isOtherSelected: [Int: Bool] = [:]  // 질문 인덱스 -> Other 선택 여부

    /// 선택지가 있고, 모든 필수 질문에 응답했는지
    private var canSubmitWithAnswers: Bool {
        guard let questions = request.questions, !questions.isEmpty else { return false }
        // 모든 질문에 답했는지 확인
        for (index, _) in questions.enumerated() {
            let hasSelection = selectedOptions[index] != nil
            let hasOtherInput = isOtherSelected[index] == true && !(customInputs[index]?.isEmpty ?? true)
            if !hasSelection && !hasOtherInput {
                return false
            }
        }
        return true
    }

    /// 선택 결과를 answers 딕셔너리로 변환
    private var answersDict: [String: String]? {
        guard canSubmitWithAnswers else { return nil }
        guard let questions = request.questions else { return nil }
        var result: [String: String] = [:]
        for (index, _) in questions.enumerated() {
            if isOtherSelected[index] == true, let customText = customInputs[index], !customText.isEmpty {
                // 직접 입력한 경우
                result["\(index)"] = customText
            } else if let label = selectedOptions[index] {
                // 선택지에서 선택한 경우
                result["\(index)"] = label
            }
        }
        return result
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 헤더
            HStack {
                Image(systemName: request.hasQuestions ? "questionmark.circle.fill" : "exclamationmark.shield.fill")
                    .foregroundStyle(request.hasQuestions ? .blue : .orange)
                    .font(.title3)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(request.hasQuestions ? "선택 요청" : "권한 요청")
                            .font(.headline)
                        // 세션 이름 배지
                        Text(request.displayName)
                            .font(.caption.weight(.medium))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(Color.blue.opacity(0.15)))
                            .foregroundStyle(.blue)
                    }
                    Text(request.toolName)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    onToggleExpand()
                } label: {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                }
                .buttonStyle(.plain)
            }

            // 선택지 UI (questions가 있을 때)
            if let questions = request.questions, !questions.isEmpty {
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(Array(questions.enumerated()), id: \.offset) { index, question in
                        QuestionSelectionView(
                            question: question,
                            selectedLabel: selectedOptions[index],
                            isOtherSelected: isOtherSelected[index] ?? false,
                            customInput: Binding(
                                get: { customInputs[index] ?? "" },
                                set: { customInputs[index] = $0 }
                            ),
                            onSelect: { label in
                                selectedOptions[index] = label
                                isOtherSelected[index] = false
                            },
                            onSelectOther: {
                                selectedOptions[index] = nil
                                isOtherSelected[index] = true
                            }
                        )
                    }
                }
                .padding(.vertical, 8)
            }

            // 확장된 정보
            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    if let cwd = request.cwd {
                        HStack {
                            Text("위치:")
                                .foregroundStyle(.secondary)
                            Text(cwd)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                        .font(.caption)
                    }

                    HStack {
                        Text("세션:")
                            .foregroundStyle(.secondary)
                        Text(request.sessionId)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    .font(.caption)
                }
                .padding(.leading, 28)
            }

            // 버튼
            if request.hasQuestions {
                // 선택지가 있는 경우: Submit 버튼
                HStack(spacing: 12) {
                    Button {
                        onAllow(answersDict)
                    } label: {
                        Label("Submit", systemImage: "paperplane.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)
                    .disabled(!canSubmitWithAnswers)

                    Button {
                        onAsk()
                    } label: {
                        Label("터미널에서", systemImage: "terminal")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .help("Claude Code 터미널에서 직접 선택")
                }
            } else {
                // 단순 권한 요청: Allow/Deny/Ask 버튼
                HStack(spacing: 12) {
                    Button {
                        onAllow(nil)
                    } label: {
                        Label("Allow", systemImage: "checkmark.circle.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)

                    Button {
                        onDeny()
                    } label: {
                        Label("Deny", systemImage: "xmark.circle.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)

                    Button {
                        onAsk()
                    } label: {
                        Label("Ask", systemImage: "questionmark.circle")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .help("Claude Code에서 직접 선택")
                }
            }
        }
        .padding()
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(NSColor.windowBackgroundColor))
                .shadow(color: request.hasQuestions ? .blue.opacity(0.3) : .orange.opacity(0.3), radius: 8)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(request.hasQuestions ? Color.blue.opacity(0.5) : Color.orange.opacity(0.5), lineWidth: 2)
        }
    }
}

// MARK: - InlinePermissionRequestView

/// 세션 카드 아래에 인라인으로 표시되는 권한 요청 UI
struct InlinePermissionRequestView: View {
    let request: PermissionRequest
    let onAllow: ([String: String]?) -> Void
    let onDeny: () -> Void
    let onAsk: () -> Void

    @State private var selectedOptions: [Int: Set<String>] = [:]  // multiSelect 지원
    @State private var customInputs: [Int: String] = [:]
    @State private var isOtherSelected: [Int: Bool] = [:]

    private var canSubmitWithAnswers: Bool {
        guard let questions = request.questions, !questions.isEmpty else { return false }
        for (index, _) in questions.enumerated() {
            let hasSelection = !(selectedOptions[index]?.isEmpty ?? true)
            let hasOtherInput = isOtherSelected[index] == true && !(customInputs[index]?.isEmpty ?? true)
            if !hasSelection && !hasOtherInput {
                return false
            }
        }
        return true
    }

    private var answersDict: [String: String]? {
        guard canSubmitWithAnswers else { return nil }
        guard let questions = request.questions else { return nil }
        var result: [String: String] = [:]
        for (index, _) in questions.enumerated() {
            if isOtherSelected[index] == true, let customText = customInputs[index], !customText.isEmpty {
                result["\(index)"] = customText
            } else if let labels = selectedOptions[index], !labels.isEmpty {
                // multiSelect: 쉼표로 구분된 문자열
                result["\(index)"] = labels.sorted().joined(separator: ", ")
            }
        }
        return result
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 헤더: 타입 + 도구명 + 타이머
            HStack {
                Image(systemName: request.hasQuestions ? "questionmark.circle.fill" : "exclamationmark.shield.fill")
                    .foregroundStyle(request.hasQuestions ? .blue : .orange)
                    .font(.subheadline)

                Text(request.hasQuestions ? "선택 요청" : "권한 요청")
                    .font(.subheadline.weight(.medium))

                Text("• \(request.toolName)")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()
            }

            // 선택지 UI (questions가 있을 때)
            if let questions = request.questions, !questions.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(Array(questions.enumerated()), id: \.offset) { index, question in
                        InlineQuestionSelectionView(
                            question: question,
                            selectedLabels: selectedOptions[index] ?? [],
                            isOtherSelected: isOtherSelected[index] ?? false,
                            customInput: Binding(
                                get: { customInputs[index] ?? "" },
                                set: { customInputs[index] = $0 }
                            ),
                            onToggle: { label in
                                // multiSelect: 토글, 단일선택: 교체
                                if question.multiSelect {
                                    var current = selectedOptions[index] ?? []
                                    if current.contains(label) {
                                        current.remove(label)
                                    } else {
                                        current.insert(label)
                                    }
                                    selectedOptions[index] = current
                                } else {
                                    selectedOptions[index] = [label]
                                }
                                isOtherSelected[index] = false
                            },
                            onSelectOther: {
                                selectedOptions[index] = []
                                isOtherSelected[index] = true
                            }
                        )
                    }
                }
            }

            // 버튼
            if request.hasQuestions {
                HStack(spacing: 8) {
                    Button {
                        onAllow(answersDict)
                    } label: {
                        Label("Submit", systemImage: "paperplane.fill")
                            .font(.subheadline)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(canSubmitWithAnswers ? .blue : .gray)
                    .disabled(!canSubmitWithAnswers)
                    .opacity(canSubmitWithAnswers ? 1.0 : 0.5)
                    .controlSize(.small)

                    Button {
                        onAsk()
                    } label: {
                        Label("터미널", systemImage: "terminal")
                            .font(.subheadline)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            } else {
                HStack(spacing: 8) {
                    Button {
                        onAllow(nil)
                    } label: {
                        Label("Allow", systemImage: "checkmark.circle.fill")
                            .font(.subheadline)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                    .controlSize(.small)

                    Button {
                        onDeny()
                    } label: {
                        Label("Deny", systemImage: "xmark.circle.fill")
                            .font(.subheadline)
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                    .controlSize(.small)

                    Button {
                        onAsk()
                    } label: {
                        Label("Ask", systemImage: "questionmark.circle")
                            .font(.subheadline)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
        }
        .padding(12)
        .background {
            UnevenRoundedRectangle(
                topLeadingRadius: 0,
                bottomLeadingRadius: 14,
                bottomTrailingRadius: 14,
                topTrailingRadius: 0
            )
            .fill(request.hasQuestions
                ? Color.blue.opacity(0.08)
                : Color.orange.opacity(0.08))
        }
        .overlay {
            UnevenRoundedRectangle(
                topLeadingRadius: 0,
                bottomLeadingRadius: 14,
                bottomTrailingRadius: 14,
                topTrailingRadius: 0
            )
            .strokeBorder(
                request.hasQuestions ? Color.blue.opacity(0.3) : Color.orange.opacity(0.3),
                lineWidth: 1
            )
        }
        .padding(.horizontal, 16)
    }
}

// MARK: - OptionChipView

/// 호버된 툴팁 정보
private struct HoveredTooltip: Equatable {
    let description: String
    let frame: CGRect  // 글로벌 좌표
}

/// 옵션 칩 뷰 (호버 시 좌표 전달)
private struct OptionChipView: View {
    let option: PermissionOption
    let isSelected: Bool
    let isMultiSelect: Bool
    let onTap: () -> Void
    let onHoverChange: (CGRect?) -> Void  // nil = 호버 해제

    @State private var isHovered: Bool = false
    @State private var currentFrame: CGRect = .zero

    var body: some View {
        Button {
            onTap()
        } label: {
            HStack(spacing: 4) {
                if isMultiSelect {
                    Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                        .font(.caption2)
                }
                Text(option.label)
                    .font(.caption)
                // description이 있으면 info 아이콘 표시
                if option.description != nil, !option.description!.isEmpty {
                    Image(systemName: "info.circle")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background {
                Capsule()
                    .fill(isSelected
                        ? Color.blue.opacity(0.2)
                        : isHovered
                            ? Color.blue.opacity(0.1)
                            : Color(NSColor.controlBackgroundColor))
            }
            .overlay {
                Capsule()
                    .strokeBorder(isSelected
                        ? Color.blue
                        : isHovered
                            ? Color.blue.opacity(0.5)
                            : Color.clear, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .background {
            GeometryReader { geo in
                Color.clear
                    .onAppear { currentFrame = geo.frame(in: .global) }
                    .onChange(of: geo.frame(in: .global)) { _, newFrame in
                        currentFrame = newFrame
                    }
            }
        }
        .onHover { hovering in
            isHovered = hovering
            if hovering {
                onHoverChange(currentFrame)
            } else {
                onHoverChange(nil)
            }
        }
    }
}

// MARK: - InlineQuestionSelectionView

/// 인라인 권한 요청용 컴팩트 질문 선택 UI
private struct InlineQuestionSelectionView: View {
    let question: PermissionQuestion
    let selectedLabels: Set<String>  // multiSelect 지원
    let isOtherSelected: Bool
    @Binding var customInput: String
    let onToggle: (String) -> Void  // 토글 (multiSelect) 또는 선택 (단일)
    let onSelectOther: () -> Void

    @FocusState private var isTextFieldFocused: Bool
    @State private var hoveredTooltip: HoveredTooltip?
    @State private var containerFrame: CGRect = .zero

    /// 옵션이 선택되었는지 확인
    private func isSelected(_ label: String) -> Bool {
        selectedLabels.contains(label) && !isOtherSelected
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // 질문 텍스트 + multiSelect 표시
            HStack(spacing: 4) {
                if let questionText = question.question {
                    Text(questionText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if question.multiSelect {
                    Text("(복수 선택)")
                        .font(.caption2)
                        .foregroundStyle(.blue)
                }
            }

            // 옵션들 (가로 스크롤 칩 형태)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(question.options) { option in
                        OptionChipView(
                            option: option,
                            isSelected: isSelected(option.label),
                            isMultiSelect: question.multiSelect,
                            onTap: { onToggle(option.label) },
                            onHoverChange: { frame in
                                if let frame = frame,
                                   let desc = option.description,
                                   !desc.isEmpty {
                                    hoveredTooltip = HoveredTooltip(description: desc, frame: frame)
                                } else {
                                    hoveredTooltip = nil
                                }
                            }
                        )
                    }

                    // Other 칩
                    Button {
                        onSelectOther()
                        isTextFieldFocused = true
                    } label: {
                        Text("Other")
                            .font(.caption)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background {
                                Capsule()
                                    .fill(isOtherSelected
                                        ? Color.blue.opacity(0.2)
                                        : Color(NSColor.controlBackgroundColor))
                            }
                            .overlay {
                                Capsule()
                                    .strokeBorder(isOtherSelected
                                        ? Color.blue
                                        : Color.clear, lineWidth: 1)
                            }
                    }
                    .buttonStyle(.plain)
                }
            }

            // Other 텍스트 필드
            if isOtherSelected {
                TextField("직접 입력...", text: $customInput)
                    .textFieldStyle(.plain)
                    .font(.caption)
                    .padding(8)
                    .background {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color(NSColor.textBackgroundColor))
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(Color.blue.opacity(0.5), lineWidth: 1)
                    }
                    .focused($isTextFieldFocused)
            }
        }
        .background {
            GeometryReader { geo in
                Color.clear
                    .onAppear { containerFrame = geo.frame(in: .global) }
                    .onChange(of: geo.frame(in: .global)) { _, newFrame in
                        containerFrame = newFrame
                    }
            }
        }
        .overlay(alignment: .topLeading) {
            // 툴팁 오버레이
            if let tooltip = hoveredTooltip, containerFrame != .zero {
                HStack(spacing: 4) {
                    Image(systemName: "info.circle.fill")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.7))
                    Text(tooltip.description)
                        .font(.caption2)
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.black)
                }
                .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
                .offset(
                    x: tooltip.frame.minX - containerFrame.minX,
                    y: tooltip.frame.maxY - containerFrame.minY + 4
                )
                .allowsHitTesting(false)
                .zIndex(1000)
            }
        }
    }
}

// MARK: - QuestionSelectionView

/// 개별 질문의 선택지 UI
private struct QuestionSelectionView: View {
    let question: PermissionQuestion
    let selectedLabel: String?
    let isOtherSelected: Bool
    @Binding var customInput: String
    let onSelect: (String) -> Void
    let onSelectOther: () -> Void

    @FocusState private var isTextFieldFocused: Bool
    @State private var hoveredTooltip: HoveredTooltip?
    @State private var containerFrame: CGRect = .zero

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 질문 헤더
            if let header = question.header {
                Text(header)
                    .font(.subheadline.weight(.semibold))
            }
            if let questionText = question.question {
                Text(questionText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // 선택지 버튼들
            VStack(spacing: 6) {
                ForEach(question.options) { option in
                    OptionRowView(
                        option: option,
                        isSelected: selectedLabel == option.label && !isOtherSelected,
                        onTap: { onSelect(option.label) },
                        onHoverChange: { frame in
                            if let frame = frame,
                               let desc = option.description,
                               !desc.isEmpty {
                                hoveredTooltip = HoveredTooltip(description: desc, frame: frame)
                            } else {
                                hoveredTooltip = nil
                            }
                        }
                    )
                }

                // Other (직접 입력) 옵션
                Button {
                    onSelectOther()
                    isTextFieldFocused = true
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Other")
                                .font(.subheadline)
                            Text("직접 입력")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if isOtherSelected {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.blue)
                        }
                    }
                    .padding(10)
                    .background {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(isOtherSelected
                                ? Color.blue.opacity(0.1)
                                : Color(NSColor.controlBackgroundColor))
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(isOtherSelected
                                ? Color.blue.opacity(0.5)
                                : Color.clear, lineWidth: 1)
                    }
                }
                .buttonStyle(.plain)

                // Other 선택 시 텍스트 필드 표시
                if isOtherSelected {
                    TextField("응답 입력...", text: $customInput)
                        .textFieldStyle(.plain)
                        .padding(10)
                        .background {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(NSColor.textBackgroundColor))
                        }
                        .overlay {
                            RoundedRectangle(cornerRadius: 8)
                                .strokeBorder(Color.blue.opacity(0.5), lineWidth: 1)
                        }
                        .focused($isTextFieldFocused)
                }
            }
        }
        .background {
            GeometryReader { geo in
                Color.clear
                    .onAppear { containerFrame = geo.frame(in: .global) }
                    .onChange(of: geo.frame(in: .global)) { _, newFrame in
                        containerFrame = newFrame
                    }
            }
        }
        .overlay(alignment: .topLeading) {
            // 툴팁 오버레이
            if let tooltip = hoveredTooltip, containerFrame != .zero {
                HStack(spacing: 4) {
                    Image(systemName: "info.circle.fill")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.7))
                    Text(tooltip.description)
                        .font(.caption2)
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.black)
                }
                .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
                .offset(
                    x: tooltip.frame.minX - containerFrame.minX,
                    y: tooltip.frame.maxY - containerFrame.minY + 4
                )
                .allowsHitTesting(false)
                .zIndex(1000)
            }
        }
    }
}

// MARK: - OptionRowView

/// 옵션 행 뷰 (호버 시 좌표 전달)
private struct OptionRowView: View {
    let option: PermissionOption
    let isSelected: Bool
    let onTap: () -> Void
    let onHoverChange: (CGRect?) -> Void

    @State private var isHovered: Bool = false
    @State private var currentFrame: CGRect = .zero

    var body: some View {
        Button {
            onTap()
        } label: {
            HStack {
                HStack(spacing: 4) {
                    Text(option.label)
                        .font(.subheadline)
                    if option.description != nil, !option.description!.isEmpty {
                        Image(systemName: "info.circle")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.blue)
                }
            }
            .padding(10)
            .background {
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected
                        ? Color.blue.opacity(0.1)
                        : isHovered
                            ? Color.blue.opacity(0.05)
                            : Color(NSColor.controlBackgroundColor))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(isSelected
                        ? Color.blue.opacity(0.5)
                        : isHovered
                            ? Color.blue.opacity(0.3)
                            : Color.clear, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .background {
            GeometryReader { geo in
                Color.clear
                    .onAppear { currentFrame = geo.frame(in: .global) }
                    .onChange(of: geo.frame(in: .global)) { _, newFrame in
                        currentFrame = newFrame
                    }
            }
        }
        .onHover { hovering in
            isHovered = hovering
            if hovering {
                onHoverChange(currentFrame)
            } else {
                onHoverChange(nil)
            }
        }
    }
}

// MARK: - PermissionRequestPopover

/// 권한 요청 팝오버 (상태바 아이콘용)
struct PermissionRequestPopover: View {
    @StateObject private var viewModel = PermissionRequestViewModel()

    var body: some View {
        VStack(spacing: 0) {
            if viewModel.pendingRequests.isEmpty {
                Text("대기 중인 권한 요청이 없습니다")
                    .foregroundStyle(.secondary)
                    .padding()
            } else {
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(viewModel.pendingRequests) { request in
                            CompactPermissionCard(
                                request: request,
                                onAllow: { viewModel.allow(request: request) },
                                onDeny: { viewModel.deny(request: request) }
                            )
                        }
                    }
                    .padding()
                }
                .frame(maxHeight: 400)
            }
        }
        .frame(width: 320)
    }
}

// MARK: - CompactPermissionCard

/// 간소화된 권한 요청 카드 (팝오버용)
private struct CompactPermissionCard: View {
    let request: PermissionRequest
    let onAllow: () -> Void
    let onDeny: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.shield.fill")
                .foregroundStyle(.orange)

            VStack(alignment: .leading, spacing: 2) {
                Text(request.toolName)
                    .font(.subheadline.weight(.medium))
                if let cwd = request.cwd {
                    Text(cwd.split(separator: "/").last.map(String.init) ?? cwd)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            HStack(spacing: 8) {
                Button {
                    onAllow()
                } label: {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
                .buttonStyle(.plain)

                Button {
                    onDeny()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
            }
            .font(.title3)
        }
        .padding(10)
        .background {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(NSColor.controlBackgroundColor))
        }
    }
}

// MARK: - Preview

#Preview {
    PermissionRequestBannerView()
        .frame(width: 400)
}
