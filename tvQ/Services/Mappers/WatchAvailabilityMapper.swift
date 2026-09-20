import Foundation

/// Extrait la région choisie par l'utilisateur (AppSettings.watchProviderRegion)
/// de la réponse TMDB (toutes régions confondues) et l'aplatit en un modèle
/// `WatchAvailability` simple, texte seulement.
enum WatchAvailabilityMapper {
    static func map(dto: TMDBWatchProvidersDTO, region: String) -> WatchAvailability {
        let regionDisplayName = WatchProviderRegion(rawValue: region)?.displayNameString ?? region
        let regionDTO = dto.results[region]

        // flatrate (abonnement) affiché en premier : c'est ce que la majorité
        // des utilisateurs cherchent en priorité, avant achat/location.
        let names = [regionDTO?.flatrate, regionDTO?.buy, regionDTO?.rent]
            .compactMap { $0 }
            .flatMap { $0 }
            .map { normalizedProviderName($0.providerName) }

        var seen = Set<String>()
        let dedupedNames = names.filter { seen.insert($0).inserted }

        // Lien retourné par TMDB pour cette région (pointe en fait vers
        // themoviedb.org/tv/.../watch, qui redirige lui-même vers JustWatch —
        // TMDB ne fournit pas de deep-link direct). Repli sur la page d'accueil
        // JustWatch si TMDB n'a aucune donnée pour ce pays.
        let url = regionDTO?.link.flatMap(URL.init(string:)) ?? URL(string: "https://www.justwatch.com")!

        return WatchAvailability(
            regionDisplayName: regionDisplayName,
            providerNames: dedupedNames,
            justWatchURL: url
        )
    }

    /// JustWatch/TMDB renvoient parfois plusieurs noms pour un même service
    /// (renommage historique, orthographe), qu'on fusionne ici sous un seul nom
    /// affiché. Volontairement limité aux cas où le catalogue est identique —
    /// PAS aux cas où la marque est partagée mais le catalogue diffère (ex.
    /// Apple TV magasin achat/location vs Apple TV+ abonnement ; Amazon Video
    /// achat/location vs Amazon Prime Video abonnement ; Paramount+ Amazon
    /// Channel qui est un canal d'accès distinct) — ces cas restent séparés
    /// intentionnellement, une série peut être disponible sur l'un sans l'autre.
    /// Comparaison insensible à la casse : JustWatch n'est pas toujours cohérent
    /// sur la capitalisation d'une entrée à l'autre.
    private static let providerNameAliases: [String: String] = [
        // Paliers avec pub Netflix — même catalogue que Netflix standard,
        // aucune série n'est exclusive au palier avec publicité.
        "netflix with ads": "Netflix",
        "netflix standard with ads": "Netflix",
        "netflix basic with ads": "Netflix",
        // Orthographe ("Disney Plus" vs "Disney+"), même service.
        "disney plus": "Disney+",
        // Rebranding 2023 du même service, pas un changement de catalogue.
        "hbo max": "Max",
    ]

    private static func normalizedProviderName(_ name: String) -> String {
        providerNameAliases[name.lowercased()] ?? name
    }
}
