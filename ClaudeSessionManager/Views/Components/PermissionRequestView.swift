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

    /// Observer 참조 (deinit에서 안전한 정리를 위해 nonisolated(unsafe) 사용)
    nonisolated(unsafe) private var permissionObserver: NSObjectProtocol?
    nonisolated(unsafe) private var sessionObserver: NSObjectProtocol?

    init() {
        loadPendingRequests()
        startObserving()
    }

    deinit {
        // Observer 정리 (DistributedNotificationCenter.removeObserver는 thread-safe)
        // 지역 변수로 복사 후 nil 처리하여 race condition 방지
        let pObserver = permissionObserver
        let sObserver = sessionObserver
        permissionObserver = nil
        sessionObserver = nil

        if let observer = pObserver {
            DistributedNotificationCenter.default().removeObserver(observer)
        }
        if let observer = sObserver {
            DistributedNotificationCenter.default().removeObserver(observer)
        }
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
    /// - permissionRequestAddedNotification: 새 권한 요청 추가 시
    /// - sessionsDidChangeNotification: 훅 처리 완료 시 (터미널에서 권한 응답 포함)
    private func startObserving() {
        // 권한 요청 추가 알림
        permissionObserver = DistributedNotificationCenter.default().addObserver(
            forName: PermissionRequestStore.permissionRequestAddedNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor [weak self] in
                self?.loadPendingRequests()
            }
        }

        // 세션 변경 알림 (PostToolUse 등 훅 처리 완료 시)
        // 터미널에서 권한 응답 시 pending 삭제 감지용
        sessionObserver = DistributedNotificationCenter.default().addObserver(
            forName: SessionStore.sessionsDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
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
                            },
                            onSubmit: {
                                if canSubmitWithAnswers {
                                    onAllow(answersDict)
                                }
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
                        Label("Ask in Terminal", systemImage: "terminal")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(.gray)
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
                    .tint(Color(red: 0.2, green: 0.72, blue: 0.5))

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
                        Label("Ask in Terminal", systemImage: "terminal")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(.gray)
                    .help("Claude Code 터미널에서 직접 선택")
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
    @State private var hoveredTooltip: HoveredTooltip?  // 툴팁 상태 (최상위 레벨에서 렌더링)
    @State private var containerFrame: CGRect = .zero  // 컨테이너 글로벌 좌표

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
                            },
                            onHoverTooltip: { tooltip in
                                hoveredTooltip = tooltip
                            },
                            onSubmit: {
                                if canSubmitWithAnswers {
                                    onAllow(answersDict)
                                }
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
                        Label("Ask in Terminal", systemImage: "terminal")
                            .font(.subheadline)
                    }
                    .buttonStyle(.bordered)
                    .tint(.gray)
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
                    .tint(Color(red: 0.2, green: 0.72, blue: 0.5))
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
                        Label("Ask in Terminal", systemImage: "terminal")
                            .font(.subheadline)
                    }
                    .buttonStyle(.bordered)
                    .tint(.gray)
                    .controlSize(.small)
                }
            }
        }
        .padding(12)
        .background {
            // 컨테이너 글로벌 좌표 캡처
            GeometryReader { geo in
                UnevenRoundedRectangle(
                    topLeadingRadius: 0,
                    bottomLeadingRadius: 14,
                    bottomTrailingRadius: 14,
                    topTrailingRadius: 0
                )
                .fill(request.hasQuestions
                    ? Color.blue.opacity(0.08)
                    : Color.orange.opacity(0.08))
                .onAppear { containerFrame = geo.frame(in: .global) }
                .onChange(of: geo.frame(in: .global)) { _, newFrame in
                    containerFrame = newFrame
                }
            }
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
        // 툴팁 오버레이 - 버튼과 같은 레벨에서 렌더링 (z-index 문제 해결)
        .overlay(alignment: .topLeading) {
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
    let onHoverTooltip: (HoveredTooltip?) -> Void  // 부모에서 툴팁 렌더링
    let onSubmit: () -> Void  // Enter 키 제출 (부모에서 canSubmit 확인 후 호출)

    @FocusState private var isTextFieldFocused: Bool

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
                                    onHoverTooltip(HoveredTooltip(description: desc, frame: frame))
                                } else {
                                    onHoverTooltip(nil)
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
                    .onSubmit {
                        onSubmit()
                    }
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
    let onSubmit: () -> Void  // Enter 키 제출 (부모에서 canSubmit 확인 후 호출)

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
                        .onSubmit {
                            onSubmit()
                        }
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

// MARK: - GridPermissionOverlay

/// 격자 레이아웃용 컴팩트 권한 요청 오버레이
/// 카드 하단에 아이콘 버튼으로 표시
struct GridPermissionOverlay: View {
    let request: PermissionRequest
    let onAllow: ([String: String]?) -> Void
    let onDeny: () -> Void
    let onAsk: () -> Void

    @State private var selectedOptions: [Int: Set<String>] = [:]
    @State private var isOtherSelected: [Int: Bool] = [:]
    @State private var customInputs: [Int: String] = [:]
    @State private var isExpanded: Bool = false

    /// 세련된 초록색 (민트 계열)
    private let allowColor = Color(red: 0.2, green: 0.72, blue: 0.5)

    private var canSubmit: Bool {
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
        guard canSubmit else { return nil }
        guard let questions = request.questions else { return nil }
        var result: [String: String] = [:]
        for (index, _) in questions.enumerated() {
            if isOtherSelected[index] == true, let customText = customInputs[index], !customText.isEmpty {
                result["\(index)"] = customText
            } else if let labels = selectedOptions[index], !labels.isEmpty {
                result["\(index)"] = labels.sorted().joined(separator: ", ")
            }
        }
        return result
    }

    var body: some View {
        // 버튼 영역만 표시 (확장은 popover로 처리)
        buttonBar
            .background {
                UnevenRoundedRectangle(
                    topLeadingRadius: 0,
                    bottomLeadingRadius: 10,
                    bottomTrailingRadius: 10,
                    topTrailingRadius: 0
                )
                .fill(Color.orange)
            }
            .clipShape(
                UnevenRoundedRectangle(
                    topLeadingRadius: 0,
                    bottomLeadingRadius: 10,
                    bottomTrailingRadius: 10,
                    topTrailingRadius: 0
                )
            )
    }

    // MARK: - 버튼 바

    @ViewBuilder
    private var buttonBar: some View {
        if request.hasQuestions {
            // 선택 요청: 전송 팝오버 + X(닫기)
            HStack(spacing: 6) {
                // 전송 버튼 (팝오버 트리거)
                Button {
                    isExpanded.toggle()
                } label: {
                    Image(systemName: "paperplane.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.orange)
                        .frame(width: 28, height: 28)
                        .background(Circle().fill(Color.white))
                }
                .buttonStyle(.plain)
                .popover(isPresented: $isExpanded, arrowEdge: .top) {
                    expandedQuestionView
                        .frame(minWidth: 200, maxWidth: 280)
                }

                Spacer()

                // X (닫기/터미널에서 처리)
                Button {
                    onAsk()
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(width: 24, height: 24)
                        .background(Circle().fill(Color.black.opacity(0.7)))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
        } else {
            // 권한 요청: Allow/Deny/Terminal 아이콘
            HStack(spacing: 8) {
                // Allow
                Button {
                    onAllow(nil)
                } label: {
                    Image(systemName: "checkmark")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 24, height: 24)
                        .background(Circle().fill(allowColor))
                }
                .buttonStyle(.plain)

                // Deny
                Button {
                    onDeny()
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 24, height: 24)
                        .background(Circle().fill(Color.red.opacity(0.85)))
                }
                .buttonStyle(.plain)

                Spacer()

                // Terminal (X 버튼과 동일한 스타일)
                Button {
                    onAsk()
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(width: 24, height: 24)
                        .background(Circle().fill(Color.black.opacity(0.7)))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
        }
    }

    // MARK: - 확장된 선택지 뷰

    @ViewBuilder
    private var expandedQuestionView: some View {
        if let questions = request.questions {
            GridQuestionPopoverContent(
                questions: questions,
                selectedOptions: $selectedOptions,
                isOtherSelected: $isOtherSelected,
                customInputs: $customInputs,
                canSubmit: canSubmit,
                onSubmit: {
                    // 값을 먼저 캡처한 후 팝오버 닫기
                    let answers = answersDict
                    isExpanded = false
                    onAllow(answers)
                }
            )
        }
    }
}

// MARK: - GridQuestionPopoverContent

/// 격자용 선택지 팝오버 내용
private struct GridQuestionPopoverContent: View {
    let questions: [PermissionQuestion]
    @Binding var selectedOptions: [Int: Set<String>]
    @Binding var isOtherSelected: [Int: Bool]
    @Binding var customInputs: [Int: String]
    let canSubmit: Bool
    let onSubmit: () -> Void

    /// 현재 클릭하여 표시 중인 description의 칩 ID
    @State private var activeDescriptionId: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 타이틀
            HStack(spacing: 6) {
                Image(systemName: "questionmark.circle.fill")
                    .foregroundStyle(.blue)
                Text("선택 요청")
                    .font(.headline)
            }

            Divider()

            ForEach(Array(questions.enumerated()), id: \.offset) { index, question in
                VStack(alignment: .leading, spacing: 8) {
                    // 헤더 + 질문
                    VStack(alignment: .leading, spacing: 2) {
                        if let header = question.header {
                            Text(header)
                                .font(.subheadline.weight(.semibold))
                        }
                        if let questionText = question.question {
                            Text(questionText)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        if question.multiSelect {
                            Text("(복수 선택 가능)")
                                .font(.caption2)
                                .foregroundStyle(.blue)
                        }
                    }

                    // 옵션 칩들
                    FlowLayout(spacing: 6) {
                        ForEach(question.options) { option in
                            GridOptionChip(
                                chipId: "\(index)-\(option.label)",
                                label: option.label,
                                description: option.description,
                                isSelected: selectedOptions[index]?.contains(option.label) ?? false,
                                isMultiSelect: question.multiSelect,
                                activeDescriptionId: $activeDescriptionId,
                                onTap: {
                                    if question.multiSelect {
                                        var current = selectedOptions[index] ?? []
                                        if current.contains(option.label) {
                                            current.remove(option.label)
                                        } else {
                                            current.insert(option.label)
                                        }
                                        selectedOptions[index] = current
                                    } else {
                                        selectedOptions[index] = [option.label]
                                    }
                                    isOtherSelected[index] = false
                                }
                            )
                        }

                        // Other 칩
                        GridOptionChip(
                            chipId: "\(index)-other",
                            label: "Other",
                            description: "직접 입력",
                            isSelected: isOtherSelected[index] ?? false,
                            isMultiSelect: question.multiSelect,
                            activeDescriptionId: $activeDescriptionId,
                            onTap: {
                                selectedOptions[index] = []
                                isOtherSelected[index] = true
                            }
                        )
                    }

                    // Other 텍스트 필드
                    if isOtherSelected[index] ?? false {
                        TextField("직접 입력...", text: Binding(
                            get: { customInputs[index] ?? "" },
                            set: { customInputs[index] = $0 }
                        ))
                        .textFieldStyle(.plain)
                        .font(.caption)
                        .padding(8)
                        .background(RoundedRectangle(cornerRadius: 6).fill(Color(NSColor.textBackgroundColor)))
                        .overlay {
                            RoundedRectangle(cornerRadius: 6)
                                .strokeBorder(Color.blue.opacity(0.3), lineWidth: 1)
                        }
                        .onSubmit {
                            if canSubmit {
                                onSubmit()
                            }
                        }
                    }
                }
            }

            Divider()

            // 전송 버튼
            Button {
                onSubmit()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "paperplane.fill")
                    Text("전송")
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(RoundedRectangle(cornerRadius: 8).fill(canSubmit ? .blue : Color.gray.opacity(0.5)))
            }
            .buttonStyle(.plain)
            .disabled(!canSubmit)
        }
        .padding(14)
    }
}

// MARK: - GridOptionChip

/// 격자용 옵션 칩 (info 아이콘 클릭 시 description popover 표시)
private struct GridOptionChip: View {
    let chipId: String
    let label: String
    let description: String?
    let isSelected: Bool
    let isMultiSelect: Bool
    @Binding var activeDescriptionId: String?
    let onTap: () -> Void

    @State private var isHovered: Bool = false

    private var hasDescription: Bool {
        description != nil && !description!.isEmpty
    }

    private var showDescription: Bool {
        activeDescriptionId == chipId
    }

    var body: some View {
        HStack(spacing: 4) {
            if isMultiSelect {
                Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                    .font(.caption2)
                    .foregroundStyle(isSelected ? .blue : .secondary)
            }
            Text(label)
                .font(.caption)
            if hasDescription {
                Image(systemName: showDescription ? "info.circle.fill" : "info.circle")
                    .font(.caption2)
                    .foregroundStyle(showDescription ? .blue : .secondary)
                    .onTapGesture {
                        withAnimation(.easeOut(duration: 0.15)) {
                            if showDescription {
                                activeDescriptionId = nil
                            } else {
                                activeDescriptionId = chipId
                            }
                        }
                    }
                    .popover(isPresented: .init(
                        get: { showDescription },
                        set: { if !$0 { activeDescriptionId = nil } }
                    ), arrowEdge: .bottom) {
                        if let desc = description {
                            Text(desc)
                                .font(.caption)
                                .padding(10)
                                .fixedSize(horizontal: false, vertical: true)
                                .frame(maxWidth: 200)
                        }
                    }
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
        .contentShape(Capsule())
        .onHover { hovering in
            isHovered = hovering
        }
        .onTapGesture {
            onTap()
        }
    }
}

// MARK: - FlowLayout

/// 가로 공간 부족 시 자동 줄바꿈 레이아웃
private struct FlowLayout: Layout {
    var spacing: CGFloat = 4

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var totalHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > maxWidth, currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }
            positions.append(CGPoint(x: currentX, y: currentY))
            currentX += size.width + spacing
            lineHeight = max(lineHeight, size.height)
            totalHeight = currentY + lineHeight
        }

        return (CGSize(width: maxWidth, height: totalHeight), positions)
    }
}

// MARK: - Preview

#Preview {
    PermissionRequestBannerView()
        .frame(width: 400)
}
