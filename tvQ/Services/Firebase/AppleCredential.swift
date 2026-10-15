import Foundation
import AuthenticationServices

/// Réponse de Sign in with Apple, extraite et validée. Regroupe la logique que
/// la connexion et la réauthentification (suppression de compte) partagent :
/// préparer la requête avec un nonce, ignorer l'annulation, extraire les jetons.
struct AppleCredential {
    enum Failure: Error {
        /// Réponse d'Apple incomplète ou illisible, ou nonce absent.
        case invalidResponse
    }

    let idToken: String
    let rawNonce: String
    /// Présent seulement si Apple l'a fourni ; requis pour révoquer le jeton
    /// à la suppression d'un compte.
    let authorizationCode: String?
    /// Apple ne fournit le nom qu'à la toute première connexion.
    let displayName: String?

    /// Configure la requête Apple et retourne le nonce brut à conserver jusqu'à la
    /// réponse. Un nouveau nonce à chaque tentative (anti-rejeu) ; Apple reçoit sa
    /// version hachée, Firebase recevra la version brute.
    static func prepare(_ request: ASAuthorizationAppleIDRequest, scopes: [ASAuthorization.Scope]) -> String {
        let nonce = AppleSignInNonce.random()
        request.requestedScopes = scopes
        request.nonce = AppleSignInNonce.sha256(nonce)
        return nonce
    }

    /// `nil` : l'utilisateur a annulé la fenêtre Apple, ce qui n'est pas une erreur
    /// à afficher. Lance une erreur si la réponse est inutilisable.
    static func from(_ result: Result<ASAuthorization, Error>, rawNonce: String?) throws -> AppleCredential? {
        switch result {
        case .failure(let error):
            if (error as NSError).code == ASAuthorizationError.canceled.rawValue {
                return nil
            }
            throw error

        case .success(let authorization):
            guard
                let rawNonce,
                let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                let tokenData = credential.identityToken,
                let idToken = String(data: tokenData, encoding: .utf8)
            else {
                throw Failure.invalidResponse
            }

            let authorizationCode = credential.authorizationCode.flatMap { String(data: $0, encoding: .utf8) }
            let name = [credential.fullName?.givenName, credential.fullName?.familyName]
                .compactMap { $0 }
                .joined(separator: " ")

            return AppleCredential(
                idToken: idToken,
                rawNonce: rawNonce,
                authorizationCode: authorizationCode,
                displayName: name.isEmpty ? nil : name
            )
        }
    }
}
