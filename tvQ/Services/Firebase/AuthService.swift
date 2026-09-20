import Foundation
import FirebaseAuth

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

    private static func map(_ firebaseUser: FirebaseAuth.User) -> AppUser {
        AppUser(
            id: firebaseUser.uid,
            email: firebaseUser.email ?? "",
            displayName: firebaseUser.displayName
        )
    }
}
