import SwiftUI

/// Page d'arrivée de l'app — pensée pour la découverte plutôt que le suivi
/// personnel (voir MyShowsView et ScheduleView pour ça). Trois listes toutes
/// faites de TMDB, clairement étiquetées comme telles : ce ne sont pas des
/// métriques propres à tvQ (voir BACKLOG.md pour la discussion sur une future
/// section "Tendances" internes, mise de côté pour l'instant faute d'assez
/// d'utilisateurs pour que ce soit pertinent).
struct HomeView: View {
    @State private var viewModel = HomeViewModel()
    @Environment(FollowedShowsStore.self) private var followedShowsStore

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading && viewModel.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let errorMessage = viewModel.errorMessage, viewModel.isEmpty {
                    ContentUnavailableView(
                        "Something went wrong",
                        systemImage: "exclamationmark.triangle",
                        description: Text(errorMessage)
                    )
                } else if viewModel.isEmpty {
                    ContentUnavailableView(
                        "Nothing to discover yet",
                        systemImage: "sparkles",
                        description: Text("Shows to discover will show up here.")
                    )
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 28) {
                            section(title: "Trending", shows: viewModel.trending)
                            section(title: "On the air", shows: viewModel.onTheAir)
                            section(title: "Airing today", shows: viewModel.airingToday)
                        }
                        .padding(.vertical, 20)
                    }
                }
            }
            .navigationTitle("Home")
            .settingsToolbarItem()
            .navigationDestination(for: ShowSummary.self) { summary in
                ShowDetailView(tmdbID: summary.tmdbID)
            }
            .task { viewModel.load() }
        }
    }

    @ViewBuilder
    private func section(title: LocalizedStringKey, shows: [ShowSummary]) -> some View {
        if !shows.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(title)
                        .font(.title3.weight(.semibold))

                    // Attribution explicite : ce classement vient de TMDB, pas
                    // d'une mesure propre à tvQ — voir le commentaire en tête
                    // de fichier.
                    Text("via TMDB")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 20)

                LazyVGrid(columns: gridColumns, spacing: 24) {
                    ForEach(shows) { summary in
                        // Contrairement à My Shows (où unfollow retire la carte, ce
                        // qui rendait un retour en arrière confus), ici la série
                        // reste affichée qu'elle soit suivie ou non — le badge peut
                        // donc rester tapable sans ce risque.
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
                .padding(.horizontal, 20)
            }
        }
    }

    private var gridColumns: [GridItem] {
        [GridItem(.adaptive(minimum: 150, maximum: 200), spacing: 24)]
    }
}

#Preview {
    HomeView()
}
