import Foundation
import Observation
import AuthenticationServices

/// Pilote l'authentification pour toute l'app : à la fois l'écran de connexion
/// et le routage racine (LoginView vs contenu principal), via authStateChanges.
/// Ne connaît que AuthService — aucune référence directe à FirebaseAuth ici.
@Observable
final class AuthViewModel {
    private(set) var currentUser: AppUser?
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    var email: String = ""
    var password: String = ""
    var mode: Mode = .signIn

    enum Mode {
        case signIn
        case signUp
    }

    private let authService: AuthService
    private var authStateTask: Task<Void, Never>?

    /// Nonce brut en attente de la réponse d'Apple — généré à chaque requête,
    /// consommé (et effacé) une fois le sign-in Firebase tenté.
    private var pendingAppleNonce: String?

    init(authService: AuthService = AuthService()) {
        self.authService = authService
        currentUser = authService.currentUser
        observeAuthState()
    }

    deinit {
        authStateTask?.cancel()
    }

    private func observeAuthState() {
        authStateTask = Task { [weak self] in
            guard let self else { return }
            for await user in authService.authStateChanges {
                self.currentUser = user
            }
        }
    }

    func toggleMode() {
        mode = mode == .signIn ? .signUp : .signIn
        errorMessage = nil
    }

    /// Appelée depuis LoginView. currentUser se met à jour via authStateChanges,
    /// pas besoin de l'assigner directement au succès.
    func submit() {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedEmail.isEmpty, !password.isEmpty else {
            errorMessage = String(localized: "Enter an email and password.")
            return
        }

        Task {
            isLoading = true
            errorMessage = nil
            defer { isLoading = false }

            do {
                switch mode {
                case .signIn:
                    _ = try await authService.signIn(email: trimmedEmail, password: password)
                case .signUp:
                    _ = try await authService.signUp(email: trimmedEmail, password: password)
                }
            } catch {
                errorMessage = mode == .signIn
                    ? String(localized: "Sign in failed. Check your email and password.")
                    : String(localized: "Sign up failed: \(error.localizedDescription)")
            }
        }
    }

    /// Appelée depuis le onRequest de SignInWithAppleButton. Génère un nouveau nonce
    /// à chaque tentative (anti-rejeu) et configure la requête Apple avec sa version hachée.
    func prepareAppleSignInRequest(_ request: ASAuthorizationAppleIDRequest) {
        let nonce = AppleSignInNonce.random()
        pendingAppleNonce = nonce
        request.requestedScopes = [.fullName, .email]
        request.nonce = AppleSignInNonce.sha256(nonce)
    }

    /// Appelée depuis le onCompletion de SignInWithAppleButton.
    func handleAppleSignInResult(_ result: Result<ASAuthorization, Error>) {
        let nonce = pendingAppleNonce
        pendingAppleNonce = nil

        switch result {
        case .failure(let error):
            // L'utilisateur a annulé la fenêtre Apple — pas une vraie erreur à afficher.
            let nsError = error as NSError
            if nsError.code != ASAuthorizationError.canceled.rawValue {
                errorMessage = String(localized: "Sign in with Apple failed.")
            }

        case .success(let authorization):
            guard
                let nonce,
                let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                let tokenData = credential.identityToken,
                let idToken = String(data: tokenData, encoding: .utf8)
            else {
                errorMessage = String(localized: "Sign in with Apple failed.")
                return
            }

            let displayName = [credential.fullName?.givenName, credential.fullName?.familyName]
                .compactMap { $0 }
                .joined(separator: " ")

            Task {
                isLoading = true
                errorMessage = nil
                defer { isLoading = false }

                do {
                    _ = try await authService.signInWithApple(
                        idToken: idToken,
                        rawNonce: nonce,
                        displayName: displayName.isEmpty ? nil : displayName
                    )
                } catch {
                    errorMessage = String(localized: "Sign in with Apple failed.")
                }
            }
        }
    }

    func signOut() {
        do {
            try authService.signOut()
        } catch {
            errorMessage = String(localized: "Sign out failed.")
        }
    }
}
