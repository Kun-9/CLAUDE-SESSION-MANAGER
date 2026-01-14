import Foundation
import SwiftUI

struct SessionView: View {
    @StateObject private var viewModel = SessionListViewModel()
    @Binding var selectedSession: SessionItem?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                SectionHeaderView(
                    title: "Session",
                    subtitle: "Manage your claude-code sessions."
                )

                SessionListModePicker(selection: $viewModel.listMode)

                if viewModel.listMode == .all {
                    LazyVStack(spacing: 12) {
                        ForEach(viewModel.sessions) { session in
                            sessionButton(for: session)
                        }
                    }
                } else {
                    LazyVStack(spacing: 16) {
                        ForEach(viewModel.sessionSections) { section in
                            VStack(alignment: .leading, spacing: 10) {
                                Button {
                                    viewModel.toggleSection(section.id)
                                } label: {
                                    SessionSectionHeader(
                                        title: section.title,
                                        subtitle: section.subtitle,
                                        count: section.sessions.count,
                                        isCollapsed: viewModel.isSectionCollapsed(section.id)
                                    )
                                }
                                .buttonStyle(.plain)

                                if !viewModel.isSectionCollapsed(section.id) {
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

    @ViewBuilder
    private func sessionButton(for session: SessionItem) -> some View {
        Button {
            selectedSession = session
        } label: {
            SessionCardView(session: session)
        }
        .buttonStyle(.plain)
    }
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
