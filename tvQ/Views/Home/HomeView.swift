import SwiftUI

/// Onglet Accueil : fournit la navigation (pile, titre, réglages) autour de la page des recommandations, qui contient tout le reste.
struct HomeView: View {
    var body: some View {
        NavigationStack {
            RecommendationsView()
                .navigationTitle("Home")
                .accountToolbarItem()
        }
    }
}

#Preview {
    HomeView()
        .environment(FollowedShowsStore())
}
