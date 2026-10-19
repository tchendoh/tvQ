import Testing
import Foundation
@testable import tvQ

struct CachePolicyTests {
    private let policy = CachePolicy(maxAge: 100)
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    @Test func recentEntryIsFresh() {
        #expect(policy.isFresh(syncedAt: now - 99, now: now))
    }

    @Test func oldEntryIsStale() {
        #expect(!policy.isFresh(syncedAt: now - 100, now: now))
        #expect(!policy.isFresh(syncedAt: now - 10_000, now: now))
    }

    @Test func endedShowNeverGoesStale() {
        #expect(policy.isFresh(syncedAt: now - 10_000_000, isEnded: true, now: now))
    }

    /// La copie locale reprend la date d'origine de la copie Firestore : plus courte,
    /// elle serait aussitôt périmée et relirait Firestore à chaque chargement.
    @Test func localCacheLivesAtLeastAsLongAsSharedCache() {
        #expect(CachePolicy.local.maxAge >= CachePolicy.shared.maxAge)
    }
}
