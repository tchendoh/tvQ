import Foundation

/// Palier 1 du cache d'épisodes : disque local, par appareil. Sert d'abord à
/// éviter de re-solliciter Firestore à chaque ouverture d'écran dans une même
/// session, et permet un affichage instantané (même hors-ligne) avec la
/// dernière donnée connue. Voir FirestoreEpisodeCacheRepository pour le palier
/// partagé entre utilisateurs, et RemoteScheduleRepository pour l'orchestration
/// des trois paliers (local → Firestore → TMDB/TVmaze).
actor LocalEpisodeCache {
    static let shared = LocalEpisodeCache()

    /// Plus court que le TTL Firestore (24h), mais monté de 6h à 12h le
    /// 2026-07-15 : réduit d'environ moitié les lectures Firestore répétées par
    /// utilisateur actif (jusqu'à 2 lectures/série/jour au lieu de 4), au prix
    /// d'un délai de propagation max plus long (jusqu'à ~36h dans le pire cas,
    /// contre ~30h avant, en combinant ce palier et celui de Firestore) —
    /// acceptable pour des épisodes qui changent rarement d'un jour à l'autre.
    nonisolated static let ttl: TimeInterval = 60 * 60 * 12 // 12h

    private var entries: [String: EpisodeCacheEntry] = [:]
    private var isLoaded = false
    private let fileURL: URL

    init(fileURL: URL = LocalEpisodeCache.defaultFileURL) {
        self.fileURL = fileURL
    }

    private static var defaultFileURL: URL {
        let dir = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("tvQ", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("episode_cache.json")
    }

    private func loadIfNeeded() {
        guard !isLoaded else { return }
        isLoaded = true
        guard let data = try? Data(contentsOf: fileURL) else { return }
        entries = (try? JSONDecoder().decode([String: EpisodeCacheEntry].self, from: data)) ?? [:]
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    /// nil si absent en cache ou périmé. `maxAge: nil` désactive toute
    /// expiration — utilisé pour les séries .ended par RemoteScheduleRepository :
    /// leurs épisodes ne changeront plus jamais, donc une fois en cache, elles
    /// n'ont plus jamais besoin d'être revalidées.
    func episodes(showID: String, maxAge: TimeInterval? = LocalEpisodeCache.ttl) -> [Episode]? {
        loadIfNeeded()
        guard let entry = entries[showID] else { return nil }
        if let maxAge {
            guard Date().timeIntervalSince(entry.syncedAt) < maxAge else { return nil }
        }
        return entry.episodes
    }

    func store(showID: String, episodes: [Episode], syncedAt: Date = Date()) {
        loadIfNeeded()
        entries[showID] = EpisodeCacheEntry(episodes: episodes, syncedAt: syncedAt)
        persist()
    }
}

struct EpisodeCacheEntry: Codable {
    let episodes: [Episode]
    let syncedAt: Date
}
