//
//  APIService.swift
//  tvQ
//
//  Created by Eric Chandonnet on 2023-12-28.
//

import Foundation

protocol APIService {
    func fetchTVSearchResults(query: String, numberOfResults: Int) async throws -> [SearchTVResponse.Result]
    
    func fetchSingleTV(tvId: TVId) async throws -> SingleTVResponse
    
    func fetchFullSingleTV(tvId: TVId) async throws -> FullSingleTVResponse
    
    func fetchPerson(personId: Int) async throws -> Person
    
    func fetchTVSeason(tvId: TVId, seasonNumber: Int) async throws -> SeasonResponse
}
