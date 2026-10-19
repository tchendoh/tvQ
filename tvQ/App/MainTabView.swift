import SwiftUI

struct MainTabView: View {
    @Environment(FollowedShowsStore.self) private var followedShowsStore
    @Environment(ScheduleViewModel.self) private var scheduleViewModel
    @Bindable private var notificationRouter = NotificationRouter.shared

    private enum AppTab {
        case home, schedule, myShows, search
    }

    @State private var selectedTab: AppTab = .home

    /// Le setter est appelé même quand on touche l'onglet déjà actif : c'est ce qui
    /// permet de reconnaître un deuxième toucher sur Schedule. iOS remonte alors la
    /// liste tout en haut ; on la ramène plutôt sur « Aujourd'hui ».
    private var tabSelection: Binding<AppTab> {
        Binding(
            get: { selectedTab },
            set: { tab in
                if tab == .schedule, selectedTab == .schedule {
                    scheduleViewModel.requestScrollToToday()
                }
                selectedTab = tab
            }
        )
    }

    var body: some View {
        TabView(selection: tabSelection) {
            HomeView()
                .tabItem {
                    Label("Home", systemImage: "flame")
                }
                .tag(AppTab.home)

            ScheduleView()
                .tabItem {
                    Label("Schedule", systemImage: "calendar")
                }
                .tag(AppTab.schedule)

            MyShowsView()
                .tabItem {
                    Label("My Shows", systemImage: "tv")
                }
                .tag(AppTab.myShows)

            SearchView()
                .tabItem {
                    Label("Search", systemImage: "magnifyingglass")
                }
                .tag(AppTab.search)
        }
        /// Préchargement de l'horaire au lancement : un TabView n'évalue un onglet
        /// qu'à sa première apparition, donc le déclencheur vit ici plutôt que
        /// dans ScheduleView. Se relance à chaque follow/unfollow.
        .task(id: followedShowsStore.followedShowIDs) {
            scheduleViewModel.load(showIDs: followedShowsStore.followedShowIDs)
        }
        // La base locale a changé (rafraîchissement en arrière-plan, nouvelle série,
        // cache vidé) : on relit l'horaire depuis SwiftData, sans réseau. Le court délai
        // regroupe les rafales : chaque nouvel incrément annule la relecture en attente.
        .task(id: LocalDataVersion.shared.value) {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            await scheduleViewModel.reloadFromLocal()
        }
        // load() recharge tout l'horaire : suffit pour passer à la nouvelle langue.
        .onContentLanguageChange {
            scheduleViewModel.load(showIDs: followedShowsStore.followedShowIDs)
        }
        .schedulesEpisodeNotifications()
        // Toucher une notification : fiche de la série par-dessus l'onglet courant.
        .presentsShowDetailSheet(tmdbID: $notificationRouter.tmdbID)
        // Toucher une Live Activity : même fiche (lien tvq://show/{id}).
        .onOpenURL { url in
            if let tmdbID = TvQLink.tmdbID(from: url) {
                notificationRouter.tmdbID = tmdbID
            }
        }
        // Erreurs des séries suivies (chargement, follow/unfollow), communes à tous
        // les onglets : affichées ici une seule fois plutôt que dans chaque écran.
        .alert(
            "Error",
            isPresented: Binding(
                get: { followedShowsStore.errorMessage != nil },
                set: { if !$0 { followedShowsStore.dismissError() } }
            ),
            presenting: followedShowsStore.errorMessage
        ) { _ in
            Button("OK") { followedShowsStore.dismissError() }
        } message: { message in
            Text(message)
        }
    }
}

#Preview {
    MainTabView()
        .environment(SessionStore())
        .environment(FollowedShowsStore())
        .environment(ScheduleViewModel())
}
