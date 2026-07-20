import SwiftUI

/// Racine de navigation de l'app. Chaque onglet possède son propre NavigationStack
/// pour que ShowDetailView reste accessible depuis "À venir" et "Mes séries",
/// pas seulement depuis "Recherche".
struct MainTabView: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem {
                    Label("Home", systemImage: "sparkles")
                }

            ScheduleView()
                .tabItem {
                    Label("Schedule", systemImage: "calendar")
                }

            MyShowsView()
                .tabItem {
                    Label("My Shows", systemImage: "tv")
                }

            SearchView()
                .tabItem {
                    Label("Search", systemImage: "magnifyingglass")
                }
        }
    }
}

#Preview {
    MainTabView()
}
