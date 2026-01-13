import SwiftUI

struct SessionView: View {
    @StateObject private var viewModel = SessionListViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                SectionHeaderView(
                    title: "Session",
                    subtitle: "Manage your claude-code sessions."
                )

                LazyVStack(spacing: 12) {
                    ForEach(viewModel.sessions) { session in
                        SessionCardView(session: session)
                    }
                }
            }
            .padding(24)
        }
    }
}
