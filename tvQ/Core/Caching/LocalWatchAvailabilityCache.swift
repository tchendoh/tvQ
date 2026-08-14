import Foundation

/// Cache local (par appareil, pas de palier Firestore partagé) pour
/// WatchAvailability — même pattern que LocalShowCache/LocalEpisodeCache, mais
/// sans palier partagé : la donnée dépend du pays choisi par l'utilisateur
/// (voir AppSettings.watchProviderRegion), donc peu de réutilisation entre
/// utilisateurs contrairement aux métadonnées de série ou aux épisodes.
/// Sert surtout à éviter de refaire un appel TMDB à chaque réouverture de la
/// même fiche série (voir ShowDetailViewModel.load).
actor LocalWatchAvailabilityCache {
    static let shared = LocalWatchAvailabilityCache()

    /// Plus long que le cycle de sync JustWatch → TMDB (max 1×/24h, voir
    /// TMDBClient.fetchWatchProviders) : les diffuseurs d'une série changent
    /// rarement d'un jour à l'autre, pas besoin de revérifier aussi souvent
    /// que le TTL minimal imposé par la fraîcheur des données TMDB.
    nonisolated static let ttl: TimeInterval = 60 * 60 * 72 // 72h

    private var entries: [String: WatchAvailabilityCacheEntry] = [:]
    private var isLoaded = false
    private let fileURL: URL

    init(fileURL: URL = LocalWatchAvailabilityCache.defaultFileURL) {
        self.fileURL = fileURL
    }

    private static var defaultFileURL: URL {
        let dir = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("tvQ", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("watch_availability_cache.json")
    }

    private func loadIfNeeded() {
        guard !isLoaded else { return }
        isLoaded = true
        guard let data = try? Data(contentsOf: fileURL) else { return }
        entries = (try? JSONDecoder().decode([String: WatchAvailabilityCacheEntry].self, from: data)) ?? [:]
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    /// nil si absent ou périmé.
    func availability(cacheKey: String) -> WatchAvailability? {
        loadIfNeeded()
        guard let entry = entries[cacheKey] else { return nil }
        guard Date().timeIntervalSince(entry.syncedAt) < Self.ttl else { return nil }
        return entry.availability
    }

    func store(cacheKey: String, availability: WatchAvailability, syncedAt: Date = Date()) {
        loadIfNeeded()
        entries[cacheKey] = WatchAvailabilityCacheEntry(availability: availability, syncedAt: syncedAt)
        persist()
    }

    /// Vide ce palier — voir LocalShowCache.clear() pour le raisonnement.
    func clear() {
        isLoaded = true
        entries = [:]
        try? FileManager.default.removeItem(at: fileURL)
    }
}

private struct WatchAvailabilityCacheEntry: Codable {
    let availability: WatchAvailability
    let syncedAt: Date
}
