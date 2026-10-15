import SwiftUI

struct MainTabView: View {
    @Environment(FollowedShowsStore.self) private var followedShowsStore
    @Environment(ScheduleViewModel.self) private var scheduleViewModel

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
        /// Préchargement de l'horaire au lancement : un TabView n'évalue un onglet
        /// qu'à sa première apparition, donc le déclencheur vit ici plutôt que
        /// dans ScheduleView. Se relance à chaque follow/unfollow.
        .task(id: followedShowsStore.followedShowIDs) {
            scheduleViewModel.load(showIDs: followedShowsStore.followedShowIDs)
        }
    }
}

#Preview {
    MainTabView()
        .environment(SessionStore())
        .environment(FollowedShowsStore())
        .environment(ScheduleViewModel())
}
