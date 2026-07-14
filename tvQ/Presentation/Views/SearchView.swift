import SwiftUI

struct SearchView: View {
    @State private var viewModel = SearchViewModel()
    @Environment(FollowedShowsStore.self) private var followedShowsStore

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.query.isEmpty {
                    ContentUnavailableView(
                        "Find a show",
                        systemImage: "magnifyingglass",
                        description: Text("Type a title to get started.")
                    )
                } else if viewModel.results.isEmpty && !viewModel.isLoading {
                    ContentUnavailableView.search(text: viewModel.query)
                } else {
                    ScrollView {
                        LazyVGrid(columns: gridColumns, spacing: 24) {
                            ForEach(viewModel.results) { summary in
                                let showID = String(summary.tmdbID)
                                NavigationLink(value: summary) {
                                    ShowCardView(
                                        title: summary.title,
                                        posterURL: summary.posterURL,
                                        isFollowed: followedShowsStore.isFollowing(showID),
                                        onToggleFollow: { followedShowsStore.toggle(showID: showID) }
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(20)
                    }
                }
            }
            .navigationTitle("Search")
            .searchable(text: $viewModel.query, prompt: "Show title")
            .onChange(of: viewModel.query) {
                viewModel.search()
            }
            .overlay(alignment: .top) {
                if viewModel.isLoading {
                    ProgressView()
                        .padding()
                }
            }
            .alert(
                "Error",
                isPresented: isShowingError,
                presenting: viewModel.errorMessage
            ) { _ in
                Button("OK") { viewModel.dismissError() }
            } message: { message in
                Text(message)
            }
            .navigationDestination(for: ShowSummary.self) { summary in
                ShowDetailView(tmdbID: summary.tmdbID)
            }
            .settingsToolbarItem()
        }
    }

    // minimum 150 force 2 colonnes sur iPhone (3 ne rentrent plus) — plus d'air,
    // affiches plus grandes et plus lisibles, voir discussion sur l'esthétique.
    private var gridColumns: [GridItem] {
        [GridItem(.adaptive(minimum: 150, maximum: 200), spacing: 24)]
    }

    // Un vrai Binding, pas .constant() : fermer l'alerte doit pouvoir réinitialiser
    // errorMessage, sinon SwiftUI la considère encore "présentée" indéfiniment.
    private var isShowingError: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil },
            set: { isPresented in
                if !isPresented { viewModel.dismissError() }
            }
        )
    }
}

#Preview {
    SearchView()
        .environment(FollowedShowsStore())
}
