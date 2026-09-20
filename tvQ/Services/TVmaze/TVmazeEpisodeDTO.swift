import Foundation

/// Reflète exactement un élément de la réponse JSON de
/// `GET /shows/{id}/episodes` (TVmaze).
struct TVmazeEpisodeDTO: Codable {
    let id: Int
    let name: String
    let season: Int
    let number: Int?  // nullable côté TVmaze pour certains specials
    let airdate: String?  // "YYYY-MM-DD"
    let airtime: String?  // "HH:mm", heure locale au réseau de diffusion
    let airstamp: String? // ISO8601 complet avec timezone, ex: "2026-07-15T20:00:00-04:00"

    enum CodingKeys: String, CodingKey {
        case id, name, season, number, airdate, airtime, airstamp
    }
}
