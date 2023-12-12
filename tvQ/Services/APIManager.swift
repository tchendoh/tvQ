//
//  APIManager.swift
//  BingeQ
//
//  Created by Eric Chandonnet on 2023-12-04.
//

import Foundation

enum ApiManagerError: Error {
    case urlError
    case requestError
    case jsonDecodingError
    case fetchingDataError
    case invalidStatusCode
    case tooManyRequests429
}

actor APIManager: APIService {
    
    
    var apiAccessToken: String {
        ProcessInfo.processInfo.environment["TMDB_API_READ_ACCESS_TOKEN"]!
    }
    
    init() {
        
    }
    
    func fetchTVSearchResults(query: String, numberOfResults: Int) async throws -> [SearchTVResponse.Result] {
        
        var urlComponents = URLComponents()
        urlComponents.scheme = Constants.Tmdb.URL.scheme
        urlComponents.host = Constants.Tmdb.URL.base
        urlComponents.path = Constants.Tmdb.URL.searchTV
        urlComponents.queryItems = [URLQueryItem(name: "query", value: query),
                                    URLQueryItem(name: "language", value: Constants.Setup.language),
                                    URLQueryItem(name: "api_key", value: ProcessInfo.processInfo.environment["TMDB_API_KEY"]!)]
        
        guard let url = urlComponents.url else { throw ApiManagerError.urlError }
        
        /// Refactor : besoin du type de retour
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.allHTTPHeaderFields = [
            "accept": "application/json",
            "Authorization": "Bearer \(apiAccessToken)"
        ]
        
        do {
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard (response as? HTTPURLResponse)?.statusCode == 200 else {
                throw ApiManagerError.invalidStatusCode
            }
            
            guard let decodedSearchResponse = try? JSONDecoder().decode(SearchTVResponse.self, from: data) else {
                throw ApiManagerError.jsonDecodingError
            }
            
            let firstResults = Array(decodedSearchResponse.results.prefix(numberOfResults))

            return firstResults
        }
        catch {
            print(error)
            print("url \(url) ")
            throw(error)
        }
    }
    
    func fetchSingleTV(tvId: TVId) async throws -> SingleTVResponse {
        /// Refactor : toujours besoin de path, dans le cas d'une recherche, on a besoin de query
        var urlComponents = URLComponents()
        urlComponents.scheme = Constants.Tmdb.URL.scheme
        urlComponents.host = Constants.Tmdb.URL.base
        urlComponents.path = "\(Constants.Tmdb.URL.singleTV)/\(tvId)"
        urlComponents.queryItems = [URLQueryItem(name: "language", value: Constants.Setup.language),
                                    URLQueryItem(name: "api_key", value: ProcessInfo.processInfo.environment["TMDB_API_KEY"]!)]
        
        guard let url = urlComponents.url else { throw ApiManagerError.urlError }
        
        /// Refactor : besoin du type de retour
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.allHTTPHeaderFields = [
            "accept": "application/json",
            "Authorization": "Bearer \(apiAccessToken)"
        ]
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard (response as? HTTPURLResponse)?.statusCode == 200 else {
                throw ApiManagerError.invalidStatusCode
            }
            
            guard let decodedResponse = try? JSONDecoder().decode(SingleTVResponse.self, from: data) else {
                throw ApiManagerError.jsonDecodingError
            }

//            guard let decodedResponse = try? parseResponseDebug(from: data) else {
//                throw ApiManagerError.jsonDecodingError
//            }
            
            return decodedResponse
        } catch  {
            print(error)
            print(error.localizedDescription)
            print("url \(url) ")
            throw(error)
        }
        
        
    }

    func fetchFullSingleTV(tvId: TVId) async throws -> FullSingleTVResponse {
        /// Refactor : toujours besoin de path, dans le cas d'une recherche, on a besoin de query
        var urlComponents = URLComponents()
        urlComponents.scheme = Constants.Tmdb.URL.scheme
        urlComponents.host = Constants.Tmdb.URL.base
        urlComponents.path = "\(Constants.Tmdb.URL.singleTV)/\(tvId)"
        urlComponents.queryItems = [URLQueryItem(name: "language", value: Constants.Setup.language),
                                    URLQueryItem(name: "append_to_response", value: "watch/providers,aggregate_credits,external_ids,images"),
                                    URLQueryItem(name: "include_image_language", value: "en,null"),
                                    URLQueryItem(name: "api_key", value: ProcessInfo.processInfo.environment["TMDB_API_KEY"]!)]
        
        guard let url = urlComponents.url else { throw ApiManagerError.urlError }
        
        /// Refactor : besoin du type de retour
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.allHTTPHeaderFields = [
            "accept": "application/json",
            "Authorization": "Bearer \(apiAccessToken)"
        ]
        //print("url \(url) ")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard (response as? HTTPURLResponse)?.statusCode != 429 else {
                throw ApiManagerError.tooManyRequests429
            }

            guard (response as? HTTPURLResponse)?.statusCode == 200 else {
                throw ApiManagerError.invalidStatusCode
            }
            
//            guard let decodedResponse = try? parseResponseDebug(from: data) else {
//                throw ApiManagerError.jsonDecodingError
//            }
            let decodedResponse = try JSONDecoder().decode(FullSingleTVResponse.self, from: data)
            
            return decodedResponse
        } catch let DecodingError.keyNotFound(key, context) {
            print("Decoding error (keyNotFound): \(key) not found in \(context.debugDescription)")
            print("Coding path: \(context.codingPath)")
            throw ApiManagerError.jsonDecodingError
        } catch let DecodingError.dataCorrupted(context) {
            print("Decoding error (dataCorrupted): data corrupted in \(context.debugDescription)")
            print("Coding path: \(context.codingPath)")
            print("UnderlyingError: \(context.underlyingError!)")
            throw ApiManagerError.jsonDecodingError
        } catch let DecodingError.typeMismatch(type, context) {
            print("Decoding error (typeMismatch): type mismatch of \(type) in \(context.debugDescription)")
            print("Coding path: \(context.codingPath)")
            throw ApiManagerError.jsonDecodingError
        } catch let DecodingError.valueNotFound(type, context) {
            print("Decoding error (valueNotFound): value not found for \(type) in \(context.debugDescription)")
            print("Coding path: \(context.codingPath)")
            throw ApiManagerError.jsonDecodingError
        } catch  {
            print("fetchFullSingleTV")
            print(error)
            print(error.localizedDescription)
            print("url \(url) ")
            throw(error)
        }
        
    }

    private func parseResponseDebug(from data: Data) throws -> FullSingleTVResponse? {
        let decoder = JSONDecoder()
        
        do {
            return try decoder.decode(FullSingleTVResponse.self, from: data)
        } catch let DecodingError.keyNotFound(key, context) {
            print("Decoding error (keyNotFound): \(key) not found in \(context.debugDescription)")
            print("Coding path: \(context.codingPath)")
        } catch let DecodingError.dataCorrupted(context) {
            print("Decoding error (dataCorrupted): data corrupted in \(context.debugDescription)")
            print("Coding path: \(context.codingPath)")
        } catch let DecodingError.typeMismatch(type, context) {
            print("Decoding error (typeMismatch): type mismatch of \(type) in \(context.debugDescription)")
            print("Coding path: \(context.codingPath)")
        } catch let DecodingError.valueNotFound(type, context) {
            print("Decoding error (valueNotFound): value not found for \(type) in \(context.debugDescription)")
            print("Coding path: \(context.codingPath)")
        }
        return nil
    }

    func fetchTVSeason(tvId: TVId, seasonNumber: Int) async throws -> SeasonResponse {
        /// https://api.themoviedb.org/3/tv/{series_id}/season/{season_number}
        var urlComponents = URLComponents()
        urlComponents.scheme = Constants.Tmdb.URL.scheme
        urlComponents.host = Constants.Tmdb.URL.base
        urlComponents.path = "\(Constants.Tmdb.URL.seasonTV)/\(tvId)/season/\(seasonNumber)"
        urlComponents.queryItems = [URLQueryItem(name: "language", value: Constants.Setup.language),
                                    URLQueryItem(name: "api_key", value: ProcessInfo.processInfo.environment["TMDB_API_KEY"]!)]
        
        guard let url = urlComponents.url else { throw ApiManagerError.urlError }
        
        /// Refactor : besoin du type de retour
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.allHTTPHeaderFields = [
            "accept": "application/json",
            "Authorization": "Bearer \(apiAccessToken)"
        ]
        
        do {
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard (response as? HTTPURLResponse)?.statusCode == 200 else {
                throw ApiManagerError.invalidStatusCode
            }
            
            guard let decodedSeasonResponse = try? JSONDecoder().decode(SeasonResponse.self, from: data) else {
                throw ApiManagerError.jsonDecodingError
            }
            
            return decodedSeasonResponse
        }
        catch {
            print(error)
            print("url \(url) ")
            throw(error)
        }
    }
    
    func fetchPerson(personId: Int) async throws -> Person {
        /// Refactor : toujours besoin de path, dans le cas d'une recherche, on a besoin de query
        var urlComponents = URLComponents()
        urlComponents.scheme = Constants.Tmdb.URL.scheme
        urlComponents.host = Constants.Tmdb.URL.base
        urlComponents.path = "\(Constants.Tmdb.URL.personTV)/\(personId)"
        urlComponents.queryItems = [URLQueryItem(name: "api_key", value: ProcessInfo.processInfo.environment["TMDB_API_KEY"]!),
                                    URLQueryItem(name: "append_to_response", value: "combined_credits,images")]
        
        guard let url = urlComponents.url else { throw ApiManagerError.urlError }
        
        /// Refactor : besoin du type de retour
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.allHTTPHeaderFields = [
            "accept": "application/json",
            "Authorization": "Bearer \(apiAccessToken)"
        ]
        // print("url: \(url)")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard (response as? HTTPURLResponse)?.statusCode == 200 else {
                throw ApiManagerError.invalidStatusCode
            }
            
            guard let decodedResponse = try? JSONDecoder().decode(Person.self, from: data) else {
                throw ApiManagerError.jsonDecodingError
            }
            
            return decodedResponse
        } catch  {
            print(error)
            print(error.localizedDescription)
            print("url \(url) ")
            throw(error)
        }
        
        
    }
}
