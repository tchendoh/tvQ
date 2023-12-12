//
//  Cast.swift
//  tvQ
//
//  Created by Eric Chandonnet on 2024-01-08.
//

import Foundation

struct Cast: Codable, Identifiable {
    let adult: Bool?
    let gender: Int?
    let id: Int?
    let knownForDepartment: String?
    let name: String?
    let originalName: String?
    let popularity: Double?
    let profilePath: String?
    let roles: [CastRole]?
    let totalEpisodeCount: Int?
    let order: Int?
    
    private enum CodingKeys: String, CodingKey {
        case adult
        case gender
        case id
        case knownForDepartment = "known_for_department"
        case name
        case originalName = "original_name"
        case popularity
        case profilePath = "profile_path"
        case roles
        case totalEpisodeCount = "total_episode_count"
        case order
    }
    
    init(adult: Bool?, gender: Int?, id: Int?, knownForDepartment: String?, name: String?, originalName: String?, popularity: Double?, profilePath: String?, roles: [CastRole]?, totalEpisodeCount: Int?, order: Int?) {
        self.adult = adult
        self.gender = gender
        self.id = id
        self.knownForDepartment = knownForDepartment
        self.name = name
        self.originalName = originalName
        self.popularity = popularity
        self.profilePath = profilePath
        self.roles = roles
        self.totalEpisodeCount = totalEpisodeCount
        self.order = order
    }
}
extension Cast {
    struct CastRole: Codable, Identifiable {
        let id = UUID()
        let creditID: String?
        let character: String?
        let episodeCount: Int?
        
        private enum CodingKeys: String, CodingKey {
            case creditID = "credit_id"
            case character
            case episodeCount = "episode_count"
        }
        
        init(creditID: String?, character: String?, episodeCount: Int?) {
            self.creditID = creditID
            self.character = character
            self.episodeCount = episodeCount
        }
    }
}
