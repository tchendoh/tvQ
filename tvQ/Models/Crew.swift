//
//  Crew.swift
//  tvQ
//
//  Created by Eric Chandonnet on 2024-01-08.
//

import Foundation

struct Crew: Codable, Identifiable {
    let adult: Bool?
    let gender: Int?
    let id: Int?
    let knownForDepartment: String?
    let name: String?
    let originalName: String?
    let popularity: Double?
    let profilePath: String?
    let jobs: [CrewJob]?
    let department: String?
    let totalEpisodeCount: Int?
    
    private enum CodingKeys: String, CodingKey {
        case adult
        case gender
        case id
        case knownForDepartment = "known_for_department"
        case name
        case originalName = "original_name"
        case popularity
        case profilePath = "profile_path"
        case jobs
        case department
        case totalEpisodeCount = "total_episode_count"
    }
    
    init(adult: Bool?, gender: Int?, id: Int?, knownForDepartment: String?, name: String?, originalName: String?, popularity: Double?, profilePath: String?, jobs: [CrewJob]?, department: String?, totalEpisodeCount: Int?) {
        self.adult = adult
        self.gender = gender
        self.id = id
        self.knownForDepartment = knownForDepartment
        self.name = name
        self.originalName = originalName
        self.popularity = popularity
        self.profilePath = profilePath
        self.jobs = jobs
        self.department = department
        self.totalEpisodeCount = totalEpisodeCount
    }
    
    struct CrewJob: Codable {
        let creditID: String?
        let job: String?
        let episodeCount: Int?
        
        private enum CodingKeys: String, CodingKey {
            case creditID = "credit_id"
            case job
            case episodeCount = "episode_count"
        }
        
        init(creditID: String?, job: String?, episodeCount: Int?) {
            self.creditID = creditID
            self.job = job
            self.episodeCount = episodeCount
        }
    }
}
