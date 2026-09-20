import Foundation

/// Ce qui peut échouer lors d'un appel réseau. NetworkService ne construit jamais
/// de texte destiné à l'utilisateur : il classe seulement l'échec, et c'est chaque
/// ViewModel qui choisit le message à afficher selon le contexte.
enum NetworkError: Error {
    case noConnection
    /// Code HTTP hors de 200...299 (ex. 404, utilisé par TVmazeService pour
    /// distinguer "série inconnue de TVmaze" d'une vraie panne).
    case httpStatus(Int)
    case invalidResponse
    /// Conserve l'erreur de décodage d'origine (champ manquant, type inattendu...)
    /// pour faciliter le débogage avec des APIs tierces.
    case decodingFailed(Error)
    case unknown(Error)
}

/// Couche réseau générique : toute la mécanique commune (URLSession, code de statut,
/// décodage JSON) vit ici. Les services (TMDBService, TVmazeService) ne connaissent
/// que les URLs et les en-têtes propres à leur API.
struct NetworkService {
    func fetch<T: Decodable>(_ request: URLRequest, as type: T.Type) async throws -> T {
        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw NetworkError.invalidResponse
            }
            guard (200...299).contains(httpResponse.statusCode) else {
                throw NetworkError.httpStatus(httpResponse.statusCode)
            }

            return try JSONDecoder().decode(T.self, from: data)
        } catch let error as NetworkError {
            throw error
        } catch let error as DecodingError {
            throw NetworkError.decodingFailed(error)
        } catch let error as URLError where error.code == .cancelled {
            // Annulation (ex. un ViewModel relance son chargement) : on la laisse
            // passer telle quelle plutôt que de la déguiser en échec réseau.
            throw error
        } catch let error as URLError where error.code == .notConnectedToInternet {
            throw NetworkError.noConnection
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw NetworkError.unknown(error)
        }
    }
}
