import Combine
import SwiftUI

private let debugTimestampFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy.MM.dd HH:mm:ss"
    return formatter
}()

struct DebugView: View {
    @EnvironmentObject private var debugLogStore: DebugLogStore
    @StateObject private var viewModel = DebugViewModel()
    @State private var expandedPayloadIds: Set<UUID> = []
    private let refreshTimer = Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                SectionHeaderView(
                    title: "Debug",
                    subtitle: "Inspect incoming hook payloads."
                )

                HStack(spacing: 12) {
                    Toggle("Debug mode", isOn: $viewModel.debugEnabled)
                        .toggleStyle(.switch)
                    Spacer()
                    Button("Refresh") {
                        debugLogStore.reload()
                    }
                    .buttonStyle(.bordered)
                    Button("Clear") {
                        debugLogStore.clear()
                    }
                    .buttonStyle(.bordered)
                    .disabled(debugLogStore.entries.isEmpty)
                }

                if debugLogStore.entries.isEmpty {
                    Text("No logs yet.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    LazyVStack(spacing: 12) {
                        ForEach(debugLogStore.entries.reversed()) { entry in
                            debugCard(for: entry)
                        }
                    }
                }
            }
            .padding(24)
        }
        .onAppear {
            debugLogStore.reload()
        }
        .onChange(of: viewModel.debugEnabled) { _, _ in
            debugLogStore.reload()
        }
        .onReceive(refreshTimer) { _ in
            guard viewModel.debugEnabled else { return }
            debugLogStore.reload()
        }
    }

    private func debugCard(for entry: DebugLogEntry) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(entry.hookName)
                    .font(.headline)
                Spacer()
                Text(debugTimestampFormatter.string(from: Date(timeIntervalSince1970: entry.timestamp)))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let toolName = entry.toolName, !toolName.isEmpty {
                metaRow(label: "Tool", value: toolName)
            }
            if let sessionId = entry.sessionId, !sessionId.isEmpty {
                metaRow(label: "Session", value: sessionId)
            }
            if let cwd = entry.cwd, !cwd.isEmpty {
                metaRow(label: "CWD", value: cwd)
            }
            if let transcriptPath = entry.transcriptPath, !transcriptPath.isEmpty {
                metaRow(label: "Transcript", value: transcriptPath, emphasized: true)
            }
            if let prompt = entry.prompt, !prompt.isEmpty {
                metaRow(label: "Prompt", value: prompt)
            }

            HStack {
                Button {
                    togglePayload(entry.id)
                } label: {
                    payloadHeader(for: entry)
                }
                .buttonStyle(.plain)

                Spacer()

                Button {
                    ClipboardService.copy(entry.rawPayload)
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Payload 복사")
            }

            if expandedPayloadIds.contains(entry.id) {
                Text(JSONFormattingService.highlighted(entry.rawPayload))
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.primary.opacity(0.04))
                    )
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.primary.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }

    private func togglePayload(_ id: UUID) {
        if expandedPayloadIds.contains(id) {
            expandedPayloadIds.remove(id)
        } else {
            expandedPayloadIds.insert(id)
        }
    }

    private func payloadHeader(for entry: DebugLogEntry) -> some View {
        let isExpanded = expandedPayloadIds.contains(entry.id)
        let sizeText = "\(JSONFormattingService.keyCount(entry.rawPayload))"

        return VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text("Payload")
                    .font(.headline)
                Text(sizeText)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        Capsule(style: .continuous)
                            .fill(Color.primary.opacity(0.08))
                    )
            }
        }
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func metaRow(label: String, value: String, emphasized: Bool = false) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Text("\(label):")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption)
                .padding(.horizontal, emphasized ? 6 : 0)
                .padding(.vertical, emphasized ? 2 : 0)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(emphasized ? Color.accentColor.opacity(0.14) : Color.clear)
                )
                .textSelection(.enabled)
        }
    }
}

#Preview {
    DebugView()
        .environmentObject(DebugLogStore())
}
