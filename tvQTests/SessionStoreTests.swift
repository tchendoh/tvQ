import Testing
import Foundation
@testable import tvQ

/// Il y a toujours un utilisateur : sans compte, une session anonyme s'ouvre d'office.
@MainActor
struct SessionStoreTests {
    private let auth = FakeAuth()

    @Test func noUserStartsAnonymousSession() async {
        let store = SessionStore(authService: auth)
        let observation = Task { await store.observe() }
        defer { observation.cancel() }

        auth.emit(nil)

        #expect(await eventually { store.currentUser?.isAnonymous == true })
        #expect(store.anonymousSessionState == .idle)
    }

    @Test func signOutStartsNewAnonymousSession() async {
        auth.currentUser = .account("alice")
        let store = SessionStore(authService: auth)
        let observation = Task { await store.observe() }
        defer { observation.cancel() }

        try? store.signOut()

        #expect(await eventually { store.currentUser?.isAnonymous == true })
    }

    @Test func failureCanBeRetried() async {
        auth.anonymousSignInShouldFail = true
        let store = SessionStore(authService: auth)
        let observation = Task { await store.observe() }
        defer { observation.cancel() }

        auth.emit(nil)
        #expect(await eventually { store.anonymousSessionState == .failed })
        #expect(store.currentUser == nil)

        auth.anonymousSignInShouldFail = false
        await store.startAnonymousSession()

        #expect(await eventually { store.currentUser?.isAnonymous == true })
        #expect(store.anonymousSessionState == .idle)
    }

    @Test func concurrentStartsSignInOnce() async {
        auth.anonymousSignInDelay = .milliseconds(50)
        let store = SessionStore(authService: auth)

        async let first: Void = store.startAnonymousSession()
        async let second: Void = store.startAnonymousSession()
        _ = await (first, second)

        #expect(auth.anonymousSignInCount == 1)
    }

    @Test func refreshReadsLinkedAccount() {
        auth.currentUser = .anonymous("anon")
        let store = SessionStore(authService: auth)

        auth.currentUser = .account("anon")
        store.refresh()

        #expect(store.currentUser == .account("anon"))
    }
}
