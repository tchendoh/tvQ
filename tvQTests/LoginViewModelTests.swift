import Testing
import Foundation
@testable import tvQ

/// Connexion depuis une session anonyme : aucune série suivie ne doit se perdre,
/// et le document anonyme ne doit pas rester orphelin dans Firestore.
@MainActor
struct LoginViewModelTests {
    private let auth = FakeAuth(currentUser: .anonymous("anon"))
    private let shows = FakeUserShows()

    init() {
        shows.followed = ["1", "2"]
    }

    private func makeViewModel(mode: LoginViewModel.Mode = .signUp) -> LoginViewModel {
        let viewModel = LoginViewModel(authService: auth, userShowsService: shows)
        if viewModel.mode != mode { viewModel.toggleMode() }
        viewModel.email = "eric@example.com"
        viewModel.password = "secret123"
        return viewModel
    }

    private let appleCredential = AppleCredential(idToken: "token", rawNonce: "nonce", authorizationCode: nil, displayName: nil)

    private func targets(_ userID: String) -> [FakeUserShows.FollowTarget] {
        ["1", "2"].map { FakeUserShows.FollowTarget(showID: $0, userID: userID) }
    }

    // MARK: - Courriel

    @Test func signUpLinksAnonymousSessionWithoutTouchingShows() async {
        auth.signUpResult = .success(.account("anon"))
        let viewModel = makeViewModel(mode: .signUp)

        await viewModel.submit()

        #expect(auth.calls == ["signUp"])
        #expect(shows.deleteCalls.isEmpty)
        #expect(shows.followTargets.isEmpty)
        #expect(viewModel.didSucceed)
    }

    @Test func signInToExistingAccountErasesAnonymousDocumentFirstThenMerges() async {
        auth.signInResult = .success(.account("alice"))
        var deletedBeforeSignIn: [String] = []
        auth.onAuthenticate = { [shows] in deletedBeforeSignIn = shows.deleteCalls }
        let viewModel = makeViewModel(mode: .signIn)

        await viewModel.submit()

        #expect(deletedBeforeSignIn == ["anon"])
        #expect(shows.followTargets == targets("alice"))
        #expect(viewModel.didSucceed)
    }

    @Test func failedSignInRestoresShowsInAnonymousSession() async {
        auth.signInResult = .failure(AuthServiceError.invalidCredentials)
        let viewModel = makeViewModel(mode: .signIn)

        await viewModel.submit()

        #expect(shows.deleteCalls == ["anon"])
        #expect(shows.followTargets == targets("anon"))
        #expect(viewModel.errorMessage == AuthServiceError.invalidCredentials.localizedDescription)
        #expect(!viewModel.didSucceed)
    }

    @Test func failedErasureCancelsSignIn() async {
        shows.deleteShouldFail = true
        let viewModel = makeViewModel(mode: .signIn)

        await viewModel.submit()

        #expect(!auth.calls.contains("signIn"))
        #expect(shows.followTargets.isEmpty)
        #expect(viewModel.errorMessage != nil)
        #expect(!viewModel.didSucceed)
    }

    @Test func signInFromRealAccountDoesNoMerge() async {
        auth.currentUser = .account("bob")
        auth.signInResult = .success(.account("alice"))
        let viewModel = makeViewModel(mode: .signIn)

        await viewModel.submit()

        #expect(shows.loadCalls == 0)
        #expect(shows.deleteCalls.isEmpty)
        #expect(shows.followTargets.isEmpty)
        #expect(viewModel.didSucceed)
    }

    @Test func emptyFieldsShowErrorWithoutCallingAuth() async {
        let viewModel = makeViewModel()
        viewModel.email = "  "

        await viewModel.submit()

        #expect(auth.calls.isEmpty)
        #expect(viewModel.errorMessage != nil)
    }

    // MARK: - Apple

    @Test func appleLinkedToSameSessionRestoresShowsOnSameUID() async {
        auth.appleResult = .success(.account("anon"))
        let viewModel = makeViewModel()

        await viewModel.signInWithApple(credential: appleCredential)

        #expect(shows.deleteCalls == ["anon"])
        #expect(shows.followTargets == targets("anon"))
        #expect(viewModel.didSucceed)
    }

    @Test func appleAlreadyUsedSwitchesAndMerges() async {
        auth.appleResult = .success(.account("bob"))
        let viewModel = makeViewModel()

        await viewModel.signInWithApple(credential: appleCredential)

        #expect(shows.followTargets == targets("bob"))
        #expect(viewModel.didSucceed)
    }

    @Test func failedAppleRestoresShowsInAnonymousSession() async {
        auth.appleResult = .failure(FakeError())
        let viewModel = makeViewModel()

        await viewModel.signInWithApple(credential: appleCredential)

        #expect(shows.followTargets == targets("anon"))
        #expect(viewModel.errorMessage == AuthServiceError.unknown.localizedDescription)
        #expect(!viewModel.didSucceed)
    }

    // MARK: - Mot de passe oublié

    @Test func resetPasswordRequiresEmail() async {
        let viewModel = makeViewModel(mode: .signIn)
        viewModel.email = ""

        await viewModel.resetPassword()

        #expect(auth.calls.isEmpty)
        #expect(viewModel.errorMessage != nil)
        #expect(viewModel.infoMessage == nil)
    }

    @Test func resetPasswordShowsConfirmationWithoutSigningIn() async {
        let viewModel = makeViewModel(mode: .signIn)

        await viewModel.resetPassword()

        #expect(auth.calls == ["sendPasswordReset"])
        #expect(viewModel.infoMessage != nil)
        #expect(viewModel.errorMessage == nil)
        #expect(!viewModel.didSucceed)
    }
}
