import SwiftUI

/// Racine de l'app : route entre LoginView et le contenu principal selon
/// l'état d'authentification, réactif via SessionStore.
struct RootView: View {
    @State private var session = SessionStore()
    @State private var followedShowsStore = FollowedShowsStore()
    // Créé ici (et non dans ScheduleView) pour que l'horaire se précharge dès
    // le lancement, sans attendre la première ouverture de l'onglet Schedule.
    @State private var scheduleViewModel = ScheduleViewModel()

    @AppStorage(AppSettings.Keys.appearance)
    private var appearance: AppAppearance = .system

    var body: some View {
        Group {
            if let user = session.currentUser {
                MainTabView()
                    .environment(session)
                    .environment(followedShowsStore)
                    .environment(scheduleViewModel)
                    .task(id: user.id) {
                        followedShowsStore.load(userID: user.id)
                    }
            } else {
                LoginView()
            }
        }
        // Écoute Firebase tant que l'app est ouverte ; SwiftUI annule la tâche avec la vue.
        .task { await session.observe() }
        .preferredColorScheme(appearance.colorScheme)
        // Déconnexion ou suppression de compte : vider l'état partagé qui vit ici.
        .onChange(of: session.currentUser?.id) { _, newID in
            if newID == nil {
                followedShowsStore.clear()
                scheduleViewModel.clear()
            }
        }
    }
}

#Preview {
    RootView()
}
