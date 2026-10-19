import Foundation

/// Entité métier représentant un épisode.
/// `airDate` est la meilleure date de diffusion connue, choisie une fois pour
/// toutes par EpisodeMapper : le timestamp précis de TVmaze (date + heure,
/// timezone incluse) quand il existe, sinon la date seule de TMDB.
/// `hasPreciseTime` indique lequel des deux a été retenu.
nonisolated struct Episode: Identifiable, Equatable, Hashable, Codable {
    let id: String
    let showID: String
    let seasonNumber: Int
    let episodeNumber: Int
    let title: String
    let overview: String
    let stillImageURL: URL?

    /// nil si l'épisode n'est pas encore daté.
    let airDate: Date?

    /// true si `airDate` porte une heure fiable (source TVmaze), false si c'est
    /// une date seule (TMDB) dont l'heure n'a aucune signification.
    let hasPreciseTime: Bool

    /// Durée en minutes (TVmaze, sinon TMDB). nil si inconnue, ou dans une copie
    /// en cache antérieure à l'ajout de ce champ : sert à notifier après la fin.
    let runtimeMinutes: Int?

    init(
        id: String,
        showID: String,
        seasonNumber: Int,
        episodeNumber: Int,
        title: String,
        overview: String,
        stillImageURL: URL?,
        airDate: Date?,
        hasPreciseTime: Bool,
        runtimeMinutes: Int? = nil
    ) {
        self.id = id
        self.showID = showID
        self.seasonNumber = seasonNumber
        self.episodeNumber = episodeNumber
        self.title = title
        self.overview = overview
        self.stillImageURL = stillImageURL
        self.airDate = airDate
        self.hasPreciseTime = hasPreciseTime
        self.runtimeMinutes = runtimeMinutes
    }
}

// nonisolated : sans lui, l'extension hérite de l'isolation MainActor par défaut du
// projet, et les planificateurs (nonisolated) ne pourraient pas lire `code`.
nonisolated extension Episode {
    /// « S02E04 » : le seul endroit où ce format est défini (Schedule, notifications,
    /// Live Activity).
    var code: String {
        Self.code(season: seasonNumber, episode: episodeNumber)
    }

    static func code(season: Int, episode: Int) -> String {
        String(format: "S%02dE%02d", season, episode)
    }
}
