import Testing
import Foundation
@testable import tvQ

@MainActor
struct DeleteAccountViewModelTests {
    private let auth = FakeAuth(currentUser: .anonymous("anon"))
    private let shows = FakeUserShows()

    private func makeViewModel() -> DeleteAccountViewModel {
        DeleteAccountViewModel(userID: "anon", authService: auth, userShowsService: shows)
    }

    @Test func anonymousSessionIsDetected() {
        #expect(makeViewModel().isAnonymous)
        auth.currentUser = .account("alice")
        #expect(!makeViewModel().isAnonymous)
    }

    @Test func eraseDeletesDataThenUser() async {
        let viewModel = makeViewModel()

        await viewModel.eraseAnonymousData()

        #expect(shows.deleteCalls == ["anon"])
        #expect(auth.calls == ["deleteCurrentUser"])
        #expect(viewModel.errorMessage == nil)
    }

    @Test func refusedUserDeletionFallsBackToSignOut() async {
        auth.deleteShouldFail = true
        let viewModel = makeViewModel()

        await viewModel.eraseAnonymousData()

        #expect(shows.deleteCalls == ["anon"])
        #expect(auth.calls == ["deleteCurrentUser", "signOut"])
        #expect(viewModel.errorMessage == nil)
    }

    @Test func failedDataErasureKeepsUser() async {
        shows.deleteShouldFail = true
        let viewModel = makeViewModel()

        await viewModel.eraseAnonymousData()

        #expect(auth.calls.isEmpty)
        #expect(viewModel.errorMessage != nil)
        #expect(!viewModel.isDeleting)
    }
}
