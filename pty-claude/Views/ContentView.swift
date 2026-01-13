import AppKit
import SwiftUI

struct ContentView: View {
    // 저장된 설정 값(UserDefaults) - 앱 재실행 후에도 유지되는 상태
    @AppStorage(SettingsKeys.preToolUseEnabled, store: SettingsStore.defaults) private var storedPreToolUseEnabled = true
    @AppStorage(SettingsKeys.preToolUseTools, store: SettingsStore.defaults) private var storedPreToolUseTools = "AskUserQuestion"
    @AppStorage(SettingsKeys.stopEnabled, store: SettingsStore.defaults) private var storedStopEnabled = true
    @AppStorage(SettingsKeys.permissionEnabled, store: SettingsStore.defaults) private var storedPermissionEnabled = true
    @AppStorage(SettingsKeys.soundEnabled, store: SettingsStore.defaults) private var storedSoundEnabled = true
    @AppStorage(SettingsKeys.soundName, store: SettingsStore.defaults) private var storedSoundName = "Glass"
    @AppStorage(SettingsKeys.soundVolume, store: SettingsStore.defaults) private var storedSoundVolume = 1.0

    // 화면에서 편집 중인 임시 값 - 저장 버튼으로 반영
    @State private var draftPreToolUseEnabled = true
    @State private var draftPreToolUseTools = "AskUserQuestion"
    @State private var draftStopEnabled = true
    @State private var draftPermissionEnabled = true
    @State private var draftSoundEnabled = true
    @State private var draftSoundName = "Glass"
    @State private var draftSoundVolume = 1.0

    // 최초 로드 여부 체크
    @State private var hasLoadedDrafts = false

    // 사이드바 선택 및 Claude 화면 상태
    @State private var selection: SidebarItem? = .hooks
    @State private var claudeStatus = "Not updated yet."
    @State private var claudeCanApply = false
    @State private var showClaudePreview = false
    @State private var previewAfterLines: [PreviewLine] = []
    @State private var previewError: String?
    @State private var showApplyConfirmation = false
    @AppStorage("ui.useDarkMode") private var useDarkMode = false
    @State private var selectedSession: SessionItem?

    // 텍스트 입력 포커스 관리
    @FocusState private var focusedField: FocusField?

    // macOS 기본 사운드 목록
    private let soundOptions = [
        "Basso",
        "Blow",
        "Bottle",
        "Frog",
        "Funk",
        "Glass",
        "Hero",
        "Morse",
        "Ping",
        "Pop",
        "Purr",
        "Sosumi",
        "Submarine",
        "Tink",
    ]

    var body: some View {
        // 좌측 사이드바 + 우측 상세 화면 구성
        NavigationSplitView {
            List(selection: $selection) {
                Section("Settings") {
                    Label("Hooks", systemImage: "bolt.horizontal.fill")
                        .tag(SidebarItem.hooks)
                    Label("Sound", systemImage: "speaker.wave.2.fill")
                        .tag(SidebarItem.sound)
                    Label("Claude", systemImage: "sparkles")
                        .tag(SidebarItem.claude)
                    Label("Session", systemImage: "rectangle.stack")
                        .tag(SidebarItem.session)
                }
            }
            .listStyle(.sidebar)
            .frame(minWidth: 200)
        } detail: {
            switch selection ?? .hooks {
            case .hooks:
                hooksView
            case .sound:
                soundView
            case .claude:
                claudeView
            case .session:
                sessionView
            }
        }
        .frame(minWidth: 850, minHeight: 650)
        .toolbar {
            if selection != .claude && selection != .session {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        saveDrafts()
                    } label: {
                        Image(systemName: "checkmark")
                        .padding(5)
                    }
                    .keyboardShortcut(KeyEquivalent("s"), modifiers: [.command])
                    .disabled(!hasChanges)
                    .controlSize(.small)
                    .tint(hasChanges ? .blue : .secondary)
                }
            }
        }
        .onAppear {
            // 앱 최초 진입 시 저장된 값을 임시 값으로 로드
            if !hasLoadedDrafts {
                loadDrafts()
                hasLoadedDrafts = true
            }
            NSApp.appearance = NSAppearance(named: useDarkMode ? .darkAqua : .aqua)
        }
        .onChange(of: useDarkMode) { _, newValue in
            NSApp.appearance = NSAppearance(named: newValue ? .darkAqua : .aqua)
        }
        .sheet(isPresented: $showClaudePreview) {
            // 변경 사항 미리보기 시트
            ClaudePreviewSheet(
                afterLines: previewAfterLines,
                errorMessage: previewError,
                onClose: {
                    showClaudePreview = false
                }
            )
        }
        .overlay(alignment: .bottomTrailing) {
            Button {
                useDarkMode.toggle()
            } label: {
                Image(systemName: useDarkMode ? "moon.fill" : "sun.max.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .padding(8)
            }
            .buttonStyle(.plain)
            .help("Toggle appearance")
            .accessibilityLabel("Toggle appearance")
            .padding(12)
        }
        .overlay {
            if let session = selectedSession {
                GeometryReader { proxy in
                    let width = min(max(proxy.size.width * 0.8, 640), proxy.size.width - 40)
                    let height = min(max(proxy.size.height * 0.8, 460), proxy.size.height - 40)
                    ZStack {
                        Color.black.opacity(0.2)
                            .ignoresSafeArea()
                            .onTapGesture {
                                selectedSession = nil
                            }
                        SessionDetailSheet(session: session) {
                            selectedSession = nil
                        }
                        .frame(width: width, height: height)
                    }
                }
                .transition(.opacity)
            }
        }
    }
}

#Preview {
    ContentView()
}

private enum SidebarItem: Hashable {
    case hooks
    case sound
    case claude
    case session
}

private extension ContentView {
    // Hooks 설정 화면
    var hooksView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                SectionHeaderView(title: "Hooks", subtitle: "Choose which events trigger notifications.")

                VStack(alignment: .leading, spacing: 12) {
                    Toggle("PreToolUse", isOn: $draftPreToolUseEnabled)
                        .toggleStyle(.switch)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Tools")
                            .font(.subheadline.weight(.semibold))
                        TextField("AskUserQuestion, ReadFile", text: $draftPreToolUseTools)
                            .textFieldStyle(.roundedBorder)
                            .focused($focusedField, equals: .preToolUseTools)
                        Text("Comma-separated list. Leave empty to allow all tools.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Divider()

                VStack(alignment: .leading, spacing: 12) {
                    Toggle("Stop", isOn: $draftStopEnabled)
                        .toggleStyle(.switch)
                    Toggle("PermissionRequest", isOn: $draftPermissionEnabled)
                        .toggleStyle(.switch)
                }
            }
            .padding(24)
        }
        .contentShape(Rectangle())
        .simultaneousGesture(TapGesture().onEnded { dismissFocus() })
    }

    // Sound 설정 화면
    var soundView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                
                Toggle("Enable sound", isOn: $draftSoundEnabled)
                    .toggleStyle(.switch)
                    .labelsHidden()

                VStack(alignment: .leading, spacing: 20) {
                    SectionHeaderView(title: "Sound", subtitle: "Global notification sound settings.")

                    VStack(alignment: .leading, spacing: 12) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("SOUND NAME")
                                .font(.subheadline.weight(.bold))
                            HStack(spacing: 8) {
                                Picker("sound", selection: $draftSoundName) {
                                    ForEach(soundOptions, id: \.self) { option in
                                        Text(option).tag(option)
                                    }
                                }
                                .pickerStyle(.menu)
                                .frame(width: 150, alignment: .leading)
                                .fixedSize(horizontal: true, vertical: false)
                                Button {
                                    previewSound()
                                } label: {
                                    Image(systemName: "speaker.wave.2")
                                }
                                .buttonStyle(.borderless)
                                .help("Preview sound")
                                .accessibilityLabel("Preview sound")
                                .disabled(draftSoundName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            }
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Volume")
                                .font(.subheadline.weight(.semibold))
                            Slider(value: $draftSoundVolume, in: 0...1)
                                .frame(width: 160)
                        }
                    }

                    Divider()

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Uses the macOS system sound name.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .foregroundStyle(draftSoundEnabled ? .primary : .secondary)
                .disabled(!draftSoundEnabled)
            }
            .padding(24)
        }
        .contentShape(Rectangle())
        .simultaneousGesture(TapGesture().onEnded { dismissFocus() })
    }

    // Claude 훅 업데이트 화면
    var claudeView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                SectionHeaderView(title: "Claude", subtitle: "Update Claude hooks to call this app.")

                VStack(alignment: .leading, spacing: 8) {
                    Text("Hook command")
                        .font(.subheadline.weight(.semibold))
                    CodeBlockView(text: currentHookCommand() ?? "Unable to locate executable path.") {
                        if let command = currentHookCommand() {
                            copyToClipboard(command)
                            claudeStatus = "Hook command copied."
                        }
                    }
                    Text("Hooks JSON")
                        .font(.subheadline.weight(.semibold))
                    CodeBlockView(text: hooksJSONSnippetText ?? "Unable to locate executable path.", maxHeight: 140, onCopy: hooksJSONSnippetText == nil ? nil : {
                        if let snippet = hooksJSONSnippetText {
                            copyToClipboard(snippet)
                            claudeStatus = "Hooks JSON copied."
                        }
                    })
                    Text("Writes to ~/.claude/settings.json")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Divider()

                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 12) {
                        Button("Preview Changes") {
                            // 변경 미리보기 계산
                            let preview: (after: [PreviewLine], canApply: Bool, statusMessage: String?, error: String?)
                            if let command = currentHookCommand() {
                                preview = ClaudeSettingsService.buildHooksPreview(command: command)
                            } else {
                                preview = ([], false, "Unable to resolve the app executable path.", "Unable to resolve the app executable path.")
                            }
                            previewAfterLines = preview.after
                            previewError = preview.error
                            claudeCanApply = preview.canApply
                            if let status = preview.statusMessage {
                                claudeStatus = status
                            }
                            showClaudePreview = true
                        }
                        .buttonStyle(.bordered)

                        if claudeCanApply {
                            Button("Apply Updates") {
                                // 덮어쓰기 확인 알림 표시
                                showApplyConfirmation = true
                            }
                            .buttonStyle(.borderedProminent)
                        } else {
                            Button("Apply Updates") {}
                                .buttonStyle(.bordered)
                                .disabled(true)
                        }

                        Button("Test") {
                            requestHookTest()
                        }
                        .buttonStyle(.bordered)
                        .disabled(currentHookCommand() == nil)
                        .help("Send hook test")
                    }

                    Text(claudeStatus)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Button("Open settings.json") {
                        claudeStatus = ClaudeSettingsService.openSettings()
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding(24)
            .onAppear {
                refreshClaudeApplyState()
            }
            // 덮어쓰기 경고 알림
            .alert("Overwrite settings.json hooks?", isPresented: $showApplyConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Apply Updates", role: .destructive) {
                    if let command = currentHookCommand() {
                        claudeStatus = ClaudeSettingsService.updateHooks(command: command)
                    } else {
                        claudeStatus = "Unable to resolve the app executable path."
                    }
                    refreshClaudeApplyState()
                }
            } message: {
                Text("This overwrites the hooks entries in ~/.claude/settings.json.")
            }
        }
        .contentShape(Rectangle())
        .simultaneousGesture(TapGesture().onEnded { dismissFocus() })
    }

    // Session 관리 화면
    var sessionView: some View {
        SessionView(selectedSession: $selectedSession)
    }

    // 저장된 값과 임시 값이 다른지 여부
    var hasChanges: Bool {
        storedPreToolUseEnabled != draftPreToolUseEnabled
            || storedPreToolUseTools != draftPreToolUseTools
            || storedStopEnabled != draftStopEnabled
            || storedPermissionEnabled != draftPermissionEnabled
            || storedSoundEnabled != draftSoundEnabled
            || storedSoundName != draftSoundName
            || storedSoundVolume != draftSoundVolume
    }

    // 저장된 값을 임시 값으로 복사
    func loadDrafts() {
        draftPreToolUseEnabled = storedPreToolUseEnabled
        draftPreToolUseTools = storedPreToolUseTools
        draftStopEnabled = storedStopEnabled
        draftPermissionEnabled = storedPermissionEnabled
        draftSoundEnabled = storedSoundEnabled
        draftSoundName = storedSoundName
        draftSoundVolume = storedSoundVolume
    }

    // 임시 값을 저장 값으로 반영
    func saveDrafts() {
        storedPreToolUseEnabled = draftPreToolUseEnabled
        storedPreToolUseTools = draftPreToolUseTools
        storedStopEnabled = draftStopEnabled
        storedPermissionEnabled = draftPermissionEnabled
        storedSoundEnabled = draftSoundEnabled
        storedSoundName = draftSoundName
        storedSoundVolume = draftSoundVolume
    }

    // 사운드 이름으로 미리듣기 재생
    func previewSound() {
        let name = draftSoundName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        if let sound = NSSound(named: NSSound.Name(name)) {
            sound.volume = Float(draftSoundVolume)
            sound.play()
        }
    }

    // 텍스트 입력 포커스 해제
    func dismissFocus() {
        focusedField = nil
        NSApp.keyWindow?.makeFirstResponder(nil)
    }

    // 클립보드에 텍스트 복사
    func copyToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    // 앱 번들에 포함된 훅 CLI 경로 기반 훅 명령 구성
    func currentHookCommand() -> String? {
        let toolURL = Bundle.main.bundleURL
            .appendingPathComponent("Contents")
            .appendingPathComponent("Resources")
            .appendingPathComponent("pty-claude-hook")
        guard FileManager.default.isExecutableFile(atPath: toolURL.path) else {
            return nil
        }
        return "\(toolURL.path)"
    }

    // hooks에 실제로 설정될 JSON 스니펫
    var hooksJSONSnippetText: String? {
        guard let command = currentHookCommand() else {
            return nil
        }
        return ClaudeSettingsService.hooksJSONSnippet(command: command)
    }

    func refreshClaudeApplyState() {
        guard let command = currentHookCommand() else {
            claudeCanApply = false
            return
        }
        claudeCanApply = ClaudeSettingsService.hooksNeedUpdate(command: command)
    }

    func requestHookTest() {
        guard let command = currentHookCommand() else {
            claudeStatus = "Unable to resolve the app executable path."
            return
        }

        let eventName = hookTestEventName()
        let toolName = hookTestToolName()
        let cwd = hookTestCwd()

        claudeStatus = "Sending hook test..."
        DispatchQueue.global(qos: .userInitiated).async {
            let status = runHookTest(
                command: command,
                eventName: eventName,
                toolName: toolName,
                cwd: cwd,
                sessionId: "hook-test"
            )
            DispatchQueue.main.async {
                claudeStatus = status
            }
        }
    }

    func hookTestEventName() -> String {
        if storedPreToolUseEnabled {
            return "PreToolUse"
        }
        if storedStopEnabled {
            return "Stop"
        }
        if storedPermissionEnabled {
            return "PermissionRequest"
        }
        return "PreToolUse"
    }

    func hookTestToolName() -> String {
        let tools = storedPreToolUseTools
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        let firstTool = tools.first { !$0.isEmpty }
        return firstTool ?? "AskUserQuestion"
    }

    func hookTestCwd() -> String {
        let current = FileManager.default.currentDirectoryPath
        if current == "/" {
            return FileManager.default.homeDirectoryForCurrentUser.path
        }
        return current
    }

    func runHookTest(
        command: String,
        eventName: String,
        toolName: String,
        cwd: String,
        sessionId: String?
    ) -> String {
        var payload: [String: Any] = [
            "hook_event_name": eventName,
            "tool_name": toolName,
            "cwd": cwd,
        ]
        if let sessionId, !sessionId.isEmpty {
            payload["session_id"] = sessionId
        }

        do {
            let data = try JSONSerialization.data(withJSONObject: payload, options: [])
            let process = Process()
            process.executableURL = URL(fileURLWithPath: command)
            let inputPipe = Pipe()
            let outputPipe = Pipe()
            let errorPipe = Pipe()
            process.standardInput = inputPipe
            process.standardOutput = outputPipe
            process.standardError = errorPipe
            try process.run()
            inputPipe.fileHandleForWriting.write(data)
            inputPipe.fileHandleForWriting.closeFile()
            process.waitUntilExit()

            if process.terminationStatus == 0 {
                return "Hook test sent (\(eventName))."
            }

            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let errorText = String(data: errorData, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)

            if let errorText, !errorText.isEmpty {
                return "Hook test failed: \(errorText)"
            }
            return "Hook test failed with status \(process.terminationStatus)."
        } catch {
            return "Failed to run hook test: \(error.localizedDescription)"
        }
    }
}

// 텍스트필드 포커스 식별자
private enum FocusField: Hashable {
    case preToolUseTools
}

// Claude 훅 변경 미리보기 시트
private struct ClaudePreviewSheet: View {
    let afterLines: [PreviewLine]
    let errorMessage: String?
    let onClose: () -> Void

    var body: some View {
        // 에러 메시지 또는 변경 라인 리스트 표시
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Claude Hooks Preview")
                    .font(.title3.weight(.semibold))
                Spacer()
                Button {
                    onClose()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                }
                .buttonStyle(.plain)
                .help("Close")
                .accessibilityLabel("Close preview")
            }

            if let errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.secondary)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(afterLines, id: \.id) { line in
                            Text(line.text.isEmpty ? " " : line.text)
                                .font(.system(.caption, design: .monospaced))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 2)
                                .background(lineBackground(for: line.kind))
                                .textSelection(.enabled)
                                .foregroundStyle(.primary)
                                .lineLimit(nil)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
        }
        .padding(20)
        .frame(minWidth: 520, minHeight: 420)
        .background(Color(NSColor.windowBackgroundColor))
    }

    private func lineBackground(for kind: ChangeKind) -> Color {
        switch kind {
        case .added:
            return Color.green.opacity(0.25)
        case .removed:
            return Color.red.opacity(0.25)
        case .unchanged:
            return Color.clear
        }
    }
}

// 코드 블록 스타일 + 선택적 복사 버튼
private struct CodeBlockView: View {
    let text: String
    let maxHeight: CGFloat?
    let onCopy: (() -> Void)?

    // 복사 액션이 없으면 버튼을 숨긴다
    init(text: String, maxHeight: CGFloat? = nil, onCopy: (() -> Void)? = nil) {
        self.text = text
        self.maxHeight = maxHeight
        self.onCopy = onCopy
    }

    var body: some View {
        // 오른쪽 상단에 복사 버튼을 오버레이
        ZStack(alignment: .topTrailing) {
            ScrollView {
                Text(text)
                    .font(.system(.callout, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 10)
                    .padding(.vertical, 10)
                    .padding(.trailing, onCopy == nil ? 10 : 34)
            }
            .frame(maxHeight: maxHeight)

            if let onCopy {
                Button(action: onCopy) {
                    Image(systemName: "doc.on.doc")
                }
                .buttonStyle(.borderless)
                // 코드 블록 내부 우측 상단 여백 확보
                .padding(6)
                .help("Copy hook command")
                .accessibilityLabel("Copy hook command")
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(NSColor.windowBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(NSColor.separatorColor), lineWidth: 1)
                )
        )
    }
}
