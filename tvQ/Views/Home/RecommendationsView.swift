import SwiftUI

/// Page des recommandations : trois listes toutes faites de TMDB (tendances, en
/// ondes, diffusées aujourd'hui), clairement étiquetées comme telles. Ce ne sont
/// pas des métriques propres à tvQ.
///
/// Contient tout le contenu de la page (chargement, états, grilles), mais aucune
/// navigation : les cartes produisent des `NavigationLink(value:)` vers un
/// `ShowSummary`, et c'est l'écran qui l'accueille (HomeView) qui fournit la
/// NavigationStack, le titre et la destination. La page peut ainsi devenir un
/// panneau dans une mise en page plus large (une ArrangementView, par exemple).
struct RecommendationsView: View {
    @State private var viewModel = HomeViewModel()
    /// Largeur minimale d'une carte, qui grandit avec la taille du texte choisie
    /// dans les réglages d'accessibilité.
    @ScaledMetric(relativeTo: .body) private var cardMinimumWidth = ShowCardView.baseMinimumWidth
    @Environment(FollowedShowsStore.self) private var followedShowsStore

    var body: some View {
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
        .task { viewModel.load() }
    }

    @ViewBuilder
    private func section(title: LocalizedStringKey, shows: [ShowSummary]) -> some View {
        if !shows.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(title)
                        .font(.title3.weight(.semibold))

                    // Attribution explicite : ce classement vient de TMDB, pas
                    // d'une mesure propre à tvQ (voir le commentaire en tête
                    // de fichier).
                    Text("via TMDB")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 20)

                EvenGrid(items: shows, minimumWidth: cardMinimumWidth) { summary in
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
                .padding(.horizontal, 20)
            }
        }
    }
}

#Preview {
    NavigationStack {
        RecommendationsView()
    }
    .environment(FollowedShowsStore())
}
