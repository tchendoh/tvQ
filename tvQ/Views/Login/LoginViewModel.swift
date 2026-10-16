import Foundation
import Observation
import AuthenticationServices

/// Formulaire de connexion et d'inscription (LoginView). Vit le temps de l'écran :
/// courriel et mot de passe disparaissent de la mémoire avec lui.
///
/// Au succès, rien à faire ici : SessionStore reçoit le nouvel utilisateur par le
/// flux Firebase, et RootView remplace LoginView par l'app.
@MainActor
@Observable
final class LoginViewModel {
    enum Mode {
        case signIn
        case signUp
    }

    var email = ""
    var password = ""
    private(set) var mode: Mode = .signIn
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    private let authService: AuthService
    /// Nonce brut en attente de la réponse d'Apple.
    private var pendingAppleNonce: String?

    init(authService: AuthService = AuthService()) {
        self.authService = authService
    }

    func toggleMode() {
        mode = mode == .signIn ? .signUp : .signIn
        errorMessage = nil
    }

    func submit() async {
        guard !isLoading else { return }

        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedEmail.isEmpty, !password.isEmpty else {
            errorMessage = String(localized: "Enter an email and password.")
            return
        }

        await perform {
            switch self.mode {
            case .signIn:
                _ = try await self.authService.signIn(email: trimmedEmail, password: self.password)
            case .signUp:
                _ = try await self.authService.signUp(email: trimmedEmail, password: self.password)
            }
        }
    }

    // MARK: - Sign in with Apple

    /// onRequest de SignInWithAppleButton.
    func prepareAppleRequest(_ request: ASAuthorizationAppleIDRequest) {
        pendingAppleNonce = AppleCredential.prepare(request, scopes: [.fullName, .email])
    }

    /// onCompletion de SignInWithAppleButton.
    func signInWithApple(_ result: Result<ASAuthorization, Error>) async {
        guard !isLoading else { return }

        let nonce = pendingAppleNonce
        pendingAppleNonce = nil

        let credential: AppleCredential
        do {
            guard let parsed = try AppleCredential.from(result, rawNonce: nonce) else { return }
            credential = parsed
        } catch {
            errorMessage = String(localized: "Sign in with Apple failed.")
            return
        }

        await perform {
            _ = try await self.authService.signInWithApple(
                idToken: credential.idToken,
                rawNonce: credential.rawNonce,
                displayName: credential.displayName
            )
        }
    }

    // MARK: - Outils

    /// État de chargement et message d'erreur communs à toutes les façons de se connecter.
    private func perform(_ operation: () async throws -> Void) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            try await operation()
        } catch let error as AuthServiceError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = AuthServiceError.unknown.localizedDescription
        }
    }
}
