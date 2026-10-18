import Testing
import Foundation
@testable import tvQ

struct TMDBTokenTests {
    @Test func cachedTokenIsReturnedImmediatelyAndRefreshedOnce() async throws {
        let source = FakeTokenSource(cached: "ancien", delay: .milliseconds(50))
        let token = TMDBToken(source: source)

        #expect(try await token.value() == "ancien")
        #expect(try await token.value() == "ancien")

        try await Task.sleep(for: .milliseconds(150))
        #expect(source.fetchCount == 1)   // un seul rafraîchissement par lancement
    }

    @Test func firstLaunchWaitsForTheFetch() async throws {
        let source = FakeTokenSource(cached: nil, afterFetch: "neuf", delay: .milliseconds(30))
        let token = TMDBToken(source: source)

        #expect(try await token.value() == "neuf")
        #expect(source.fetchCount == 1)
    }

    @Test func concurrentFirstCallersShareOneFetch() async throws {
        let source = FakeTokenSource(cached: nil, afterFetch: "neuf", delay: .milliseconds(50))
        let token = TMDBToken(source: source)

        async let a = token.value()
        async let b = token.value()
        async let c = token.value()
        let results = try await [a, b, c]

        #expect(results == ["neuf", "neuf", "neuf"])
        #expect(source.fetchCount == 1)
    }

    @Test func prefetchThenValueMakesOneFetch() async throws {
        let source = FakeTokenSource(cached: nil, afterFetch: "neuf", delay: .milliseconds(30))
        let token = TMDBToken(source: source)

        await token.prefetch()
        #expect(try await token.value() == "neuf")
        #expect(source.fetchCount == 1)
    }

    /// Hors ligne au premier lancement : erreur, puis nouvel essai à la requête suivante.
    @Test func failedFetchIsRetriedOnNextRequest() async throws {
        let source = FakeTokenSource(cached: nil, afterFetch: "neuf", failures: 1)
        let token = TMDBToken(source: source)

        await #expect(throws: FakeError.self) { try await token.value() }
        #expect(try await token.value() == "neuf")
        #expect(source.fetchCount == 2)
    }

    @Test func emptyValueInConsoleIsAnExplicitError() async {
        let source = FakeTokenSource(cached: nil, afterFetch: "")
        let token = TMDBToken(source: source)

        await #expect(throws: TMDBToken.TokenError.self) { try await token.value() }
    }

    // MARK: - Jeton refusé par TMDB (401)

    /// Rotation dans la console pendant que l'app tourne : la requête refusée récupère
    /// le nouveau jeton sans relancement.
    @Test func rejectedTokenIsReplacedWithoutRelaunch() async throws {
        let source = FakeTokenSource(cached: "bidon")
        let token = TMDBToken(source: source)
        #expect(try await token.value() == "bidon")
        try await Task.sleep(for: .milliseconds(50))   // fin du rafraîchissement d'arrière-plan

        source.publish("bon")
        let fresh = try await token.refreshAfterRejection(of: "bidon")

        #expect(fresh == "bon")
        #expect(try await token.value() == "bon")
        #expect(source.forcedFetchCount == 1)
    }

    @Test func unchangedTokenGivesNil() async throws {
        let source = FakeTokenSource(cached: "bidon", afterFetch: "bidon")
        let token = TMDBToken(source: source)

        #expect(try await token.refreshAfterRejection(of: "bidon") == nil)
    }

    /// Un jeton toujours invalide ne doit pas déclencher une récupération par requête.
    @Test func forcedFetchesAreThrottled() async throws {
        let source = FakeTokenSource(cached: "bidon", afterFetch: "bidon")
        let token = TMDBToken(source: source)
        let start = Date.now

        _ = try await token.refreshAfterRejection(of: "bidon", now: start)
        _ = try await token.refreshAfterRejection(of: "bidon", now: start.addingTimeInterval(30))
        #expect(source.forcedFetchCount == 1)

        _ = try await token.refreshAfterRejection(of: "bidon", now: start.addingTimeInterval(61))
        #expect(source.forcedFetchCount == 2)
    }

    @Test func simultaneousRejectionsShareOneForcedFetch() async throws {
        let source = FakeTokenSource(cached: "bidon", afterFetch: "bon", delay: .milliseconds(50))
        let token = TMDBToken(source: source)

        async let a = token.refreshAfterRejection(of: "bidon")
        async let b = token.refreshAfterRejection(of: "bidon")
        let results = try await [a, b]

        #expect(results == ["bon", "bon"])
        #expect(source.forcedFetchCount == 1)
    }

    /// Une autre requête a déjà récupéré le nouveau jeton : pas de nouvel appel.
    @Test func alreadyRefreshedTokenIsReturnedDirectly() async throws {
        let source = FakeTokenSource(cached: "bon")
        let token = TMDBToken(source: source)

        #expect(try await token.refreshAfterRejection(of: "bidon") == "bon")
        #expect(source.forcedFetchCount == 0)
    }
}
