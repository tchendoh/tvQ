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
    let flatrate: [TMDBWatchProviderDTO]?
    let buy: [TMDBWatchProviderDTO]?
    let rent: [TMDBWatchProviderDTO]?
}

struct TMDBWatchProviderDTO: Codable {
    let providerID: Int
    let providerName: String

    enum CodingKeys: String, CodingKey {
        case providerID = "provider_id"
        case providerName = "provider_name"
    }
}
