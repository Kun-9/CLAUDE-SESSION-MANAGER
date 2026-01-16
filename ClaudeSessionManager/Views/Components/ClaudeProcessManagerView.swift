// MARK: - 파일 설명
// ClaudeProcessManagerView: Claude 프로세스 관리 팝오버
// - 실행 중인 프로세스 목록 표시
// - 개별/일괄/좀비 프로세스 종료 기능

import SwiftUI

// MARK: - Process Manager Button

struct ClaudeProcessManagerButton: View {
    @State private var isPresented = false
    @State private var processes: [ClaudeProcess] = []
    @State private var isLoading = false
    @State private var refreshTimer: Timer?

    private var normalCount: Int { processes.filter { !$0.isBackground }.count }
    private var zombieCount: Int { processes.filter { $0.isBackground }.count }

    var body: some View {
        Button {
            refreshProcesses()
            isPresented = true
        } label: {
            HStack(spacing: 6) {
                // 정상 프로세스 수 (터미널 연결됨)
                HStack(spacing: 3) {
                    Image(systemName: "terminal.fill")
                        .font(.system(size: 10))
                    Text("\(normalCount)")
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                }
                .foregroundStyle(normalCount > 0 ? .primary : .tertiary)

                // 좀비 프로세스 수 (있을 때만)
                if zombieCount > 0 {
                    HStack(spacing: 3) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 10))
                        Text("\(zombieCount)")
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                    }
                    .foregroundStyle(.orange)
                }
            }
            .frame(height: 28)
            .padding(.horizontal, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .padding(3)
        .background {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Color(NSColor.controlBackgroundColor).opacity(0.5))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
        }
        .popover(isPresented: $isPresented, arrowEdge: .bottom) {
            ClaudeProcessListView(
                processes: $processes,
                isLoading: $isLoading,
                onRefresh: refreshProcesses,
                onKillAll: killAllProcesses,
                onKillZombies: killZombieProcesses,
                onKillProcess: killProcess
            )
        }
        .onAppear {
            refreshProcesses()
            startAutoRefresh()
        }
        .onDisappear {
            stopAutoRefresh()
        }
    }

    // MARK: - Auto Refresh

    private func startAutoRefresh() {
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
            if !isPresented {
                refreshProcessesQuietly()
            }
        }
    }

    private func stopAutoRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    // MARK: - Actions

    private func refreshProcesses() {
        isLoading = true
        DispatchQueue.global(qos: .userInitiated).async {
            let result = ClaudeProcessService.listProcesses()
            DispatchQueue.main.async {
                processes = result
                isLoading = false
            }
        }
    }

    private func refreshProcessesQuietly() {
        DispatchQueue.global(qos: .utility).async {
            let result = ClaudeProcessService.listProcesses()
            DispatchQueue.main.async {
                processes = result
            }
        }
    }

    private func killAllProcesses() {
        isLoading = true
        DispatchQueue.global(qos: .userInitiated).async {
            _ = ClaudeProcessService.killAllProcesses()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                refreshProcesses()
            }
        }
    }

    private func killZombieProcesses() {
        isLoading = true
        DispatchQueue.global(qos: .userInitiated).async {
            _ = ClaudeProcessService.killBackgroundProcesses()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                refreshProcesses()
            }
        }
    }

    private func killProcess(_ process: ClaudeProcess) {
        DispatchQueue.global(qos: .userInitiated).async {
            _ = ClaudeProcessService.killProcess(process)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                refreshProcesses()
            }
        }
    }
}

// MARK: - Process List View

private struct ClaudeProcessListView: View {
    @Binding var processes: [ClaudeProcess]
    @Binding var isLoading: Bool
    let onRefresh: () -> Void
    let onKillAll: () -> Void
    let onKillZombies: () -> Void
    let onKillProcess: (ClaudeProcess) -> Void

    @State private var showKillAllConfirm = false

    private var zombieCount: Int { processes.filter { $0.isBackground }.count }

    var body: some View {
        VStack(spacing: 0) {
            // 헤더
            header
                .padding(.horizontal, 12)
                .padding(.vertical, 10)

            Divider()

            // 프로세스 목록
            if isLoading {
                loadingView
            } else if processes.isEmpty {
                emptyView
            } else {
                processList
            }

            Divider()

            // 푸터
            footer
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
        }
        .frame(width: 400, height: 350)
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Claude 프로세스")
                    .font(.headline)

                Text(statusText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                onRefresh()
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 12))
            }
            .buttonStyle(.plain)
            .disabled(isLoading)
        }
    }

    private var statusText: String {
        let total = processes.count
        let background = zombieCount
        if total == 0 {
            return "실행 중인 프로세스 없음"
        } else if background > 0 {
            return "\(total)개 실행 중 (\(background)개 좀비)"
        } else {
            return "\(total)개 실행 중"
        }
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack {
            Spacer()
            ProgressView()
                .scaleEffect(0.8)
            Text("조회 중...")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.top, 8)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Empty View

    private var emptyView: some View {
        VStack {
            Spacer()
            Image(systemName: "checkmark.circle")
                .font(.system(size: 32))
                .foregroundStyle(.green)
            Text("실행 중인 프로세스 없음")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.top, 8)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Process List

    private var processList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(processes) { process in
                    ProcessRowView(
                        process: process,
                        onKill: { onKillProcess(process) }
                    )

                    if process.id != processes.last?.id {
                        Divider()
                            .padding(.leading, 12)
                    }
                }
            }
        }
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: 8) {
            Spacer()

            // 좀비 정리 버튼
            Button {
                onKillZombies()
            } label: {
                Label("좀비 정리", systemImage: "exclamationmark.triangle")
                    .font(.system(size: 12, weight: .medium))
            }
            .buttonStyle(.bordered)
            .tint(.orange)
            .disabled(zombieCount == 0)

            // 모두 종료 버튼
            Button(role: .destructive) {
                showKillAllConfirm = true
            } label: {
                Label("모두 종료", systemImage: "xmark.circle.fill")
                    .font(.system(size: 12, weight: .medium))
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
            .disabled(processes.isEmpty)
            .popover(isPresented: $showKillAllConfirm, arrowEdge: .bottom) {
                VStack(spacing: 12) {
                    Text("현재 대화 중인 세션을 포함하여\n모든 Claude 프로세스가 종료됩니다.")
                        .font(.callout)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 8) {
                        Button("취소") {
                            showKillAllConfirm = false
                        }
                        .buttonStyle(.bordered)

                        Button("종료") {
                            showKillAllConfirm = false
                            onKillAll()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.red)
                    }
                }
                .padding(12)
            }
        }
    }
}

// MARK: - Process Row View

private struct ProcessRowView: View {
    let process: ClaudeProcess
    let onKill: () -> Void

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 12) {
            // 상태 아이콘
            statusIcon
                .frame(width: 24)

            // 프로세스 정보
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text("PID \(process.id)")
                        .font(.system(size: 12, weight: .medium, design: .monospaced))

                    if process.isBackground {
                        Text("좀비")
                            .font(.system(size: 10, weight: .medium))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.2))
                            .foregroundStyle(.orange)
                            .clipShape(Capsule())
                    }
                }

                Text(process.displayDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            // CPU/메모리
            VStack(alignment: .trailing, spacing: 2) {
                Text(String(format: "%.1f%%", process.cpu))
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(cpuColor)

                Text(process.startTime)
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }

            // 종료 버튼
            Button {
                onKill()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .opacity(isHovering ? 1 : 0.5)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(isHovering ? Color.primary.opacity(0.05) : Color.clear)
        .onHover { isHovering = $0 }
    }

    private var statusIcon: some View {
        Group {
            if process.isBackground {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
            } else {
                Image(systemName: "terminal.fill")
                    .foregroundStyle(.green)
            }
        }
        .font(.system(size: 14))
    }

    private var cpuColor: Color {
        if process.cpu > 50 {
            return .red
        } else if process.cpu > 10 {
            return .orange
        } else {
            return .secondary
        }
    }
}
