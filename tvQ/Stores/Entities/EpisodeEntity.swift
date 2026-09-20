import Foundation
import SwiftData

/// Forme persistée d'un `Episode`. Les champs sont à plat (pas de JSON) parce que
/// l'écran Schedule filtre par date directement dans le store (voir EpisodeStore).
///
/// `cacheKey` (tmdbID + langue, voir AppSettings.cacheLanguageKey) regroupe les
/// épisodes d'une même série dans une même langue : c'est la clé de remplacement.
/// `uid` combine cette clé et l'id de l'épisode, pour que la même série en deux
/// langues ne s'écrase pas.
///
/// `nonisolated` est nécessaire parce que le projet est isolé au MainActor par défaut,
/// alors que ces objets sont manipulés depuis un actor (EpisodeStore).
@Model
nonisolated final class EpisodeEntity {
    @Attribute(.unique) var uid: String
    var cacheKey: String

    var episodeID: String
    var showID: String
    var seasonNumber: Int
    var episodeNumber: Int
    var title: String
    var overview: String
    var stillImageURL: URL?
    var airDate: Date?
    var hasPreciseTime: Bool

    init(cacheKey: String, episode: Episode) {
        self.uid = "\(cacheKey)|\(episode.id)"
        self.cacheKey = cacheKey
        self.episodeID = episode.id
        self.showID = episode.showID
        self.seasonNumber = episode.seasonNumber
        self.episodeNumber = episode.episodeNumber
        self.title = episode.title
        self.overview = episode.overview
        self.stillImageURL = episode.stillImageURL
        self.airDate = episode.airDate
        self.hasPreciseTime = episode.hasPreciseTime
    }

    func toDomain() -> Episode {
        Episode(
            id: episodeID,
            showID: showID,
            seasonNumber: seasonNumber,
            episodeNumber: episodeNumber,
            title: title,
            overview: overview,
            stillImageURL: stillImageURL,
            airDate: airDate,
            hasPreciseTime: hasPreciseTime
        )
    }
}
