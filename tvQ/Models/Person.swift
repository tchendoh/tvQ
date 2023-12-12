//
//  PersonResponse.swift
//  tvQ
//
//  Created by Eric Chandonnet on 2024-01-05.
//

import Foundation

struct Person: Codable {
    let adult: Bool?
    let alsoKnownAs: [String]?
    let biography: String?
    let birthday: String?
    let deathday: String?
    let gender: Int?
    let id: Int?
    let imdbID: String?
    let knownForDepartment: String?
    let name: String?
    let placeOfBirth: String?
    let popularity: Double?
    let profilePath: String?
    let combinedCredits: CombinedCredit?
    let images: PersonImage?
    
    private enum CodingKeys: String, CodingKey {
        case adult
        case alsoKnownAs = "also_known_as"
        case biography
        case birthday
        case deathday
        case gender
        case id
        case imdbID = "imdb_id"
        case knownForDepartment = "known_for_department"
        case name
        case placeOfBirth = "place_of_birth"
        case popularity
        case profilePath = "profile_path"
        case combinedCredits = "combined_credits"
        case images
    }
    
    init(adult: Bool?, alsoKnownAs: [String]?, biography: String?, birthday: String?, deathday: String?, gender: Int?, id: Int?, imdbID: String?, knownForDepartment: String?, name: String?, placeOfBirth: String?, popularity: Double?, profilePath: String?, combinedCredits: CombinedCredit?, images: PersonImage?) {
        self.adult = adult
        self.alsoKnownAs = alsoKnownAs
        self.biography = biography
        self.birthday = birthday
        self.deathday = deathday
        self.gender = gender
        self.id = id
        self.imdbID = imdbID
        self.knownForDepartment = knownForDepartment
        self.name = name
        self.placeOfBirth = placeOfBirth
        self.popularity = popularity
        self.profilePath = profilePath
        self.combinedCredits = combinedCredits
        self.images = images
    }
}

extension Person {
    struct CombinedCredit: Codable {
        let cast: [Cast]?
        let crew: [Crew]?
        
        init(cast: [Cast]?, crew: [Crew]?) {
            self.cast = cast
            self.crew = crew
        }
    }
}

extension Person.CombinedCredit {
    struct Cast: Codable {
        let adult: Bool?
        let backdropPath: String?
        let genreIds: [Int]?
        let id: Int?
        let originalLanguage: String?
        let originalTitle: String?
        let overview: String?
        let popularity: Double?
        let posterPath: String?
        let releaseDate: String?
        let title: String?
        let video: Bool?
        let voteAverage: Double?
        let voteCount: Int?
        let character: String?
        let creditID: String?
        let order: Int?
        let mediaType: String?
        let originCountry: [String]?
        let originalName: String?
        let firstAirDate: String?
        let name: String?
        let episodeCount: Int?
        
        private enum CodingKeys: String, CodingKey {
            case adult
            case backdropPath = "backdrop_path"
            case genreIds = "genre_ids"
            case id
            case originalLanguage = "original_language"
            case originalTitle = "original_title"
            case overview
            case popularity
            case posterPath = "poster_path"
            case releaseDate = "release_date"
            case title
            case video
            case voteAverage = "vote_average"
            case voteCount = "vote_count"
            case character
            case creditID = "credit_id"
            case order
            case mediaType = "media_type"
            case originCountry = "origin_country"
            case originalName = "original_name"
            case firstAirDate = "first_air_date"
            case name
            case episodeCount = "episode_count"
        }
        
        init(adult: Bool?, backdropPath: String?, genreIds: [Int]?, id: Int?, originalLanguage: String?, originalTitle: String?, overview: String?, popularity: Double?, posterPath: String?, releaseDate: String?, title: String?, video: Bool?, voteAverage: Double?, voteCount: Int?, character: String?, creditID: String?, order: Int?, mediaType: String?, originCountry: [String]?, originalName: String?, firstAirDate: String?, name: String?, episodeCount: Int?) {
            self.adult = adult
            self.backdropPath = backdropPath
            self.genreIds = genreIds
            self.id = id
            self.originalLanguage = originalLanguage
            self.originalTitle = originalTitle
            self.overview = overview
            self.popularity = popularity
            self.posterPath = posterPath
            self.releaseDate = releaseDate
            self.title = title
            self.video = video
            self.voteAverage = voteAverage
            self.voteCount = voteCount
            self.character = character
            self.creditID = creditID
            self.order = order
            self.mediaType = mediaType
            self.originCountry = originCountry
            self.originalName = originalName
            self.firstAirDate = firstAirDate
            self.name = name
            self.episodeCount = episodeCount
        }
    }
}

extension Person {
    struct PersonImage: Codable {
        let profiles: [Profile]?
        
        init(profiles: [Profile]?) {
            self.profiles = profiles
        }
    }
}

extension Person.PersonImage {
    struct Profile: Codable {
        let aspectRatio: Double?
        let height: Int?
        let iso6391: String?
        let filePath: String?
        let voteAverage: Double?
        let voteCount: Int?
        let width: Int?
        
        private enum CodingKeys: String, CodingKey {
            case aspectRatio = "aspect_ratio"
            case height
            case iso6391 = "iso_639_1"
            case filePath = "file_path"
            case voteAverage = "vote_average"
            case voteCount = "vote_count"
            case width
        }
        
        init(aspectRatio: Double?, height: Int?, iso6391: String?, filePath: String?, voteAverage: Double?, voteCount: Int?, width: Int?) {
            self.aspectRatio = aspectRatio
            self.height = height
            self.iso6391 = iso6391
            self.filePath = filePath
            self.voteAverage = voteAverage
            self.voteCount = voteCount
            self.width = width
        }
    }
}
