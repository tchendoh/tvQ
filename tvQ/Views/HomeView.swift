import SwiftUI

/// Onglet Accueil : fournit la navigation (pile, titre, réglages, destination des
/// fiches) autour de la page des recommandations, qui contient tout le reste.
struct HomeView: View {
    var body: some View {
        NavigationStack {
            RecommendationsView()
                .navigationTitle("Home")
                .settingsToolbarItem()
                .navigationDestination(for: ShowSummary.self) { summary in
                    ShowDetailView(tmdbID: summary.tmdbID)
                }
        }
    }
}

#Preview {
    HomeView()
        .environment(FollowedShowsStore())
}
