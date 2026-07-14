import SwiftUI

/// Racine de l'app : route entre LoginView et le contenu principal selon
/// l'état d'authentification, réactif via AuthViewModel.authStateChanges.
struct RootView: View {
    @State private var authViewModel = AuthViewModel()
    @State private var followedShowsStore = FollowedShowsStore()

    @AppStorage(AppSettings.Keys.appearance)
    private var appearance: String = AppAppearance.system.rawValue

    var body: some View {
        Group {
            if let user = authViewModel.currentUser {
                MainTabView()
                    .environment(authViewModel)
                    .environment(followedShowsStore)
                    .task(id: user.id) {
                        followedShowsStore.load(userID: user.id)
                    }
            } else {
                LoginView(viewModel: authViewModel)
            }
        }
        .preferredColorScheme(AppAppearance(rawValue: appearance)?.colorScheme)
    }
}

#Preview {
    RootView()
}
