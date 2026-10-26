import SwiftUI

/// Page Accueil : des rangées horizontales d'affiches (modèle App Store et app TV),
/// chacune avec un lien « See all » vers la grille complète.
///
/// 1. Popular on tvQ : séries les plus suivies sur tvQ (trends/current), seulement
///    au-delà d'un seuil d'utilisateurs ; en bêta, une carte d'invitation en attendant.
/// 2. Trending et Airing today : listes toutes faites de TMDB, clairement attribuées
///    (sous-titre de chaque rangée et mention au bas de la page) pour qu'on ne les
///    prenne pas pour des choix de tvQ.
///
/// Aucune navigation propre : HomeView fournit la NavigationStack et le titre.
/// Les cartes ouvrent la fiche dans un sheet (voir ShowDetailSheet.swift).
struct RecommendationsView: View {
    @State private var viewModel = HomeViewModel()
    @State private var selectedTMDBID: Int?

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
                    systemImage: "flame",
                    description: Text("Shows to discover will show up here.")
                )
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 32) {
                        if !viewModel.popularOnTvQ.isEmpty {
                            ShowShelf(
                                title: "Popular on tvQ",
                                subtitle: "Most followed by tvQ users",
                                shows: viewModel.popularOnTvQ,
                                selectedTMDBID: $selectedTMDBID
                            )
                        } else if viewModel.showsTvQInvite {
                            TvQPopularInviteCard()
                                .padding(.horizontal, 20)
                        }

                        ShowShelf(
                            title: "Trending",
                            subtitle: "Most popular this week on TMDB",
                            shows: viewModel.trending,
                            selectedTMDBID: $selectedTMDBID
                        )

                        ShowShelf(
                            title: "Airing today",
                            subtitle: "New episodes today, according to TMDB",
                            shows: viewModel.airingToday,
                            selectedTMDBID: $selectedTMDBID
                        )

                        TMDBListsAttribution()
                            .padding(.horizontal, 20)
                    }
                    .padding(.vertical, 20)
                }
                .refreshable { viewModel.load() }
            }
        }
        .task { viewModel.load() }
        .onContentLanguageChange { viewModel.load() }
        .presentsShowDetailSheet(tmdbID: $selectedTMDBID)
    }
}

/// Carte affichée aux testeurs (TestFlight et Xcode) tant que « Popular on tvQ »
/// n'a pas atteint son seuil. Jamais dans la version App Store (AppDistribution).
private struct TvQPopularInviteCard: View {
    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.title2)
                .foregroundStyle(.tint)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text("Coming soon: popular on tvQ")
                    .font(.headline)
                Text("The most followed shows on tvQ will appear here. The more shows testers follow, the more this ranking will mean.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.tint.opacity(0.1), in: RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .combine)
    }
}

/// Mention unique de la source des listes TMDB, au bas de la page. Remplace les
/// « via TMDB » de chaque section. Dit aussi le seul tri fait par tvQ
/// (AppRules.Recommendations), pour rester exact.
private struct TMDBListsAttribution: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image("TMDbLogo")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(height: 14)
                .accessibilityHidden(true)
            Text("Trending and Airing today come from TMDB. tvQ only leaves out talk shows, news and game shows.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    NavigationStack {
        RecommendationsView()
    }
    .environment(FollowedShowsStore())
}
