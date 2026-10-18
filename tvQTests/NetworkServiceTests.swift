import Testing
import Foundation
@testable import tvQ

/// Intercepte les requêtes de URLSession.shared (que NetworkService utilise) pour
/// répondre sans réseau. Seuls les hôtes de test et TVmaze sont interceptés.
final class StubURLProtocol: URLProtocol, @unchecked Sendable {
    enum Reply {
        case response(status: Int, body: Data)
        case failure(URLError.Code)
    }

    nonisolated(unsafe) static var reply: Reply = .response(status: 200, body: Data())
    nonisolated(unsafe) static var lastRequest: URLRequest?
    static let interceptedHosts: Set<String> = ["stub.tvq.test", "api.tvmaze.com"]

    override class func canInit(with request: URLRequest) -> Bool {
        interceptedHosts.contains(request.url?.host ?? "")
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.lastRequest = request
        switch Self.reply {
        case .response(let status, let body):
            let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: body)
            client?.urlProtocolDidFinishLoading(self)
        case .failure(let code):
            client?.urlProtocol(self, didFailWithError: URLError(code))
        }
    }

    override func stopLoading() {}
}

private struct Payload: Decodable, Equatable {
    let value: Int
}

/// En série : la réponse factice est globale.
@MainActor
@Suite(.serialized)
struct NetworkServiceTests {
    private let request = URLRequest(url: URL(string: "https://stub.tvq.test/item")!)

    init() {
        URLProtocol.registerClass(StubURLProtocol.self)
    }

    private func fetch() async throws -> Payload {
        try await NetworkService().fetch(request, as: Payload.self)
    }

    @Test func decodesSuccessfulResponse() async throws {
        StubURLProtocol.reply = .response(status: 200, body: Data(#"{"value": 42}"#.utf8))
        #expect(try await fetch() == Payload(value: 42))
    }

    @Test func httpErrorKeepsItsStatusCode() async {
        StubURLProtocol.reply = .response(status: 401, body: Data())
        do {
            _ = try await fetch()
            Issue.record("Une erreur était attendue")
        } catch NetworkError.httpStatus(let code) {
            #expect(code == 401)
        } catch {
            Issue.record("Erreur inattendue : \(error)")
        }
    }

    @Test func invalidJSONIsADecodingFailure() async {
        StubURLProtocol.reply = .response(status: 200, body: Data(#"{"autre": 1}"#.utf8))
        do {
            _ = try await fetch()
            Issue.record("Une erreur était attendue")
        } catch NetworkError.decodingFailed {
            // attendu
        } catch {
            Issue.record("Erreur inattendue : \(error)")
        }
    }

    @Test func offlineIsNoConnection() async {
        StubURLProtocol.reply = .failure(.notConnectedToInternet)
        do {
            _ = try await fetch()
            Issue.record("Une erreur était attendue")
        } catch NetworkError.noConnection {
            // attendu
        } catch {
            Issue.record("Erreur inattendue : \(error)")
        }
    }

    /// Une annulation ne doit pas être affichée comme une panne réseau.
    @Test func cancellationIsNotDisguised() async {
        StubURLProtocol.reply = .failure(.cancelled)
        do {
            _ = try await fetch()
            Issue.record("Une erreur était attendue")
        } catch let error as URLError {
            #expect(error.code == .cancelled)
        } catch {
            Issue.record("Erreur inattendue : \(error)")
        }
    }

    @Test func otherFailuresAreUnknown() async {
        StubURLProtocol.reply = .failure(.timedOut)
        do {
            _ = try await fetch()
            Issue.record("Une erreur était attendue")
        } catch NetworkError.unknown {
            // attendu
        } catch {
            Issue.record("Erreur inattendue : \(error)")
        }
    }

    // MARK: - TVmazeService

    /// 404 = série inconnue de TVmaze : la fiche reste utilisable, sans heure précise.
    @Test func tvmazeLookup404IsNil() async throws {
        StubURLProtocol.reply = .response(status: 404, body: Data())
        let show = try await TVmazeService().lookupShow(imdbID: "tt0000000")
        #expect(show == nil)
        #expect(StubURLProtocol.lastRequest?.url?.query == "imdb=tt0000000")
    }

    @Test func tvmazeLookupOtherErrorsAreThrown() async {
        StubURLProtocol.reply = .response(status: 500, body: Data())
        await #expect(throws: NetworkError.self) {
            _ = try await TVmazeService().lookupShow(imdbID: "tt0944947")
        }
    }

    @Test func tvmazeLookupDecodesRealResponse() async throws {
        StubURLProtocol.reply = .response(status: 200, body: Data(Fixtures.tvmazeLookup.utf8))
        let show = try #require(try await TVmazeService().lookupShow(imdbID: "tt0944947"))
        #expect(show.id == 82)
        #expect(show.status == "Ended")
    }
}
