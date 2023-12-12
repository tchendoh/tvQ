//
//  SearchTVResponse.swift
//  BingeQ
//
//  Created by Eric Chandonnet on 2023-12-03.
//

import Foundation

struct SearchTVResponse: Codable {
    var page: Int
    var results: [Result]
    var totalPages: Int
    var totalResults: Int
    
    private enum CodingKeys: String, CodingKey {
        case page
        case results
        case totalPages = "total_pages"
        case totalResults = "total_results"
    }
    
    init(page: Int, results: [Result], totalPages: Int, totalResults: Int) {
        self.page = page
        self.results = results
        self.totalPages = totalPages
        self.totalResults = totalResults
    }
}

extension SearchTVResponse {
    struct Result: Codable, Identifiable {
        var adult: Bool
        var backdropPath: String?
        var genreIds: [Int]
        var id: Int
        var originCountry: [String]
        var originalLanguage: String
        var originalName: String
        var overview: String
        var popularity: Double
        var posterPath: String?
        var firstAirDate: String
        var name: String
        var voteAverage: Double
        var voteCount: Int
        
        private enum CodingKeys: String, CodingKey {
            case adult
            case backdropPath = "backdrop_path"
            case genreIds = "genre_ids"
            case id
            case originCountry = "origin_country"
            case originalLanguage = "original_language"
            case originalName = "original_name"
            case overview
            case popularity
            case posterPath = "poster_path"
            case firstAirDate = "first_air_date"
            case name
            case voteAverage = "vote_average"
            case voteCount = "vote_count"
        }
        
        init(adult: Bool, backdropPath: String?, genreIds: [Int], id: Int, originCountry: [String], originalLanguage: String, originalName: String, overview: String, popularity: Double, posterPath: String, firstAirDate: String, name: String, voteAverage: Double, voteCount: Int) {
            self.adult = adult
            self.backdropPath = backdropPath
            self.genreIds = genreIds
            self.id = id
            self.originCountry = originCountry
            self.originalLanguage = originalLanguage
            self.originalName = originalName
            self.overview = overview
            self.popularity = popularity
            self.posterPath = posterPath
            self.firstAirDate = firstAirDate
            self.name = name
            self.voteAverage = voteAverage
            self.voteCount = voteCount
        }
    }
}

