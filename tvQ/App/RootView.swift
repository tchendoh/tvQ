import SwiftUI

/// Racine de l'app : affiche le contenu principal dès qu'un utilisateur existe
/// (compte ou session anonyme). LoginView n'est plus une étape obligatoire :
/// elle s'ouvre depuis Settings.
struct RootView: View {
    @State private var session = SessionStore()
    @State private var followedShowsStore = FollowedShowsStore()
    // Créé ici (et non dans ScheduleView) pour que l'horaire se précharge dès
    // le lancement, sans attendre la première ouverture de l'onglet Schedule.
    @State private var scheduleViewModel = ScheduleViewModel()

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
                LaunchView(
                    failed: session.anonymousSessionState == .failed,
                    retry: { Task { await session.startAnonymousSession() } }
                )
            }
        }
        // Écoute Firebase tant que l'app est ouverte ; SwiftUI annule la tâche avec la vue.
        .task { await session.observe() }
        // Déconnexion ou suppression de compte : vider l'état partagé qui vit ici.
        .onChange(of: session.currentUser?.id) { _, newID in
            if newID == nil {
                followedShowsStore.clear()
                scheduleViewModel.clear()
                // MainTabView disparaît avec la session : on ne peut pas compter
                // sur sa synchronisation pour retirer les notifications du compte.
                Task {
                    await NotificationScheduler.shared.removeAll()
                    await LiveActivityScheduler.shared.endAll()
                }
            }
        }
    }
}

/// Écran affiché tant que la session anonyme n'est pas ouverte : en pratique,
/// seulement au tout premier lancement (ou après une déconnexion).
private struct LaunchView: View {
    let failed: Bool
    let retry: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image("tvQAppIcon")
                .resizable()
                .scaledToFit()
                .frame(width: 96, height: 96)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .accessibilityLabel(Text(verbatim: "tvQ"))

            if failed {
                Text("tvQ needs a connection to start the first time.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button("Try Again", action: retry)
                    .buttonStyle(.borderedProminent)
            } else {
                ProgressView()
            }
        }
        .padding(24)
    }
}

#Preview {
    RootView()
}
