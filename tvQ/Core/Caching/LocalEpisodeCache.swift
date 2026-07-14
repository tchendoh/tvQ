import Foundation

/// Palier 1 du cache d'épisodes : disque local, par appareil. Sert d'abord à
/// éviter de re-solliciter Firestore à chaque ouverture d'écran dans une même
/// session, et permet un affichage instantané (même hors-ligne) avec la
/// dernière donnée connue. Voir FirestoreEpisodeCacheRepository pour le palier
/// partagé entre utilisateurs, et RemoteScheduleRepository pour l'orchestration
/// des trois paliers (local → Firestore → TMDB/TVmaze).
actor LocalEpisodeCache {
    static let shared = LocalEpisodeCache()

    /// Volontairement plus court que le TTL Firestore (24h) : ce palier ne sert
    /// qu'à absorber les lectures répétées pendant une session, pas à réduire
    /// la charge sur les APIs externes — c'est le rôle du palier Firestore.
    static let ttl: TimeInterval = 60 * 60 * 6 // 6h

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

    /// nil si absent en cache ou périmé (plus vieux que Self.ttl).
    func episodes(showID: String) -> [Episode]? {
        loadIfNeeded()
        guard let entry = entries[showID] else { return nil }
        guard Date().timeIntervalSince(entry.syncedAt) < Self.ttl else { return nil }
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
