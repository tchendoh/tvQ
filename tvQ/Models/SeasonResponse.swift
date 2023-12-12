//
//  SeasonResponse.swift
//  tvQ
//
//  Created by Eric Chandonnet on 2023-12-14.
//

import Foundation

struct SeasonResponse: Codable {
    let id_: String?
    let airDate: String?
    let episodes: [Episode]?
    let name: String?
    let overview: String?
    let id: Int?
    let posterPath: String?
    let seasonNumber: Int?
    
    private enum CodingKeys: String, CodingKey {
        case id_ = "_id"
        case airDate = "air_date"
        case episodes
        case name
        case overview
        case id
        case posterPath = "poster_path"
        case seasonNumber = "season_number"
    }
    
    init(id_: String?, airDate: String?, episodes: [Episode]?, name: String?, overview: String?, id: Int?, posterPath: String?, seasonNumber: Int?) {
        self.id_ = id_
        self.airDate = airDate
        self.episodes = episodes
        self.name = name
        self.overview = overview
        self.id = id
        self.posterPath = posterPath
        self.seasonNumber = seasonNumber
    }
}

extension SeasonResponse {
    struct Episode: Codable {
        let airDate: String?
        let episodeNumber: Int?
        let episodeType: String?
        let id: Int?
        let name: String?
        let overview: String?
        let productionCode: String?
        let runtime: Int?
        let seasonNumber: Int?
        let showID: Int?
        let stillPath: String?
        
        private enum CodingKeys: String, CodingKey {
            case airDate = "air_date"
            case episodeNumber = "episode_number"
            case episodeType = "episode_type"
            case id
            case name
            case overview
            case productionCode = "production_code"
            case runtime
            case seasonNumber = "season_number"
            case showID = "show_id"
            case stillPath = "still_path"
        }
        
        init(airDate: String?, episodeNumber: Int?, episodeType: String?, id: Int?, name: String?, overview: String?, productionCode: String?, runtime: Int?, seasonNumber: Int?, showID: Int?, stillPath: String?) {
            self.airDate = airDate
            self.episodeNumber = episodeNumber
            self.episodeType = episodeType
            self.id = id
            self.name = name
            self.overview = overview
            self.productionCode = productionCode
            self.runtime = runtime
            self.seasonNumber = seasonNumber
            self.showID = showID
            self.stillPath = stillPath
        }
    }
}
