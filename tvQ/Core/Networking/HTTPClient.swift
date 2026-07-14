import Foundation

/// Abstraction au-dessus de URLSession, pour pouvoir injecter un mock dans les tests
/// des clients TMDB/TVmaze sans faire de vrais appels réseau.
protocol HTTPClient {
    func get<T: Decodable>(url: URL, headers: [String: String]) async throws -> T
}

enum HTTPClientError: Error, Equatable {
    case invalidResponse
    case httpError(statusCode: Int)
    case decodingFailed
}

struct URLSessionHTTPClient: HTTPClient {
    private let session: URLSession
    private let decoder: JSONDecoder

    init(session: URLSession = .shared, decoder: JSONDecoder = .init()) {
        self.session = session
        self.decoder = decoder
    }

    func get<T: Decodable>(url: URL, headers: [String: String] = [:]) async throws -> T {
        var request = URLRequest(url: url)
        headers.forEach { request.setValue($1, forHTTPHeaderField: $0) }

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw HTTPClientError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            throw HTTPClientError.httpError(statusCode: httpResponse.statusCode)
        }

        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw HTTPClientError.decodingFailed
        }
    }
}
