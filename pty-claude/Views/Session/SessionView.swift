import SwiftUI

struct SessionView: View {
    @StateObject private var viewModel = SessionListViewModel()
    @State private var selectedSession: SessionItem?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                SectionHeaderView(
                    title: "Session",
                    subtitle: "Manage your claude-code sessions."
                )

                LazyVStack(spacing: 12) {
                    ForEach(viewModel.sessions) { session in
                        Button {
                            selectedSession = session
                        } label: {
                            SessionCardView(session: session)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(24)
        }
        .sheet(item: $selectedSession) { session in
            SessionDetailSheet(session: session)
        }
    }
}
