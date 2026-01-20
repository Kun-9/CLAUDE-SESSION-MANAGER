// MARK: - 파일 설명
// SettingsSheet: 설정 시트 메인 뷰
// - Notifications, Terminal, Hooks, Debug 탭으로 구성
// - ContentView에서 시트로 표시

import SwiftUI

struct SettingsSheet: View {
    // MARK: - Bindings (편집 중인 임시 값)
    @Binding var draftNotificationsEnabled: Bool
    @Binding var draftPreToolUseEnabled: Bool
    @Binding var draftPreToolUseTools: String
    @Binding var draftStopEnabled: Bool
    @Binding var draftPermissionEnabled: Bool
    @Binding var draftInteractivePermission: Bool
    @Binding var draftSoundEnabled: Bool
    @Binding var draftSoundName: String
    @Binding var draftSoundVolume: Double
    @Binding var draftTerminalApp: String
    @Binding var draftDeleteClaudeSessionFiles: Bool

    // MARK: - 저장된 값 (UserDefaults에서 직접 읽기)
    @AppStorage(SettingsKeys.notificationsEnabled, store: SettingsStore.defaults)
    private var storedNotificationsEnabled = true
    @AppStorage(SettingsKeys.preToolUseEnabled, store: SettingsStore.defaults)
    private var storedPreToolUseEnabled = false
    @AppStorage(SettingsKeys.preToolUseTools, store: SettingsStore.defaults)
    private var storedPreToolUseTools = "AskUserQuestion"
    @AppStorage(SettingsKeys.stopEnabled, store: SettingsStore.defaults)
    private var storedStopEnabled = true
    @AppStorage(SettingsKeys.permissionEnabled, store: SettingsStore.defaults)
    private var storedPermissionEnabled = true
    @AppStorage(SettingsKeys.interactivePermission, store: SettingsStore.defaults)
    private var storedInteractivePermission = false
    @AppStorage(SettingsKeys.soundEnabled, store: SettingsStore.defaults)
    private var storedSoundEnabled = true
    @AppStorage(SettingsKeys.soundName, store: SettingsStore.defaults)
    private var storedSoundName = "Glass"
    @AppStorage(SettingsKeys.soundVolume, store: SettingsStore.defaults)
    private var storedSoundVolume = 1.0
    @AppStorage(SettingsKeys.terminalApp, store: SettingsStore.defaults)
    private var storedTerminalApp = TerminalApp.iTerm2.rawValue
    @AppStorage(SettingsKeys.deleteClaudeSessionFiles, store: SettingsStore.defaults)
    private var storedDeleteClaudeSessionFiles = true

    let soundOptions: [String]
    let onSave: () -> Void
    let onClose: () -> Void

    /// 저장된 값과 편집 중인 값이 다른지 여부
    private var hasChanges: Bool {
        storedNotificationsEnabled != draftNotificationsEnabled
            || storedPreToolUseEnabled != draftPreToolUseEnabled
            || storedPreToolUseTools != draftPreToolUseTools
            || storedStopEnabled != draftStopEnabled
            || storedPermissionEnabled != draftPermissionEnabled
            || storedInteractivePermission != draftInteractivePermission
            || storedSoundEnabled != draftSoundEnabled
            || storedSoundName != draftSoundName
            || storedSoundVolume != draftSoundVolume
            || storedTerminalApp != draftTerminalApp
            || storedDeleteClaudeSessionFiles != draftDeleteClaudeSessionFiles
    }

    // MARK: - State
    @State private var selectedTab: SettingsTab = .notifications
    @FocusState private var focusedField: FocusField?

    // Claude 탭 상태
    @State private var claudeStatus: String = ""
    @State private var claudeCanApply: Bool = false
    @State private var claudePreviewData: ClaudePreviewData?
    @State private var showApplyConfirmation: Bool = false

    @EnvironmentObject private var debugLogStore: DebugLogStore
    @EnvironmentObject private var toastCenter: ToastCenter

    var body: some View {
        VStack(spacing: 0) {
            // 헤더 + 탭
            headerView

            Divider()

            // 탭 콘텐츠
            tabContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()

            // 푸터 (저장/취소 버튼)
            footerView
        }
        .frame(width: 560, height: 520)
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear {
            // 시트 표시 후 시스템 auto-focus 해제
            Task { @MainActor in
                NSApp.keyWindow?.makeFirstResponder(nil)
            }
        }
        .sheet(item: $claudePreviewData) { data in
            ClaudePreviewSheet(
                afterLines: data.afterLines,
                errorMessage: data.errorMessage,
                onClose: { claudePreviewData = nil }
            )
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack(spacing: 0) {
            ForEach(SettingsTab.allCases) { tab in
                tabButton(for: tab)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func tabButton(for tab: SettingsTab) -> some View {
        Button {
            selectedTab = tab
        } label: {
            HStack(spacing: 6) {
                Image(systemName: tab.icon)
                    .font(.system(size: 12))
                Text(tab.title)
                    .font(.system(size: 13, weight: .medium))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                selectedTab == tab
                    ? Color.accentColor.opacity(0.15)
                    : Color.clear
            )
            .foregroundColor(selectedTab == tab ? .accentColor : .secondary)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Tab Content

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .notifications:
            notificationsView
        case .sessions:
            sessionsView
        case .terminal:
            terminalView
        case .hooks:
            hooksView
        case .debug:
            debugView
        }
    }

    // MARK: - Footer

    private var footerView: some View {
        HStack {
            Spacer()
            HoverButton("취소") {
                onClose()
            }
            .keyboardShortcut(.escape, modifiers: [])

            HoverButton("저장", isPrimary: true) {
                onSave()
                onClose()
            }
            .keyboardShortcut(.return, modifiers: [.command])
            .disabled(!hasChanges)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    // MARK: - Notifications View

    private var notificationsView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // 섹션 1: 알림 이벤트
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        SectionHeaderView(title: "Events", subtitle: "Choose which events trigger notifications.")
                        Spacer()
                        Toggle("", isOn: $draftNotificationsEnabled)
                            .toggleStyle(.switch)
                            .labelsHidden()
                    }

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

                        Toggle("Stop", isOn: $draftStopEnabled)
                            .toggleStyle(.switch)
                        Toggle("PermissionRequest", isOn: $draftPermissionEnabled)
                            .toggleStyle(.switch)
                    }
                    .foregroundStyle(draftNotificationsEnabled ? .primary : .secondary)
                    .disabled(!draftNotificationsEnabled)
                }

                Divider()

                // 섹션 1.5: 대화형 권한 요청
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        SectionHeaderView(
                            title: "Interactive Permission",
                            subtitle: "Handle permission requests in this app instead of Claude Code."
                        )
                        Spacer()
                        Toggle("", isOn: $draftInteractivePermission)
                            .toggleStyle(.switch)
                            .labelsHidden()
                    }

                }

                Divider()

                // 섹션 2: 사운드 설정
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        SectionHeaderView(title: "Sound", subtitle: "Notification sound settings.")
                        Spacer()
                        Toggle("", isOn: $draftSoundEnabled)
                            .toggleStyle(.switch)
                            .labelsHidden()
                            .disabled(!draftNotificationsEnabled)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 8) {
                            Text("Sound")
                                .font(.subheadline.weight(.semibold))
                            Picker("", selection: $draftSoundName) {
                                ForEach(soundOptions, id: \.self) { option in
                                    Text(option).tag(option)
                                }
                            }
                            .pickerStyle(.menu)
                            .frame(width: 120)
                            Button {
                                previewSound()
                            } label: {
                                Image(systemName: "speaker.wave.2")
                            }
                            .buttonStyle(.borderless)
                            .help("Preview sound")
                            .disabled(draftSoundName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }

                        HStack(spacing: 8) {
                            Text("Volume")
                                .font(.subheadline.weight(.semibold))
                            Slider(value: $draftSoundVolume, in: 0...1)
                                .frame(width: 140)
                        }
                    }
                    .foregroundStyle(draftNotificationsEnabled && draftSoundEnabled ? .primary : .secondary)
                    .disabled(!draftNotificationsEnabled || !draftSoundEnabled)
                }
            }
            .padding(24)
        }
        .contentShape(Rectangle())
        .simultaneousGesture(TapGesture().onEnded { dismissFocus() })
    }

    // MARK: - Sessions View

    private var sessionsView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        SectionHeaderView(
                            title: "Session Files",
                            subtitle: "세션 삭제 시 Claude Code 원본 파일 처리"
                        )
                        Spacer()
                        Toggle("", isOn: $draftDeleteClaudeSessionFiles)
                            .toggleStyle(.switch)
                            .labelsHidden()
                    }

                    Text("비활성화 시 앱 내 세션 레코드만 삭제되고, ~/.claude/projects/ 하위의 원본 파일은 유지됩니다.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(24)
        }
        .contentShape(Rectangle())
        .simultaneousGesture(TapGesture().onEnded { dismissFocus() })
    }

    // MARK: - Terminal View

    private var terminalView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                SectionHeaderView(
                    title: "Terminal App",
                    subtitle: "Choose which terminal app to use for sessions."
                )

                VStack(alignment: .leading, spacing: 12) {
                    ForEach(TerminalApp.allCases) { app in
                        TerminalAppRowView(
                            app: app,
                            isSelected: draftTerminalApp == app.rawValue,
                            onSelect: { draftTerminalApp = app.rawValue }
                        )
                    }
                }

                Divider()

                // 시스템 설정 열기 버튼
                VStack(alignment: .leading, spacing: 8) {
                    Text("자동화 권한")
                        .font(.subheadline.weight(.semibold))
                    Text("터미널 앱을 제어하려면 시스템 환경설정에서 자동화 권한을 허용해야 합니다.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button("시스템 설정 열기") {
                        TerminalService.openAutomationSettings()
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding(24)
        }
        .contentShape(Rectangle())
        .simultaneousGesture(TapGesture().onEnded { dismissFocus() })
    }

    // MARK: - Hooks View

    private var hooksView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                SectionHeaderView(title: "Hooks", subtitle: "Update Claude hooks to call this app.")

                VStack(alignment: .leading, spacing: 8) {
                    Text("Hook command")
                        .font(.subheadline.weight(.semibold))
                    CodeBlockView(text: ExecutableService.hookCommandPath() ?? "Unable to locate executable path.") {
                        if let command = ExecutableService.hookCommandPath() {
                            ClipboardService.copy(command)
                            toastCenter.show("클립보드에 복사됨")
                            claudeStatus = "Hook command copied."
                        }
                    }
                    Text("Hooks JSON")
                        .font(.subheadline.weight(.semibold))
                    CodeBlockView(
                        text: hooksJSONSnippetText ?? "Unable to locate executable path.",
                        maxHeight: 140,
                        onCopy: hooksJSONSnippetText == nil ? nil : {
                            if let snippet = hooksJSONSnippetText {
                                ClipboardService.copy(snippet)
                                toastCenter.show("클립보드에 복사됨")
                                claudeStatus = "Hooks JSON copied."
                            }
                        }
                    )
                    Text("Writes to ~/.claude/settings.json")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Divider()

                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 12) {
                        Button("Preview Changes") {
                            let preview: (after: [PreviewLine], canApply: Bool, statusMessage: String?, error: String?)
                            if let command = ExecutableService.hookCommandPath() {
                                preview = ClaudeSettingsService.buildHooksPreview(command: command)
                            } else {
                                preview = ([], false, "Unable to resolve the app executable path.", "Unable to resolve the app executable path.")
                            }
                            claudeCanApply = preview.canApply
                            if let status = preview.statusMessage {
                                claudeStatus = status
                            }
                            // .sheet(item:) 패턴으로 데이터와 표시를 동시에 설정
                            claudePreviewData = ClaudePreviewData(
                                afterLines: preview.after,
                                errorMessage: preview.error
                            )
                        }
                        .buttonStyle(.bordered)

                        if claudeCanApply {
                            Button("Apply Updates") {
                                showApplyConfirmation = true
                            }
                            .buttonStyle(.borderedProminent)
                        } else {
                            Button("Apply Updates") {}
                                .buttonStyle(.bordered)
                                .disabled(true)
                        }

                        Button("Noti Test") {
                            requestHookTest()
                        }
                        .buttonStyle(.bordered)
                        .disabled(ExecutableService.hookCommandPath() == nil)
                        .help("Send notification test")
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
            .alert("Overwrite settings.json hooks?", isPresented: $showApplyConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Apply Updates", role: .destructive) {
                    if let command = ExecutableService.hookCommandPath() {
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

    // MARK: - Debug View

    private var debugView: some View {
        DebugView()
            .environmentObject(debugLogStore)
    }

    // MARK: - Helpers

    private func previewSound() {
        SoundService.play(name: draftSoundName, volume: draftSoundVolume)
    }

    private func dismissFocus() {
        focusedField = nil
        NSApp.keyWindow?.makeFirstResponder(nil)
    }

    private var hooksJSONSnippetText: String? {
        guard let command = ExecutableService.hookCommandPath() else {
            return nil
        }
        return ClaudeSettingsService.hooksJSONSnippet(command: command)
    }

    private func refreshClaudeApplyState() {
        guard let command = ExecutableService.hookCommandPath() else {
            claudeCanApply = false
            return
        }
        claudeCanApply = ClaudeSettingsService.hooksNeedUpdate(command: command)
    }

    private func requestHookTest() {
        guard let command = ExecutableService.hookCommandPath() else {
            claudeStatus = "Unable to resolve the app executable path."
            return
        }

        let settings = HookTestService.Settings(
            preToolUseEnabled: draftPreToolUseEnabled,
            stopEnabled: draftStopEnabled,
            permissionEnabled: draftPermissionEnabled,
            preToolUseTools: draftPreToolUseTools
        )

        claudeStatus = "Sending hook test..."
        DispatchQueue.global(qos: .userInitiated).async {
            let result = HookTestService.run(
                command: command,
                sessionId: "hook-test",
                settings: settings
            )
            DispatchQueue.main.async {
                claudeStatus = result.status
            }
        }
    }
}

// MARK: - Types

private enum SettingsTab: String, CaseIterable, Identifiable {
    case notifications = "Notifications"
    case sessions = "Sessions"
    case terminal = "Terminal"
    case hooks = "Hooks"
    case debug = "Debug"

    var id: String { rawValue }

    var title: String { rawValue }

    var icon: String {
        switch self {
        case .notifications: return "bell"
        case .sessions: return "folder"
        case .terminal: return "rectangle.on.rectangle"
        case .hooks: return "terminal"
        case .debug: return "ladybug"
        }
    }
}

private enum FocusField: Hashable {
    case preToolUseTools
}

// MARK: - Claude Preview Data

/// Claude Preview 시트에 전달할 데이터 래퍼
/// - .sheet(item:) 패턴 사용으로 상태 캡처 타이밍 문제 해결
private struct ClaudePreviewData: Identifiable {
    let id = UUID()
    let afterLines: [PreviewLine]
    let errorMessage: String?
}

// MARK: - Claude Preview Sheet

private struct ClaudePreviewSheet: View {
    let afterLines: [PreviewLine]
    let errorMessage: String?
    let onClose: () -> Void

    var body: some View {
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

// MARK: - Code Block View

private struct CodeBlockView: View {
    let text: String
    let maxHeight: CGFloat?
    let onCopy: (() -> Void)?

    init(text: String, maxHeight: CGFloat? = nil, onCopy: (() -> Void)? = nil) {
        self.text = text
        self.maxHeight = maxHeight
        self.onCopy = onCopy
    }

    var body: some View {
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

// MARK: - Hover Button

private struct HoverButton: View {
    let title: String
    let isPrimary: Bool
    let action: () -> Void

    @State private var isHovered = false
    @Environment(\.isEnabled) private var isEnabled

    init(_ title: String, isPrimary: Bool = false, action: @escaping () -> Void) {
        self.title = title
        self.isPrimary = isPrimary
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: isPrimary ? .semibold : .regular))
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .background(backgroundColor)
                .foregroundColor(foregroundColor)
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }

    private var backgroundColor: Color {
        if !isEnabled {
            return isPrimary ? Color.accentColor.opacity(0.3) : Color.primary.opacity(0.05)
        }
        if isPrimary {
            return isHovered ? Color.accentColor.opacity(0.9) : Color.accentColor
        }
        return isHovered ? Color.primary.opacity(0.15) : Color.primary.opacity(0.08)
    }

    private var foregroundColor: Color {
        if !isEnabled {
            return isPrimary ? .white.opacity(0.6) : .secondary
        }
        return isPrimary ? .white : .primary
    }
}

// MARK: - Terminal App Row View

/// 터미널 앱 선택 행 (권한 상태 포함)
private struct TerminalAppRowView: View {
    let app: TerminalApp
    let isSelected: Bool
    let onSelect: () -> Void

    @State private var hasPermission: Bool = false
    @State private var isCheckingPermission: Bool = false

    private var isInstalled: Bool { app.isInstalled }

    var body: some View {
        Button(action: {
            if isInstalled {
                onSelect()
            }
        }) {
            HStack(spacing: 12) {
                // 선택 표시
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .accentColor : .secondary)
                    .font(.system(size: 18))

                // 앱 이름
                Text(app.displayName)
                    .font(.body)

                Spacer()

                // 상태 표시
                statusLabel
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.accentColor.opacity(0.3) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(!isInstalled)
        .opacity(isInstalled ? 1.0 : 0.5)
        .onAppear {
            checkPermission()
        }
    }

    @ViewBuilder
    private var statusLabel: some View {
        if !isInstalled {
            Text("설치 안됨")
                .font(.caption)
                .foregroundColor(.orange)
        } else if isCheckingPermission {
            ProgressView()
                .scaleEffect(0.6)
        } else if hasPermission {
            Label("허용됨", systemImage: "checkmark.shield.fill")
                .font(.caption)
                .foregroundColor(.green)
        } else {
            Button("권한 요청") {
                requestPermission()
            }
            .font(.caption)
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
    }

    private func checkPermission() {
        guard isInstalled else { return }
        isCheckingPermission = true

        DispatchQueue.global(qos: .userInitiated).async {
            let result = TerminalService.checkAutomationPermission(for: app)
            DispatchQueue.main.async {
                hasPermission = result
                isCheckingPermission = false
            }
        }
    }

    private func requestPermission() {
        TerminalService.requestAutomationPermission(for: app)
        // 권한 요청 후 잠시 대기 후 다시 확인
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            checkPermission()
        }
    }
}
