import Foundation

/// Gère l'authentification de l'utilisateur.
/// Implémentation concrète dans Data : Firebase Auth.
/// Le déverrouillage Face ID est un détail de Presentation/Core (LocalAuthentication + Keychain),
/// pas de ce protocole : Face ID ne remplace pas une session Firebase, il la redéverrouille.
protocol AuthRepository {
    var currentUser: User? { get }

    /// Flux réactif de l'utilisateur courant, émis à chaque changement d'état
    /// (connexion, déconnexion, expiration de session). Permet à la Presentation
    /// de router entre login et contenu principal sans connaître Firebase.
    var authStateChanges: AsyncStream<User?> { get }

    func signIn(email: String, password: String) async throws -> User
    func signUp(email: String, password: String) async throws -> User

    /// `idToken`/`rawNonce` viennent de ASAuthorizationAppleIDCredential, résolus en
    /// Presentation avant l'appel — Domain reste sans dépendance à AuthenticationServices.
    /// `displayName` n'est fourni par Apple qu'à la toute première connexion.
    func signInWithApple(idToken: String, rawNonce: String, displayName: String?) async throws -> User

    func signOut() throws
}
