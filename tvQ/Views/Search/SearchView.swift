import SwiftUI

struct SearchView: View {
    @State private var viewModel = SearchViewModel()
    @State private var selectedTMDBID: Int?
    /// Largeur minimale d'une carte, qui grandit avec la taille du texte choisie
    /// dans les réglages d'accessibilité.
    @ScaledMetric(relativeTo: .body) private var cardMinimumWidth = ShowCardView.baseMinimumWidth
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
                        EvenGrid(items: viewModel.results, minimumWidth: cardMinimumWidth) { summary in
                            let showID = String(summary.tmdbID)
                            Button { selectedTMDBID = summary.tmdbID } label: {
                                ShowCardView(
                                    title: summary.title,
                                    posterURL: summary.posterURL,
                                    isFollowed: followedShowsStore.isFollowing(showID),
                                    onToggleFollow: { followedShowsStore.toggle(showID: showID) }
                                )
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(20)
                    }
                }
            }
            .navigationTitle("Search")
            .presentsShowDetailSheet(tmdbID: $selectedTMDBID)
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
                isPresented: isPresentingError,
                presenting: viewModel.errorMessage
            ) { _ in
                Button("OK") { viewModel.dismissError() }
            } message: { message in
                Text(message)
            }
            .settingsToolbarItem()
        }
    }

    // Un vrai Binding, pas .constant() : fermer l'alerte doit pouvoir réinitialiser
    // errorMessage, sinon SwiftUI la considère encore "présentée" indéfiniment.
    private var isPresentingError: Binding<Bool> {
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
