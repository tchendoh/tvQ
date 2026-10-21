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

    /// Connexion à un compte existant. Depuis une session anonyme, celle-ci est
    /// abandonnée (voir `replacingAnonymousUser`).
    func signIn(email: String, password: String) async throws -> AppUser {
        do {
            return try await replacingAnonymousUser {
                let result = try await Auth.auth().signIn(withEmail: email, password: password)
                return Self.map(result.user)
            }
        } catch {
            throw AuthServiceError.translated(error)
        }
    }

    // MARK: - Session anonyme

    /// Session sans compte, ouverte d'office par SessionStore. Demande le réseau
    /// la première fois ; Firebase la conserve ensuite sur l'appareil.
    func signInAnonymously() async throws {
        do {
            _ = try await Auth.auth().signInAnonymously()
        } catch {
            throw AuthServiceError.translated(error)
        }
    }

    /// uid de la session courante si elle est anonyme, sinon nil.
    var anonymousUserID: String? {
        guard let user = Auth.auth().currentUser, user.isAnonymous else { return nil }
        return user.uid
    }

    /// Création de compte par courriel. Depuis une session anonyme, le courriel est
    /// rattaché à celle-ci : même uid, donc les séries suivies sont conservées.
    func signUp(email: String, password: String) async throws -> AppUser {
        guard let anonymousUser = Auth.auth().currentUser, anonymousUser.isAnonymous else {
            return try await createUser(email: email, password: password)
        }
        let credential = EmailAuthProvider.credential(withEmail: email, password: password)
        do {
            let result = try await anonymousUser.link(with: credential)
            return Self.map(result.user)
        } catch {
            throw AuthServiceError.translated(error)
        }
    }

    /// Exécute une connexion qui remplace la session courante. Si celle-ci était
    /// anonyme, son utilisateur Firebase est supprimé ensuite (au mieux : un échec
    /// laisse seulement un compte anonyme orphelin, sans conséquence pour l'utilisateur).
    private func replacingAnonymousUser(_ signIn: () async throws -> AppUser) async throws -> AppUser {
        let previous = Auth.auth().currentUser.flatMap { $0.isAnonymous ? $0 : nil }
        let user = try await signIn()
        if let previous, previous.uid != user.id {
            Self.deleteInBackground(previous)
        }
        return user
    }

    private func createUser(email: String, password: String) async throws -> AppUser {
        do {
            let result = try await Auth.auth().createUser(withEmail: email, password: password)
            return Self.map(result.user)
        } catch {
            throw AuthServiceError.translated(error)
        }
    }

    /// Envoie le courriel de réinitialisation de Firebase. Firebase ne révèle pas
    /// si le compte existe (protection contre l'énumération des courriels).
    func sendPasswordReset(email: String) async throws {
        do {
            try await Auth.auth().sendPasswordReset(withEmail: email)
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
        let user: FirebaseAuth.User
        if Auth.auth().currentUser?.isAnonymous == true {
            user = try await linkOrSwitchToApple(credential: credential)
        } else {
            user = try await Auth.auth().signIn(with: credential).user
        }

        // Apple ne fournit le nom qu'à la toute première connexion — Firebase ne le
        // reçoit pas automatiquement, il faut l'écrire nous-mêmes sur le profil.
        if let displayName, user.displayName == nil {
            let changeRequest = user.createProfileChangeRequest()
            changeRequest.displayName = displayName
            await Self.commit(changeRequest)
        }

        return Self.map(user)
    }

    /// Depuis une session anonyme : rattache Apple à celle-ci (séries conservées).
    /// Si ce compte Apple appartient déjà à un compte tvQ, on se connecte plutôt à
    /// ce dernier. Le nonce Apple étant à usage unique, Firebase fournit pour ce cas
    /// un identifiant de remplacement dans l'erreur.
    private func linkOrSwitchToApple(credential: AuthCredential) async throws -> FirebaseAuth.User {
        // Lu sur place et utilisé une seule fois : `link` l'envoie hors du MainActor.
        guard let anonymousUser = Auth.auth().currentUser else {
            throw AuthServiceError.noCurrentUser
        }
        do {
            return try await anonymousUser.link(with: credential).user
        } catch {
            let nsError = error as NSError
            guard AuthErrorCode(rawValue: nsError.code) == .credentialAlreadyInUse,
                  let updatedCredential = nsError.userInfo[AuthErrorUserInfoUpdatedCredentialKey] as? AuthCredential
            else { throw error }

            // Relu après l'échec (toujours la session anonyme), puisque `anonymousUser`
            // a été envoyé à `link` et ne doit plus servir.
            let orphan = Auth.auth().currentUser
            let existingUser = try await Auth.auth().signIn(with: updatedCredential).user
            if let orphan { Self.deleteInBackground(orphan) }
            return existingUser
        }
    }

    // MARK: - Objets Firebase non Sendable
    //
    // FirebaseAuth.User et UserProfileChangeRequest ne sont pas Sendable. Leurs
    // variantes `async` sont nonisolated : les appeler depuis le MainActor « envoie »
    // l'objet ailleurs, ce que Swift 6 refuse dès qu'il reste utilisé ensuite.
    // Les variantes à completion handler s'appellent sur place, sans envoi.

    /// Suppression au mieux d'un compte anonyme abandonné : un échec laisse
    /// seulement un compte orphelin, sans données ni conséquence.
    private static func deleteInBackground(_ user: FirebaseAuth.User) {
        user.delete(completion: nil)
    }

    /// Enregistre le nom fourni par Apple ; un échec n'empêche pas la connexion.
    private static func commit(_ changeRequest: UserProfileChangeRequest) async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            changeRequest.commitChanges { _ in
                continuation.resume()
            }
        }
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
            displayName: firebaseUser.displayName,
            isAnonymous: firebaseUser.isAnonymous
        )
    }
}
