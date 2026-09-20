import Foundation

/// Palier 1 du cache de métadonnées de série (titre, affiche, statut...) —
/// même rôle que LocalEpisodeCache, mais pour Show plutôt qu'Episode. Voir
/// FirestoreShowCacheService pour le palier partagé, et ShowRepository
/// pour l'orchestration des trois paliers.
actor LocalShowCache {
    static let shared = LocalShowCache()

    /// Même durée que LocalEpisodeCache.ttl (montée à 12h le 2026-07-15) — les
    /// métadonnées de série changent moins souvent que les épisodes, mais rien
    /// ne justifie un TTL différent pour l'instant ; simple à ajuster
    /// séparément si besoin plus tard.
    nonisolated static let ttl: TimeInterval = 60 * 60 * 12 // 12h

    private var entries: [String: ShowCacheEntry] = [:]
    private var isLoaded = false
    private let fileURL: URL

    init(fileURL: URL = LocalShowCache.defaultFileURL) {
        self.fileURL = fileURL
    }

    private static var defaultFileURL: URL {
        let dir = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("tvQ", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("show_cache.json")
    }

    private func loadIfNeeded() {
        guard !isLoaded else { return }
        isLoaded = true
        guard let data = try? Data(contentsOf: fileURL) else { return }
        entries = (try? JSONDecoder().decode([String: ShowCacheEntry].self, from: data)) ?? [:]
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    /// nil si absent ou périmé. Une série dont le statut caché est déjà .ended
    /// ne périme jamais : son statut ne peut plus changer, voir ShowRepository.
    func show(cacheKey: String) -> Show? {
        loadIfNeeded()
        guard let entry = entries[cacheKey] else { return nil }
        if entry.show.status == .ended { return entry.show }
        guard Date().timeIntervalSince(entry.syncedAt) < Self.ttl else { return nil }
        return entry.show
    }

    func store(cacheKey: String, show: Show, syncedAt: Date = Date()) {
        loadIfNeeded()
        entries[cacheKey] = ShowCacheEntry(show: show, syncedAt: syncedAt)
        persist()
    }

    /// Vide ce palier — utilisé par le bouton "Clear local cache" de Settings,
    /// pour tester le chemin de chargement à froid (getShow/getEpisodes sans
    /// rien en cache disque) sans devoir désinstaller l'app.
    func clear() {
        isLoaded = true
        entries = [:]
        try? FileManager.default.removeItem(at: fileURL)
    }
}

private struct ShowCacheEntry: Codable {
    let show: Show
    let syncedAt: Date
}
