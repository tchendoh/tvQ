import SwiftUI

/// Racine de l'app : route entre LoginView et le contenu principal selon
/// l'état d'authentification, réactif via AuthViewModel.authStateChanges.
struct RootView: View {
    @State private var authViewModel = AuthViewModel()
    @State private var followedShowsStore = FollowedShowsStore()
    // Créé ici (et non dans ScheduleView) pour que l'horaire se précharge dès
    // le lancement, sans attendre la première ouverture de l'onglet Schedule.
    @State private var scheduleViewModel = ScheduleViewModel()

    @AppStorage(AppSettings.Keys.appearance)
    private var appearance: String = AppAppearance.system.rawValue

    var body: some View {
        Group {
            if let user = authViewModel.currentUser {
                MainTabView()
                    .environment(authViewModel)
                    .environment(followedShowsStore)
                    .environment(scheduleViewModel)
                    .task(id: user.id) {
                        followedShowsStore.load(userID: user.id)
                    }
            } else {
                LoginView(viewModel: authViewModel)
            }
        }
        .preferredColorScheme(AppAppearance(rawValue: appearance)?.colorScheme)
        // Déconnexion ou suppression de compte : vider l'état partagé qui vit ici.
        .onChange(of: authViewModel.currentUser?.id) { _, newID in
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
