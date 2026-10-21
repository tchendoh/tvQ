import Foundation
import Observation

/// Session de l'utilisateur pour toute l'app : qui est connecté, et la déconnexion.
/// Il y a toujours un utilisateur : sans compte, une session anonyme Firebase est
/// ouverte d'office (premier lancement, déconnexion, suppression de compte).
/// Créé une seule fois dans RootView et injecté en environment.
///
/// `currentUser` ne vient que du flux `authStateChanges` de Firebase : connexion,
/// déconnexion et suppression de compte le mettent à jour d'elles-mêmes, sans que
/// personne n'ait à l'assigner.
@Observable
final class SessionStore {
    private(set) var currentUser: AppUser?

    enum AnonymousSessionState {
        case idle
        case starting
        /// Échec, le plus souvent faute de réseau au premier lancement.
        case failed
    }

    private(set) var anonymousSessionState: AnonymousSessionState = .idle

    private let authService: any AuthServicing

    init(authService: any AuthServicing = AuthService()) {
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
            if user == nil {
                await startAnonymousSession()
            }
        }
    }

    /// Ouvre une session anonyme. Appelée par `observe()` et par le bouton
    /// « Try Again » de l'écran de lancement.
    func startAnonymousSession() async {
        guard anonymousSessionState != .starting, currentUser == nil else { return }
        anonymousSessionState = .starting
        do {
            try await authService.signInAnonymously()
            anonymousSessionState = .idle
        } catch {
            anonymousSessionState = .failed
        }
    }

    /// Relit l'utilisateur courant. Nécessaire après un rattachement (courriel ou
    /// Apple ajouté à la session anonyme) : l'uid ne change pas, donc le flux
    /// `authStateChanges` ne signale rien.
    func refresh() {
        currentUser = authService.currentUser
    }

    /// Méthode de connexion du compte courant (affichée dans Settings › Account).
    var signInMethod: AuthService.SignInMethod {
        authService.signInMethod
    }

    func signOut() throws {
        try authService.signOut()
    }
}
