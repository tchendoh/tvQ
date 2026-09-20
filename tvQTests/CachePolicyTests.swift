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

    @Test func sharedCacheLivesLongerThanLocalCache() {
        #expect(CachePolicy.shared.maxAge > CachePolicy.local.maxAge)
    }
}
