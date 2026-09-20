import Foundation
import SwiftData

/// Base SwiftData locale de l'app. Ne contient que des données recréables depuis
/// TMDB/TVmaze (c'est un cache) : si le fichier est illisible ou incompatible après
/// une mise à jour du schéma, on le supprime et on repart à neuf plutôt que de planter.
nonisolated enum LocalDatabase {
    static let schema = Schema([
        ShowEntity.self,
        EpisodeEntity.self,
        EpisodeSyncEntity.self,
        WatchAvailabilityEntity.self
    ])

    static let container: ModelContainer = {
        removeLegacyCacheFiles()
        return makeContainer()
    }()

    /// Anciens caches JSON (avant SwiftData) : plus lus par personne, on les supprime
    /// pour ne pas laisser de fichiers orphelins sur l'appareil. Sans effet s'ils sont absents.
    private static func removeLegacyCacheFiles() {
        let directory = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("tvQ", isDirectory: true)
        for name in ["show_cache.json", "episode_cache.json", "watch_availability_cache.json"] {
            try? FileManager.default.removeItem(at: directory.appendingPathComponent(name))
        }
    }

    /// `inMemory: true` pour les tests : aucune écriture sur disque.
    static func makeContainer(inMemory: Bool = false) -> ModelContainer {
        let configuration = ModelConfiguration("tvQ", schema: schema, isStoredInMemoryOnly: inMemory)

        if let container = try? ModelContainer(for: schema, configurations: [configuration]) {
            return container
        }

        // Cache irrécupérable : on supprime les fichiers SQLite et on réessaie une fois.
        let url = configuration.url
        for suffix in ["", "-shm", "-wal"] {
            try? FileManager.default.removeItem(at: URL(fileURLWithPath: url.path + suffix))
        }
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Impossible d'ouvrir la base locale : \(error)")
        }
    }
}
