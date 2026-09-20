import Foundation
import FirebaseAuth

enum AuthServiceError: Error {
    case noCurrentUser
}

/// Accès à Firebase Auth (email/mot de passe et Sign in with Apple).
/// C'est le seul endroit de l'app qui importe FirebaseAuth — le reste de l'app passe par ce service.
final class AuthService {
    var currentUser: AppUser? {
        // FirebaseAuth.User est main-actor-isolé depuis le SDK 12.x ; Auth.auth() et
        // ses callbacks s'exécutent toujours sur le main thread en pratique, mais le
        // compilateur ne peut pas le vérifier statiquement ici — assumeIsolated le confirme.
        // Important : appeler Self.map directement, pas le passer en référence à .map(_:) —
        // une closure MainActor perd sa garantie d'isolation en s'échappant comme valeur.
        MainActor.assumeIsolated {
            guard let firebaseUser = Auth.auth().currentUser else { return nil }
            return Self.map(firebaseUser)
        }
    }

    var authStateChanges: AsyncStream<AppUser?> {
        AsyncStream { continuation in
            let handle = Auth.auth().addStateDidChangeListener { _, firebaseUser in
                let user = MainActor.assumeIsolated { () -> AppUser? in
                    guard let firebaseUser else { return nil }
                    return Self.map(firebaseUser)
                }
                continuation.yield(user)
            }
            continuation.onTermination = { _ in
                Auth.auth().removeStateDidChangeListener(handle)
            }
        }
    }

    func signIn(email: String, password: String) async throws -> AppUser {
        let result = try await Auth.auth().signIn(withEmail: email, password: password)
        return Self.map(result.user)
    }

    func signUp(email: String, password: String) async throws -> AppUser {
        let result = try await Auth.auth().createUser(withEmail: email, password: password)
        return Self.map(result.user)
    }

    func signInWithApple(idToken: String, rawNonce: String, displayName: String?) async throws -> AppUser {
        let credential = OAuthProvider.credential(
            providerID: AuthProviderID.apple,
            idToken: idToken,
            rawNonce: rawNonce
        )
        let result = try await Auth.auth().signIn(with: credential)

        // Apple ne fournit le nom qu'à la toute première connexion — Firebase ne le
        // reçoit pas automatiquement, il faut l'écrire nous-mêmes sur le profil.
        if let displayName, result.user.displayName == nil {
            let changeRequest = result.user.createProfileChangeRequest()
            changeRequest.displayName = displayName
            try? await changeRequest.commitChanges()
        }

        return Self.map(result.user)
    }

    func signOut() throws {
        try Auth.auth().signOut()
    }

    // MARK: - Suppression de compte

    /// Méthode de connexion du compte courant : détermine comment le
    /// re-authentifier avant une suppression (opération sensible côté Firebase,
    /// qui exige une connexion récente).
    enum SignInMethod {
        case password
        case apple
        case other
    }

    var signInMethod: SignInMethod {
        MainActor.assumeIsolated {
            let providerIDs = Auth.auth().currentUser?.providerData.map(\.providerID) ?? []
            if providerIDs.contains("apple.com") { return .apple }
            if providerIDs.contains("password") { return .password }
            return .other
        }
    }

    @MainActor
    func reauthenticate(password: String) async throws {
        guard let user = Auth.auth().currentUser, let email = user.email else {
            throw AuthServiceError.noCurrentUser
        }
        let credential = EmailAuthProvider.credential(withEmail: email, password: password)
        try await user.reauthenticate(with: credential)
    }

    @MainActor
    func reauthenticateWithApple(idToken: String, rawNonce: String) async throws {
        guard let user = Auth.auth().currentUser else {
            throw AuthServiceError.noCurrentUser
        }
        let credential = OAuthProvider.credential(
            providerID: AuthProviderID.apple,
            idToken: idToken,
            rawNonce: rawNonce
        )
        try await user.reauthenticate(with: credential)
    }

    /// Apple exige de révoquer le jeton Sign in with Apple quand un compte créé
    /// avec Apple est supprimé. `authorizationCode` vient de la re-authentification
    /// Apple qui précède (à usage unique, valable peu de temps).
    @MainActor
    func revokeAppleToken(authorizationCode: String) async throws {
        try await Auth.auth().revokeToken(withAuthorizationCode: authorizationCode)
    }

    @MainActor
    func deleteCurrentUser() async throws {
        guard let user = Auth.auth().currentUser else {
            throw AuthServiceError.noCurrentUser
        }
        try await user.delete()
    }

    private static func map(_ firebaseUser: FirebaseAuth.User) -> AppUser {
        AppUser(
            id: firebaseUser.uid,
            email: firebaseUser.email ?? "",
            displayName: firebaseUser.displayName
        )
    }
}
