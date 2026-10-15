import Foundation
import Observation

/// Session de l'utilisateur pour toute l'app : qui est connecté, et la déconnexion.
/// Créé une seule fois dans RootView et injecté en environment.
///
/// `currentUser` ne vient que du flux `authStateChanges` de Firebase : connexion,
/// déconnexion et suppression de compte le mettent à jour d'elles-mêmes, sans que
/// personne n'ait à l'assigner.
@MainActor
@Observable
final class SessionStore {
    private(set) var currentUser: AppUser?

    private let authService: AuthService

    init(authService: AuthService = AuthService()) {
        self.authService = authService
        // Valeur immédiate, pour ne pas afficher LoginView une fraction de seconde
        // avant que le flux ne livre son premier état.
        currentUser = authService.currentUser
    }

    /// Écoute les changements de connexion jusqu'à l'annulation. Appelée depuis
    /// `.task` dans RootView : SwiftUI lance et annule cette tâche avec la vue,
    /// donc aucune Task à conserver ni à annuler à la main.
    func observe() async {
        for await user in authService.authStateChanges {
            currentUser = user
        }
    }

    func signOut() throws {
        try authService.signOut()
    }
}
