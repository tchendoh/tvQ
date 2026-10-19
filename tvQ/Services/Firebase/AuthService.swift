import Foundation
import FirebaseAuth

/// Erreurs propres à l'app : le reste du code ne voit jamais les codes d'erreur
/// de Firebase. `errorDescription` est le texte affiché à l'utilisateur.
enum AuthServiceError: LocalizedError {
    case noCurrentUser
    case invalidCredentials
    case invalidEmail
    case emailAlreadyInUse
    case weakPassword
    case network
    case tooManyRequests
    case unknown

    var errorDescription: String? {
        switch self {
        case .noCurrentUser: String(localized: "You're not signed in.")
        case .invalidCredentials: String(localized: "Incorrect email or password.")
        case .invalidEmail: String(localized: "This email address isn't valid.")
        case .emailAlreadyInUse: String(localized: "An account already exists with this email.")
        case .weakPassword: String(localized: "Choose a password of at least 6 characters.")
        case .network: String(localized: "No connection. Check your network and try again.")
        case .tooManyRequests: String(localized: "Too many attempts. Wait a moment and try again.")
        case .unknown: String(localized: "Something went wrong. Try again.")
        }
    }

    /// Traduit une erreur Firebase Auth. Une erreur qui ne vient pas de Firebase Auth
    /// (ex. annulation) est retournée telle quelle par `translated(_:)`.
    init(firebaseError error: NSError) {
        switch AuthErrorCode(rawValue: error.code) {
        case .wrongPassword, .invalidCredential, .userNotFound: self = .invalidCredentials
        case .invalidEmail: self = .invalidEmail
        case .emailAlreadyInUse: self = .emailAlreadyInUse
        case .weakPassword: self = .weakPassword
        case .networkError: self = .network
        case .tooManyRequests: self = .tooManyRequests
        default: self = .unknown
        }
    }

    static func translated(_ error: Error) -> Error {
        let nsError = error as NSError
        guard nsError.domain == AuthErrorDomain else { return error }
        return AuthServiceError(firebaseError: nsError)
    }
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
            // `nonisolated(unsafe)` : le handle Firebase est un jeton opaque (NSObjectProtocol,
            // donc non Sendable) qu'on ne lit ni ne modifie jamais ; il sert seulement à être
            // rendu à Firebase, dont removeStateDidChangeListener est sûr depuis n'importe quel
            // thread. Exception justifiée à la règle « pas de nonisolated(unsafe) ».
            nonisolated(unsafe) let handle = Auth.auth().addStateDidChangeListener { _, firebaseUser in
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
        do {
            let result = try await Auth.auth().signIn(withEmail: email, password: password)
            return Self.map(result.user)
        } catch {
            throw AuthServiceError.translated(error)
        }
    }

    func signUp(email: String, password: String) async throws -> AppUser {
        do {
            let result = try await Auth.auth().createUser(withEmail: email, password: password)
            return Self.map(result.user)
        } catch {
            throw AuthServiceError.translated(error)
        }
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
    func reauthenticate(password: String) async throws {
        guard let user = Auth.auth().currentUser, let email = user.email else {
            throw AuthServiceError.noCurrentUser
        }
        let credential = EmailAuthProvider.credential(withEmail: email, password: password)
        do {
            try await user.reauthenticate(with: credential)
        } catch {
            throw AuthServiceError.translated(error)
        }
    }
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
    func revokeAppleToken(authorizationCode: String) async throws {
        try await Auth.auth().revokeToken(withAuthorizationCode: authorizationCode)
    }
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
