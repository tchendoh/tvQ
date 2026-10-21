import Foundation
import Observation
import AuthenticationServices

/// Suppression de compte (DeleteAccountView). Vit le temps de la feuille modale.
///
/// Au succès, Firebase signale la déconnexion : SessionStore ouvre une nouvelle
/// session anonyme vide, et l'uid qui change ferme aussi cette feuille.
@Observable
final class DeleteAccountViewModel {
    private(set) var isDeleting = false
    private(set) var errorMessage: String?

    private let userID: String
    private let authService: any AuthServicing
    private let userShowsService: any UserShowsServicing
    private var pendingAppleNonce: String?

    init(
        userID: String,
        authService: any AuthServicing = AuthService(),
        userShowsService: any UserShowsServicing = UserShowsService()
    ) {
        self.userID = userID
        self.authService = authService
        self.userShowsService = userShowsService
    }

    /// Le compte a été créé avec Sign in with Apple (sinon courriel et mot de passe) :
    /// détermine comment confirmer l'identité avant de supprimer.
    var usesAppleSignIn: Bool {
        authService.signInMethod == .apple
    }

    /// Session anonyme : rien à revérifier (ni mot de passe ni Apple).
    var isAnonymous: Bool {
        authService.anonymousUserID != nil
    }

    /// Session anonyme : efface les données, puis l'utilisateur Firebase. Si Firebase
    /// refuse la suppression (connexion jugée trop ancienne, impossible à revérifier
    /// pour un anonyme), on se déconnecte : les données sont déjà parties, et
    /// l'utilisateur orphelin n'a plus rien.
    func eraseAnonymousData() async {
        guard !isDeleting else { return }
        isDeleting = true
        errorMessage = nil
        defer { isDeleting = false }

        do {
            try await userShowsService.deleteAllData(userID: userID)
        } catch {
            errorMessage = String(localized: "Couldn't erase your data. Check your connection, then try again.")
            return
        }

        do {
            try await authService.deleteCurrentUser()
        } catch {
            try? authService.signOut()
        }
    }

    /// Compte courriel : réauthentification par mot de passe, puis suppression.
    func deleteAccount(password: String) async {
        await performDeletion {
            try await self.authService.reauthenticate(password: password)
            return nil
        }
    }

    // MARK: - Sign in with Apple

    /// Réauthentification : aucun scope (ni nom ni courriel), seulement un nonce frais.
    func prepareAppleRequest(_ request: ASAuthorizationAppleIDRequest) {
        pendingAppleNonce = AppleCredential.prepare(request, scopes: [])
    }

    /// Compte Apple : mêmes étapes, plus la révocation du jeton Apple exigée par
    /// l'App Store avant la suppression du compte.
    func deleteAccount(withApple result: Result<ASAuthorization, Error>) async {
        let nonce = pendingAppleNonce
        pendingAppleNonce = nil

        let credential: AppleCredential
        do {
            guard let parsed = try AppleCredential.from(result, rawNonce: nonce) else { return }
            credential = parsed
        } catch {
            errorMessage = String(localized: "Couldn't confirm your identity with Apple.")
            return
        }

        guard let authorizationCode = credential.authorizationCode else {
            errorMessage = String(localized: "Couldn't confirm your identity with Apple.")
            return
        }

        await performDeletion {
            try await self.authService.reauthenticateWithApple(idToken: credential.idToken, rawNonce: credential.rawNonce)
            return authorizationCode
        }
    }

    // MARK: - Outils

    /// `reauthenticate` retourne le code d'autorisation Apple à révoquer (nil pour
    /// un compte courriel). Ordre important : les données Firestore partent *avant*
    /// le compte, tant que les règles de sécurité voient l'utilisateur connecté.
    private func performDeletion(reauthenticate: () async throws -> String?) async {
        guard !isDeleting else { return }
        isDeleting = true
        errorMessage = nil
        defer { isDeleting = false }

        do {
            let appleAuthorizationCode = try await reauthenticate()
            try await userShowsService.deleteAllData(userID: userID)
            if let appleAuthorizationCode {
                try await authService.revokeAppleToken(authorizationCode: appleAuthorizationCode)
            }
            try await authService.deleteCurrentUser()
        } catch AuthServiceError.invalidCredentials {
            errorMessage = AuthServiceError.invalidCredentials.localizedDescription
        } catch {
            errorMessage = String(
                localized: "Couldn't delete your account. Check your password and connection, then try again."
            )
        }
    }
}
