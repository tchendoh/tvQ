import Foundation

/// Reflète exactement la réponse JSON de `GET /shows/{id}` ou
/// `GET /lookup/shows?imdb=:id` (TVmaze). Sert uniquement à résoudre
/// l'identifiant TVmaze et le statut de diffusion — les métadonnées
/// riches (images, synopsis) restent la responsabilité de TMDB.
struct TVmazeShowDTO: Codable {
    let id: Int
    let name: String
    let status: String // "Running", "Ended", "To Be Determined", etc.

    enum CodingKeys: String, CodingKey {
        case id, name, status
    }
}
