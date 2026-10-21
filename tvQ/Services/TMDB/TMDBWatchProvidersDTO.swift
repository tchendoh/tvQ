import Foundation

/// Reflète la réponse JSON de `GET /3/tv/{series_id}/watch/providers` (TMDB).
/// Données fournies par JustWatch (attribution obligatoire — voir AboutView) et
/// couvrant toutes les régions d'un coup : `watch_region` ne fait rien sur cet
/// endpoint précis (contrairement à d'autres), le filtrage par pays se fait
/// donc côté client, sur `results[countryCode]`.
struct TMDBWatchProvidersDTO: Codable {
    let results: [String: TMDBWatchProvidersRegionDTO]
}

struct TMDBWatchProvidersRegionDTO: Codable {
    /// Lien vers la page JustWatch/TMDB de la série pour cette région — pas un
    /// deep-link vers l'app d'un diffuseur en particulier (TMDB ne fournit pas ça).
    let link: String?
    /// Inclus dans un abonnement (Netflix, Crave, Disney+).
    let flatrate: [TMDBWatchProviderDTO]?
    let buy: [TMDBWatchProviderDTO]?
    let rent: [TMDBWatchProviderDTO]?
    /// Gratuit avec publicité (Tubi, Pluto TV, CBC Gem…). `var` avec valeur par
    /// défaut : clés absentes de la plupart des réponses, et facultatives à l'init.
    var ads: [TMDBWatchProviderDTO]? = nil
    /// Gratuit sans publicité (rare : diffuseurs publics, bibliothèques).
    var free: [TMDBWatchProviderDTO]? = nil

    /// Tous les diffuseurs, dans l'ordre d'affichage : abonnement, gratuit sans
    /// pub, gratuit avec pub, puis achat et location.
    var providersInDisplayOrder: [TMDBWatchProviderDTO] {
        [flatrate, free, ads, buy, rent].compactMap { $0 }.flatMap { $0 }
    }
}

struct TMDBWatchProviderDTO: Codable {
    let providerID: Int
    let providerName: String

    enum CodingKeys: String, CodingKey {
        case providerID = "provider_id"
        case providerName = "provider_name"
    }
}
