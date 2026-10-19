import ActivityKit
import Foundation

/// Live Activity d'un épisode diffusé à heure fixe, les soirs de diffusion.
/// Partagé entre l'app (qui la programme, voir LiveActivityScheduler) et
/// l'extension tvQActivity (qui l'affiche).
///
/// ActivityKit limite la taille des attributs à quelques Ko : l'image ne passe
/// pas ici, seulement le nom de son fichier dans l'App Group.
nonisolated struct EpisodeActivityAttributes: ActivityAttributes {
    /// Rien ne change en cours de route : l'affichage avance avec les dates
    /// (compte à rebours, barre de progression) et passe à « Terminé » quand
    /// le contenu devient périmé (staleDate = fin de l'épisode).
    struct ContentState: Codable, Hashable {}

    let episodeID: String
    let tmdbID: Int
    let showTitle: String
    let network: String?
    /// « S02E04 ».
    let episodeCode: String
    let episodeTitle: String
    let airDate: Date
    let endDate: Date
    /// Fichier de l'image de fond dans AppGroup.activityImagesURL ; nil sans image.
    let imageFileName: String?
    /// Couleur de la série (Show.dominantColor), déjà assombrie pour du texte blanc.
    let tint: ShowColor?
    /// Deuxième couleur de la série (Show.accentColor), lisible sur fond sombre ;
    /// nil si l'image n'en a qu'une (l'extension la dérive alors de `tint`).
    var accentTint: ShowColor? = nil
}

/// Lien ouvert en touchant l'activité : la fiche de la série (voir MainTabView).
nonisolated enum TvQLink {
    static let scheme = "tvq"

    static func show(tmdbID: Int) -> URL {
        URL(string: "\(scheme)://show/\(tmdbID)")!
    }

    static func tmdbID(from url: URL) -> Int? {
        guard url.scheme == scheme, url.host() == "show" else { return nil }
        return Int(url.lastPathComponent)
    }
}

extension EpisodeActivityAttributes {
    /// Sigle de la série pour la Dynamic Island réduite, comme les équipes sportives
    /// (MTL, TOR) : « Moon Knight » → MK, « Star Wars: Maul » → SW (le sous-titre est
    /// ignoré), « The Last of Us » → LOU (articles écartés, sauf s'il ne reste rien),
    /// « Severance » → SEV (un seul mot : ses trois premières lettres).
    var showInitials: String {
        Self.initials(of: showTitle)
    }

    static func initials(of title: String) -> String {
        // Titre principal seulement : avant « : », « – » ou « - » (sous-titre).
        var main = title
        for separator in [":", " – ", " — ", " - "] {
            main = main.components(separatedBy: separator).first ?? main
        }
        // Mots, sans les élisions (« L'Échappée » → « Échappée »).
        let words: [String] = main
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber && $0 != "'" && $0 != "’" })
            .map { word in
                let parts = word.split(whereSeparator: { $0 == "'" || $0 == "’" })
                return String(parts.last ?? word)
            }
            .filter { !$0.isEmpty }
        let articles: Set<String> = ["the", "a", "an", "le", "la", "les", "l", "un", "une"]
        let significant = words.filter { !articles.contains($0.lowercased()) }
        let kept = significant.isEmpty ? words : significant

        guard let first = kept.first else { return "" }
        if kept.count == 1 {
            return String(first.prefix(3)).uppercased()
        }
        return String(kept.prefix(3).compactMap(\.first)).uppercased()
    }
}
