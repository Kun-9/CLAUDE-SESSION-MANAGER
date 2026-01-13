import Foundation
import SwiftUI

struct SessionView: View {
    @StateObject private var viewModel = SessionListViewModel()
    @Binding var selectedSession: SessionItem?
    @State private var listMode: SessionListMode = .all
    @State private var collapsedSectionIds: Set<String> = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                SectionHeaderView(
                    title: "Session",
                    subtitle: "Manage your claude-code sessions."
                )

                SessionListModePicker(selection: $listMode)

                if listMode == .all {
                    LazyVStack(spacing: 12) {
                        ForEach(viewModel.sessions) { session in
                            sessionButton(for: session)
                        }
                    }
                } else {
                    LazyVStack(spacing: 16) {
                        ForEach(sessionSections) { section in
                            VStack(alignment: .leading, spacing: 10) {
                                Button {
                                    toggleSection(section.id)
                                } label: {
                                    SessionSectionHeader(
                                        title: section.title,
                                        subtitle: section.subtitle,
                                        count: section.sessions.count,
                                        isCollapsed: isSectionCollapsed(section.id)
                                    )
                                }
                                .buttonStyle(.plain)

                                if !isSectionCollapsed(section.id) {
                                    ForEach(section.sessions) { session in
                                        sessionButton(for: session)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .padding(24)
        }
    }

    private var sessionSections: [SessionSection] {
        let sessions = viewModel.sessions
        var order: [String] = []
        var grouped: [String: [SessionItem]] = [:]
        for session in sessions {
            let key = session.locationPath ?? "unknown"
            if grouped[key] == nil {
                grouped[key] = []
                order.append(key)
            }
            grouped[key]?.append(session)
        }

        return order.map { key in
            let items = grouped[key] ?? []
            let title: String
            let subtitle: String?
            if key == "unknown" {
                title = "Unknown Location"
                subtitle = nil
            } else {
                title = (key as NSString).lastPathComponent
                subtitle = key
            }
            return SessionSection(id: key, title: title, subtitle: subtitle, sessions: items)
        }
    }

    @ViewBuilder
    private func sessionButton(for session: SessionItem) -> some View {
        Button {
            selectedSession = session
        } label: {
            SessionCardView(session: session)
        }
        .buttonStyle(.plain)
    }

    private func isSectionCollapsed(_ id: String) -> Bool {
        collapsedSectionIds.contains(id)
    }

    private func toggleSection(_ id: String) {
        if collapsedSectionIds.contains(id) {
            collapsedSectionIds.remove(id)
        } else {
            collapsedSectionIds.insert(id)
        }
    }
}

private enum SessionListMode: String, CaseIterable, Identifiable {
    case all = "All"
    case byLocation = "By Location"

    var id: String { rawValue }
}

private struct SessionListModePicker: View {
    @Binding var selection: SessionListMode

    var body: some View {
        Picker("Session view", selection: $selection) {
            ForEach(SessionListMode.allCases) { mode in
                Text(mode.rawValue).tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .frame(maxWidth: 320)
    }
}
