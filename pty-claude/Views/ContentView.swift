// MARK: - 파일 설명
// ContentView: 앱 메인 뷰
// - 세션 목록을 메인 콘텐츠로 표시
// - 설정은 시트로 분리 (Settings 버튼 클릭)

import AppKit
import SwiftUI

struct ContentView: View {
    // MARK: - 저장된 설정 값 (UserDefaults)

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
    @AppStorage(SettingsKeys.soundEnabled, store: SettingsStore.defaults)
    private var storedSoundEnabled = true
    @AppStorage(SettingsKeys.soundName, store: SettingsStore.defaults)
    private var storedSoundName = "Glass"
    @AppStorage(SettingsKeys.soundVolume, store: SettingsStore.defaults)
    private var storedSoundVolume = 1.0

    // MARK: - 화면에서 편집 중인 임시 값

    @State private var draftNotificationsEnabled = true
    @State private var draftPreToolUseEnabled = false
    @State private var draftPreToolUseTools = "AskUserQuestion"
    @State private var draftStopEnabled = true
    @State private var draftPermissionEnabled = true
    @State private var draftSoundEnabled = true
    @State private var draftSoundName = "Glass"
    @State private var draftSoundVolume = 1.0

    // MARK: - UI State

    @State private var hasLoadedDrafts = false
    @State private var showSettings = false
    @State private var selectedSession: SessionItem?
    @FocusState private var isSessionModalFocused: Bool
    @AppStorage("ui.useDarkMode") private var useDarkMode = false

    @EnvironmentObject private var debugLogStore: DebugLogStore
    @EnvironmentObject private var toastCenter: ToastCenter

    // macOS 기본 사운드 목록
    private let soundOptions = [
        "Basso", "Blow", "Bottle", "Frog", "Funk", "Glass",
        "Hero", "Morse", "Ping", "Pop", "Purr", "Sosumi",
        "Submarine", "Tink",
    ]

    var body: some View {
        rootView
    }
}

// MARK: - Private Views

private extension ContentView {
    var rootView: some View {
        SessionView(selectedSession: $selectedSession)
            .frame(minWidth: 600, minHeight: 500)
            .onAppear {
                if !hasLoadedDrafts {
                    loadDrafts()
                    hasLoadedDrafts = true
                }
                NSApp.appearance = NSAppearance(named: useDarkMode ? .darkAqua : .aqua)
                // 창 제목 설정
                DispatchQueue.main.async {
                    NSApp.mainWindow?.title = "CLAUDE SESSION MANAGER"
                }
            }
            .onChange(of: useDarkMode) { _, newValue in
                NSApp.appearance = NSAppearance(named: newValue ? .darkAqua : .aqua)
            }
            .onChange(of: selectedSession?.id) { _, newValue in
                isSessionModalFocused = newValue != nil
            }
            .sheet(isPresented: $showSettings, onDismiss: loadDrafts) {
                SettingsSheet(
                    draftNotificationsEnabled: $draftNotificationsEnabled,
                    draftPreToolUseEnabled: $draftPreToolUseEnabled,
                    draftPreToolUseTools: $draftPreToolUseTools,
                    draftStopEnabled: $draftStopEnabled,
                    draftPermissionEnabled: $draftPermissionEnabled,
                    draftSoundEnabled: $draftSoundEnabled,
                    draftSoundName: $draftSoundName,
                    draftSoundVolume: $draftSoundVolume,
                    soundOptions: soundOptions,
                    onSave: saveDrafts,
                    onClose: { showSettings = false }
                )
                .environmentObject(debugLogStore)
                .environmentObject(toastCenter)
            }
            .overlay { sessionDetailOverlay }
            .overlay(alignment: .bottom) { toastOverlay }
            .overlay(alignment: .bottomLeading) { settingsButton }
            .overlay(alignment: .bottomTrailing) { darkModeButton }
    }

    @ViewBuilder
    var sessionDetailOverlay: some View {
        if let session = selectedSession {
            GeometryReader { proxy in
                let width = min(max(proxy.size.width * 0.8, 640), proxy.size.width - 40)
                let height = min(max(proxy.size.height * 0.8, 460), proxy.size.height - 40)
                ZStack {
                    Color.black.opacity(0.2)
                        .ignoresSafeArea()
                        .onTapGesture { selectedSession = nil }
                    SessionDetailSheet(session: session) {
                        selectedSession = nil
                    }
                    .frame(width: width, height: height)
                }
                .focusable(true)
                .focusEffectDisabled(true)
                .focused($isSessionModalFocused)
                .onExitCommand { selectedSession = nil }
            }
            .transition(.opacity)
        }
    }

    var toastOverlay: some View {
        ToastOverlayView()
            .padding(.bottom, 20)
    }

    var settingsButton: some View {
        Button {
            showSettings = true
        } label: {
            Image(systemName: "gearshape")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .keyboardShortcut(",", modifiers: [.command])
        .padding(16)
    }

    var darkModeButton: some View {
        Button {
            useDarkMode.toggle()
        } label: {
            Image(systemName: useDarkMode ? "sun.max" : "moon")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .padding(16)
    }
}

// MARK: - Settings Helpers

private extension ContentView {
    /// 저장된 값을 임시 값으로 복사
    func loadDrafts() {
        draftNotificationsEnabled = storedNotificationsEnabled
        draftPreToolUseEnabled = storedPreToolUseEnabled
        draftPreToolUseTools = storedPreToolUseTools
        draftStopEnabled = storedStopEnabled
        draftPermissionEnabled = storedPermissionEnabled
        draftSoundEnabled = storedSoundEnabled
        draftSoundName = storedSoundName
        draftSoundVolume = storedSoundVolume
    }

    /// 임시 값을 저장 값으로 반영
    func saveDrafts() {
        storedNotificationsEnabled = draftNotificationsEnabled
        storedPreToolUseEnabled = draftPreToolUseEnabled
        storedPreToolUseTools = draftPreToolUseTools
        storedStopEnabled = draftStopEnabled
        storedPermissionEnabled = draftPermissionEnabled
        storedSoundEnabled = draftSoundEnabled
        storedSoundName = draftSoundName
        storedSoundVolume = draftSoundVolume
    }
}

// MARK: - Preview

#Preview {
    ContentView()
        .environmentObject(ToastCenter())
        .environmentObject(DebugLogStore())
}
