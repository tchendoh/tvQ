import Foundation

/// Extrait la région choisie par l'utilisateur (AppSettings.watchProviderRegion)
/// de la réponse TMDB (toutes régions confondues) et la ramène à un modèle
/// `WatchAvailability` simple, texte seulement, regroupé par façon de regarder.
enum WatchAvailabilityMapper {
    static func map(dto: TMDBWatchProvidersDTO, region: String) -> WatchAvailability {
        let regionDisplayName = AppSettings.regionDisplayName(region)
        let regionDTO = dto.results[region]

        // Abonnement d'abord (ce que la majorité cherche), puis le gratuit, puis
        // achat/location. Un service déjà vu dans un groupe précédent est omis.
        var seen = Set<String>()
        func names(_ lists: [TMDBWatchProviderDTO]?...) -> [String] {
            lists.compactMap { $0 }.flatMap { $0 }
                .map { normalizedProviderName($0.providerName) }
                .filter { seen.insert($0.lowercased()).inserted }  // sans casse : « netflix with ads » = « Netflix »
        }
        let included = names(regionDTO?.flatrate)
        let free = names(regionDTO?.free, regionDTO?.ads)
        let buyOrRent = names(regionDTO?.buy, regionDTO?.rent)

        // Lien retourné par TMDB pour cette région (pointe en fait vers
        // themoviedb.org/tv/.../watch, qui redirige lui-même vers JustWatch —
        // TMDB ne fournit pas de deep-link direct). Repli sur la page d'accueil
        // JustWatch si TMDB n'a aucune donnée pour ce pays.
        let url = regionDTO?.link.flatMap(URL.init(string:)) ?? URL(string: "https://www.justwatch.com")!

        let availableRegions = dto.results
            .filter { _, regionDTO in !regionDTO.providersInDisplayOrder.isEmpty }
            .map(\.key)

        return WatchAvailability(
            regionDisplayName: regionDisplayName,
            included: included,
            free: free,
            buyOrRent: buyOrRent,
            justWatchURL: url,
            availableRegions: availableRegions
        )
    }

    /// JustWatch/TMDB multiplient les variantes d'un même service : paliers
    /// (« Netflix Standard with Ads »), canaux revendus par une autre plateforme
    /// (« Paramount+ Amazon Channel », « Crave Apple TV Channel ») et orthographes
    /// (« Disney Plus »). Pour l'utilisateur, la question est « sur quel service ? » :
    /// tout est ramené au nom du service, puis dédupliqué.
    ///
    /// Restent séparés, volontairement : les marques partagées dont le catalogue
    /// diffère vraiment (Apple TV, magasin d'achat/location, vs Apple TV+,
    /// abonnement ; Amazon Video vs Amazon Prime Video). Aucune règle ci-dessous ne
    /// les touche.
    static func normalizedProviderName(_ name: String) -> String {
        var result = name.trimmingCharacters(in: .whitespaces)
        for (pattern, replacement) in normalizationRules {
            result = result.replacingOccurrences(
                of: pattern, with: replacement, options: [.regularExpression, .caseInsensitive]
            )
        }
        return providerNameAliases[result.lowercased()] ?? result
    }

    /// Appliquées dans l'ordre, sur la fin du nom seulement (`$`).
    private static let normalizationRules: [(pattern: String, replacement: String)] = [
        // Canal revendu : « Paramount+ Amazon Channel » → « Paramount+ ».
        // Exige un nom avant (« The Roku Channel », un vrai service, reste intact).
        (#"(?<=\S)\s+(?:Amazon|Apple TV|Prime Video|Roku Premium|YouTube TV)\s+Channel$"#, ""),
        // Palier avec pub : « Netflix Standard with Ads », « Max with Ads ».
        (#"\s+(?:(?:Standard|Basic|Premium|Essential)\s+)?with\s+Ads$"#, ""),
        // Palier nommé : « Paramount+ Essential », « Peacock Premium ».
        (#"(?<=\S)\s+(?:Standard|Basic|Premium|Essential)$"#, ""),
        // Orthographe, partout dans le nom : « Disney Plus » → « Disney+ »,
        // « Hulu Plus Live TV » → « Hulu+ Live TV ». Mot entier seulement, et
        // jamais en tête (un service qui s'appellerait « Plus » reste intact).
        (#"(?<=\S)\s+Plus\b"#, "+"),
    ]

    /// Renommages qu'aucune règle ne peut deviner (comparaison sans casse).
    private static let providerNameAliases: [String: String] = [
        // Rebranding 2023 du même service, pas un changement de catalogue.
        "hbo max": "Max",
        "netflix kids": "Netflix",
    ]
}
