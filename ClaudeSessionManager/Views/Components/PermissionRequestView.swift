// MARK: - 파일 설명
// PermissionRequestView: 권한 요청 선택 UI
// - 격자 레이아웃용 컴팩트 오버레이 (GridPermissionOverlay)
// - 도구별 상세 정보 팝오버 (GridToolDetailPopover)

import Combine
import SwiftUI

// MARK: - PermissionRequestViewModel

/// 권한 요청 UI 상태 관리
@MainActor
final class PermissionRequestViewModel: ObservableObject {
    @Published var pendingRequests: [PermissionRequest] = []

    /// 세션 ID별 권한 요청 매핑 (O(1) 검색용)
    @Published private(set) var requestsBySessionId: [String: PermissionRequest] = [:]

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
        let requests = PermissionRequestStore.loadPendingRequests()
        pendingRequests = requests
        // O(1) 검색을 위한 딕셔너리 갱신 (중복 sessionId는 첫 번째 요청만 유지)
        requestsBySessionId = Dictionary(requests.map { ($0.sessionId, $0) }) { first, _ in first }
    }

    /// 특정 세션의 권한 요청 조회 (O(1))
    func permissionRequest(for sessionId: String) -> PermissionRequest? {
        requestsBySessionId[sessionId]
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
        // 참고: 두 알림이 동시에 발생할 수 있으나, loadPendingRequests()는
        // 빠르게 완료되므로 debounce 불필요
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

// MARK: - Helper Functions

/// 알려진 도구 타입인지 확인 (MCP 등 알 수 없는 타입은 false)
private func isKnownToolType(_ toolName: String) -> Bool {
    switch toolName {
    case "Read", "Edit", "Write", "Bash", "Glob", "Grep", "WebFetch", "WebSearch", "Task":
        return true
    default:
        return false
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
    @State private var showDetailPopover: Bool = false  // diff/미리보기 팝오버

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

    /// 뱃지 색상
    private var badgeColor: Color {
        switch request.toolName {
        case "Read":
            return .blue
        case "Edit", "Write":
            return .orange
        case "Bash":
            return .purple
        case "Glob", "Grep":
            return .green
        case "WebFetch", "WebSearch":
            return .cyan
        case "Task":
            return .indigo
        default:
            return .gray
        }
    }

    var body: some View {
        // 선택 요청: 버튼만, 권한 요청: 도구 정보 헤더 + 버튼
        if request.hasQuestions {
            // 선택 요청: 버튼만 표시
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
        } else {
            // 권한 요청: 도구 정보 헤더 + 버튼
            VStack(spacing: 0) {
                // 도구 정보 헤더 (한 줄)
                HStack(spacing: 4) {
                    // 도구 이름 뱃지 (알 수 없는 타입은 "Unknown")
                    Text(isKnownToolType(request.toolName) ? request.toolName : "Unknown")
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(badgeColor))
                        .foregroundStyle(.white)
                        .fixedSize()

                    Spacer(minLength: 4)

                    // 상세 보기 버튼 (파일 경로, diff 등)
                    Button {
                        showDetailPopover.toggle()
                    } label: {
                        Image(systemName: "info.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)
                    .fixedSize()
                    .popover(isPresented: $showDetailPopover, arrowEdge: .top) {
                        GridToolDetailPopover(toolName: request.toolName, toolInput: request.toolInput)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4.5)
                .background(Color.black.opacity(0.3))

                // 버튼 영역
                buttonBar
            }
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

// MARK: - BashHighlightedText

// TODO: 구문 강조 라이브러리로 대체 예정 (예: Splash, Highlightr 등)
/// Bash 명령어 구문 강조 뷰 (여러 줄 지원)
private struct BashHighlightedText: View {
    let command: String

    /// 줄 단위로 분리된 명령어
    private var lines: [String] {
        command.components(separatedBy: "\n")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                Text(highlightedLine(line, isFirstLine: index == 0))
                    .font(.caption.monospaced())
                    .fixedSize(horizontal: false, vertical: true)  // 가로 줄바꿈 허용
            }
        }
    }

    /// 단일 줄의 구문 강조된 AttributedString 생성
    private func highlightedLine(_ line: String, isFirstLine: Bool) -> AttributedString {
        var result = AttributedString()

        // $ 프롬프트 추가 (첫 줄만)
        if isFirstLine {
            var prompt = AttributedString("$ ")
            prompt.foregroundColor = .secondary
            result.append(prompt)
        } else {
            // 연속 줄은 들여쓰기
            var indent = AttributedString("  ")
            indent.foregroundColor = .secondary
            result.append(indent)
        }

        let tokens = tokenize(line)
        var isFirstWord = true

        for token in tokens {
            var attr = AttributedString(token.text)

            switch token.type {
            case .command:
                attr.foregroundColor = .blue
                attr.font = .caption.monospaced().weight(.semibold)
            case .flag:
                attr.foregroundColor = .orange
            case .string:
                attr.foregroundColor = .green
            case .pipe, .redirect:
                attr.foregroundColor = .purple
                attr.font = .caption.monospaced().weight(.semibold)
            case .comment:
                attr.foregroundColor = .gray
            case .space:
                break  // 기본 색상
            case .text:
                if isFirstWord {
                    attr.foregroundColor = .blue
                    attr.font = .caption.monospaced().weight(.semibold)
                }
            }

            if token.type != .space && token.type != .pipe && token.type != .redirect {
                isFirstWord = false
            }
            if token.type == .pipe || token.type == .redirect {
                isFirstWord = true  // 파이프/리다이렉트 후 다시 명령어
            }

            result.append(attr)
        }

        return result
    }

    private enum TokenType {
        case command, flag, string, pipe, redirect, comment, space, text
    }

    private struct Token {
        let text: String
        let type: TokenType
    }

    /// 명령어를 토큰으로 분리
    private func tokenize(_ cmd: String) -> [Token] {
        var tokens: [Token] = []
        var current = ""
        var inString = false
        var stringChar: Character = "\""
        var i = cmd.startIndex

        while i < cmd.endIndex {
            let c = cmd[i]

            // 문자열 처리
            if inString {
                current.append(c)
                if c == stringChar {
                    tokens.append(Token(text: current, type: .string))
                    current = ""
                    inString = false
                }
                i = cmd.index(after: i)
                continue
            }

            // 문자열 시작
            if c == "\"" || c == "'" {
                if !current.isEmpty {
                    tokens.append(classifyToken(current))
                    current = ""
                }
                inString = true
                stringChar = c
                current.append(c)
                i = cmd.index(after: i)
                continue
            }

            // 공백
            if c.isWhitespace {
                if !current.isEmpty {
                    tokens.append(classifyToken(current))
                    current = ""
                }
                tokens.append(Token(text: String(c), type: .space))
                i = cmd.index(after: i)
                continue
            }

            // 파이프, 리다이렉트
            if c == "|" {
                if !current.isEmpty {
                    tokens.append(classifyToken(current))
                    current = ""
                }
                tokens.append(Token(text: "|", type: .pipe))
                i = cmd.index(after: i)
                continue
            }

            if c == ">" || c == "<" {
                if !current.isEmpty {
                    tokens.append(classifyToken(current))
                    current = ""
                }
                // >> 처리
                var redirectText = String(c)
                let next = cmd.index(after: i)
                if next < cmd.endIndex && cmd[next] == c {
                    redirectText.append(c)
                    i = next
                }
                tokens.append(Token(text: redirectText, type: .redirect))
                i = cmd.index(after: i)
                continue
            }

            // 주석
            if c == "#" {
                if !current.isEmpty {
                    tokens.append(classifyToken(current))
                    current = ""
                }
                // 나머지 전부 주석
                let remaining = String(cmd[i...])
                tokens.append(Token(text: remaining, type: .comment))
                break
            }

            current.append(c)
            i = cmd.index(after: i)
        }

        // 남은 토큰
        if !current.isEmpty {
            if inString {
                tokens.append(Token(text: current, type: .string))
            } else {
                tokens.append(classifyToken(current))
            }
        }

        return tokens
    }

    private func classifyToken(_ text: String) -> Token {
        if text.hasPrefix("-") {
            return Token(text: text, type: .flag)
        }
        return Token(text: text, type: .text)
    }
}

// MARK: - BashCodeBlock

/// Bash 명령어 코드 블럭
/// - 5줄 이내: 스크롤 없이 전체 표시
/// - 5줄 초과: 스크롤 가능
private struct BashCodeBlock: View {
    let command: String

    /// 최대 높이 (스크롤 필요 시)
    private let maxHeight: CGFloat = 200

    /// 명령어 줄 수
    private var lineCount: Int {
        command.components(separatedBy: "\n").count
    }

    /// 스크롤이 필요한지 (5줄 초과 시)
    private var needsScroll: Bool {
        lineCount > 5
    }

    var body: some View {
        if needsScroll {
            ScrollView(.vertical) {
                codeContent
            }
            .frame(maxHeight: maxHeight)
            .background(Color(NSColor.textBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 6))
        } else {
            codeContent
                .background(Color(NSColor.textBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
    }

    private var codeContent: some View {
        BashHighlightedText(command: command)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(8)
    }
}

// MARK: - DiffCodeBlock

/// Diff 코드 블럭 (삭제/추가 표시)
/// - MarkdownCodeBlockView 스타일 적용: 복사 버튼 + 둥근 배경
/// - 짧은 내용: 스크롤 없이 전체 표시
/// - 긴 내용: 스크롤 가능
private struct DiffCodeBlock: View {
    let label: String
    let text: String
    let color: Color

    @EnvironmentObject private var toastCenter: ToastCenter

    /// 최대 높이 (스크롤 필요 시)
    private let maxHeight: CGFloat = 300

    /// 텍스트 줄 수
    private var lineCount: Int {
        text.components(separatedBy: "\n").count
    }

    /// 스크롤이 필요한지 (대략 5줄 이상이면 스크롤)
    private var needsScroll: Bool {
        lineCount > 5
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption.weight(.medium))
                .foregroundStyle(color)

            ZStack(alignment: .topTrailing) {
                if needsScroll {
                    // 긴 내용: ScrollView 사용
                    ScrollView(.vertical) {
                        codeText
                    }
                    .frame(maxHeight: maxHeight)
                } else {
                    // 짧은 내용: 스크롤 없이 표시
                    codeText
                }

                // 복사 버튼
                Button {
                    ClipboardService.copy(text)
                    toastCenter.show("클립보드에 복사됨")
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(color)
                        .padding(5)
                        .background(Circle().fill(color.opacity(0.15)))
                }
                .buttonStyle(.plain)
                .padding(6)
                .help("복사")
            }
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(color.opacity(0.1))
            )
        }
    }

    private var codeText: some View {
        Text(text)
            .font(.system(.caption, design: .monospaced))
            .foregroundStyle(color.opacity(0.9))
            .fixedSize(horizontal: false, vertical: true)
            .lineLimit(nil)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
            .padding(.trailing, 24)
    }
}

// MARK: - WriteCodeBlock

/// Write 코드 블럭 (파일 내용 미리보기)
/// - MarkdownCodeBlockView 스타일 적용: 복사 버튼 + 둥근 배경
private struct WriteCodeBlock: View {
    let lineCount: Int
    let content: String

    @EnvironmentObject private var toastCenter: ToastCenter

    /// 최대 높이
    private let maxHeight: CGFloat = 400

    /// 스크롤이 필요한지 (대략 10줄 이상이면 스크롤)
    private var needsScroll: Bool {
        lineCount > 10
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(lineCount)줄")
                .font(.caption)
                .foregroundStyle(.secondary)

            ZStack(alignment: .topTrailing) {
                if needsScroll {
                    ScrollView(.vertical) {
                        codeText
                    }
                    .frame(maxHeight: maxHeight)
                } else {
                    codeText
                }

                // 복사 버튼
                Button {
                    ClipboardService.copy(content)
                    toastCenter.show("클립보드에 복사됨")
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.blue)
                        .padding(5)
                        .background(Circle().fill(Color.blue.opacity(0.15)))
                }
                .buttonStyle(.plain)
                .padding(6)
                .help("복사")
            }
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.primary.opacity(0.06))
            )
        }
    }

    private var codeText: some View {
        Text(content)
            .font(.system(.caption, design: .monospaced))
            .foregroundStyle(.primary)
            .fixedSize(horizontal: false, vertical: true)
            .lineLimit(nil)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
            .padding(.trailing, 24)
    }
}

// MARK: - GridToolDetailPopover

/// 격자용 도구 상세 정보 팝오버 (Edit diff, Write 미리보기)
private struct GridToolDetailPopover: View {
    let toolName: String
    let toolInput: PermissionToolInput?

    /// 도구 아이콘
    private var toolIcon: String {
        switch toolName {
        case "Read": return "doc.text"
        case "Edit": return "pencil.circle.fill"
        case "Write": return "doc.badge.plus"
        case "Bash": return "terminal"
        case "Glob": return "folder.badge.questionmark"
        case "Grep": return "magnifyingglass"
        default: return "wrench"
        }
    }

    /// 도구 색상
    private var toolColor: Color {
        switch toolName {
        case "Read": return .blue
        case "Edit": return .orange
        case "Write": return .blue
        case "Bash": return .purple
        case "Glob", "Grep": return .green
        default: return .gray
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 헤더
            HStack(spacing: 6) {
                Image(systemName: toolIcon)
                    .foregroundStyle(toolColor)
                Text(toolName)
                    .font(.headline)
            }

            // 파일 경로 (Bash 제외)
            if toolName != "Bash", let summary = toolInput?.summary(for: toolName) {
                HStack(spacing: 4) {
                    Image(systemName: "folder")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(summary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            Divider()

            if let input = toolInput {
                // Bash 명령어 (전체 표시 + 하이라이팅, 줄바꿈 지원)
                if toolName == "Bash", let command = input.command, !command.isEmpty {
                    BashCodeBlock(command: command)
                }

                // Edit diff
                if toolName == "Edit", input.hasEditDiff {
                    VStack(alignment: .leading, spacing: 6) {
                        // 삭제되는 내용
                        if let old = input.old_string, !old.isEmpty {
                            DiffCodeBlock(label: "삭제:", text: old, color: .red)
                        }

                        // 추가되는 내용
                        if let new = input.new_string, !new.isEmpty {
                            DiffCodeBlock(label: "추가:", text: new, color: .green)
                        }
                    }
                }

                // Write 미리보기
                if toolName == "Write", let content = input.content, !content.isEmpty {
                    WriteCodeBlock(lineCount: input.writeLineCount, content: content)
                }
            }
        }
        .padding(14)
        .frame(minWidth: 250, maxWidth: 500)
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
