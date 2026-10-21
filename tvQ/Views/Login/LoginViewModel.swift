import Foundation
import Observation
import AuthenticationServices

/// Formulaire de connexion et d'inscription (LoginView). Vit le temps de l'écran :
/// courriel et mot de passe disparaissent de la mémoire avec lui.
///
/// Ouvert en feuille depuis Settings, par-dessus une session anonyme :
/// - Sign Up rattache le courriel ou Apple à cette session (même uid, rien à copier) ;
/// - Sign In passe à un compte existant ; les séries suivies en anonyme y sont
///   alors ajoutées, pour ne rien perdre.
/// Au succès, `didSucceed` passe à true : la vue rafraîchit SessionStore et se ferme.
@Observable
final class LoginViewModel {
    enum Mode {
        case signIn
        case signUp
    }

    var email = ""
    var password = ""
    // Depuis une session anonyme, le cas courant est la création d'un compte.
    private(set) var mode: Mode = .signUp
    private(set) var isLoading = false
    private(set) var errorMessage: String?
    /// Confirmation affichée après l'envoi du courriel de réinitialisation.
    private(set) var infoMessage: String?
    private(set) var didSucceed = false

    private let authService: any AuthServicing
    private let userShowsService: any UserShowsServicing
    /// Nonce brut en attente de la réponse d'Apple.
    private var pendingAppleNonce: String?

    init(
        authService: any AuthServicing = AuthService(),
        userShowsService: any UserShowsServicing = UserShowsService()
    ) {
        self.authService = authService
        self.userShowsService = userShowsService
    }

    func toggleMode() {
        mode = mode == .signIn ? .signUp : .signIn
        errorMessage = nil
        infoMessage = nil
    }

    func submit() async {
        guard !isLoading else { return }

        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedEmail.isEmpty, !password.isEmpty else {
            errorMessage = String(localized: "Enter an email and password.")
            return
        }

        await authenticate(mayLeaveAnonymousSession: mode == .signIn) {
            switch self.mode {
            case .signIn:
                return try await self.authService.signIn(email: trimmedEmail, password: self.password)
            case .signUp:
                return try await self.authService.signUp(email: trimmedEmail, password: self.password)
            }
        }
    }

    // MARK: - Mot de passe oublié

    func resetPassword() async {
        guard !isLoading else { return }

        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedEmail.isEmpty else {
            infoMessage = nil
            errorMessage = String(localized: "Enter your email to reset your password.")
            return
        }

        await perform {
            try await self.authService.sendPasswordReset(email: trimmedEmail)
            self.infoMessage = String(localized: "If an account exists for this email, a reset link has been sent.")
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

        await signInWithApple(credential: credential)
    }

    /// Partie testable de la connexion Apple (ASAuthorization ne se fabrique pas en test).
    func signInWithApple(credential: AppleCredential) async {
        guard !isLoading else { return }
        await authenticate(mayLeaveAnonymousSession: true) {
            return try await self.authService.signInWithApple(
                idToken: credential.idToken,
                rawNonce: credential.rawNonce,
                displayName: credential.displayName
            )
        }
    }

    // MARK: - Outils

    /// Connexion ou création de compte depuis la session courante. Si l'opération
    /// quitte une session anonyme pour un autre compte (uid différent), les séries
    /// qui y étaient suivies sont ajoutées au compte rejoint.
    /// `mayLeaveAnonymousSession` : l'opération peut aboutir sur un autre compte.
    /// Vrai pour Sign In, et pour Apple (compte Apple déjà lié à un compte tvQ).
    private func authenticate(
        mayLeaveAnonymousSession: Bool,
        _ operation: @escaping () async throws -> AppUser
    ) async {
        await perform {
            let anonymousID = self.authService.anonymousUserID
            let anonymousShowIDs = if let anonymousID {
                await self.followedShowIDs(userID: anonymousID)
            } else {
                [String]()
            }

            // Sign In vers un compte existant : la session anonyme va être remplacée,
            // et les règles Firestore n'autoriseront plus la suppression de son
            // document. On l'efface donc maintenant, la liste étant gardée en mémoire.
            // (Sign Up par courriel rattache à la même session : rien à effacer.)
            let leavesAnonymousSession = anonymousID != nil && mayLeaveAnonymousSession
            if let anonymousID, leavesAnonymousSession {
                try await self.userShowsService.deleteAllData(userID: anonymousID)
            }

            let user: AppUser
            do {
                user = try await operation()
            } catch {
                // Connexion échouée : toujours en session anonyme, on remet la liste.
                if let anonymousID, leavesAnonymousSession {
                    await self.follow(anonymousShowIDs, userID: anonymousID)
                }
                throw error
            }

            // Autre compte, ou même session mais liste effacée par précaution (Apple rattaché).
            if let anonymousID, leavesAnonymousSession || user.id != anonymousID {
                await self.follow(anonymousShowIDs, userID: user.id)
            }
            self.didSucceed = true
        }
    }

    private func follow(_ showIDs: [String], userID: String) async {
        for showID in showIDs {
            try? await userShowsService.follow(showID: showID, userID: userID)
        }
    }

    /// Lecture unique de la liste (premier état du flux, cache local compris).
    private func followedShowIDs(userID: String) async -> [String] {
        do {
            for try await shows in userShowsService.followedShowsUpdates(userID: userID) {
                return shows.followedIDs
            }
        } catch {}
        return []
    }

    /// État de chargement et message d'erreur communs à toutes les façons de se connecter.
    private func perform(_ operation: () async throws -> Void) async {
        isLoading = true
        errorMessage = nil
        infoMessage = nil
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
