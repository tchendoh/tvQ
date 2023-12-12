//
//  FullSingleTVResponse.swift
//  tvQ
//
//  Created by Eric Chandonnet on 2023-12-30.
//

import Foundation

struct FullSingleTVResponse: Codable {
    let adult: Bool?
    let backdropPath: String?
    let createdBy: [CreatedBy]?
    let episodeRunTime: [Int]?
    let firstAirDate: String?
    let genres: [Genre]?
    let homepage: String?
    let id: Int?
    let inProduction: Bool?
    let languages: [String]?
    let lastAirDate: String?
    let lastEpisodeToAir: LastEpisodeToAir?
    let name: String?
    let nextEpisodeToAir: NextEpisodeToAir?
    let networks: [Network]?
    let numberOfEpisodes: Int?
    let numberOfSeasons: Int?
    let originCountry: [String]?
    let originalLanguage: String?
    let originalName: String?
    let overview: String?
    let popularity: Double?
    let posterPath: String?
    let productionCompanies: [ProductionCompany]?
    let productionCountries: [ProductionCountry]?
    let seasons: [Season]?
    let spokenLanguages: [SpokenLanguage]?
    let status: String?
    let tagline: String?
    let type: String?
    let watchProviders: WatchProvider?
    let aggregateCredits: AggregateCredit?
    let externalIds: ExternalID?
    let images: TVImage?
    
    private enum CodingKeys: String, CodingKey {
        case adult
        case backdropPath = "backdrop_path"
        case createdBy = "created_by"
        case episodeRunTime = "episode_run_time"
        case firstAirDate = "first_air_date"
        case genres
        case homepage
        case id
        case inProduction = "in_production"
        case languages
        case lastAirDate = "last_air_date"
        case lastEpisodeToAir = "last_episode_to_air"
        case name
        case nextEpisodeToAir = "next_episode_to_air"
        case networks
        case numberOfEpisodes = "number_of_episodes"
        case numberOfSeasons = "number_of_seasons"
        case originCountry = "origin_country"
        case originalLanguage = "original_language"
        case originalName = "original_name"
        case overview
        case popularity
        case posterPath = "poster_path"
        case productionCompanies = "production_companies"
        case productionCountries = "production_countries"
        case seasons
        case spokenLanguages = "spoken_languages"
        case status
        case tagline
        case type
        case watchProviders = "watch/providers"
        case aggregateCredits = "aggregate_credits"
        case externalIds = "external_ids"
        case images
    }
    
    init(adult: Bool?, backdropPath: String?, createdBy: [CreatedBy]?, episodeRunTime: [Int]?, firstAirDate: String?, genres: [Genre]?, homepage: String?, id: Int?, inProduction: Bool?, languages: [String]?, lastAirDate: String?, lastEpisodeToAir: LastEpisodeToAir?, name: String?, nextEpisodeToAir: NextEpisodeToAir?, networks: [Network]?, numberOfEpisodes: Int?, numberOfSeasons: Int?, originCountry: [String]?, originalLanguage: String?, originalName: String?, overview: String?, popularity: Double?, posterPath: String?, productionCompanies: [ProductionCompany]?, productionCountries: [ProductionCountry]?, seasons: [Season]?, spokenLanguages: [SpokenLanguage]?, status: String?, tagline: String?, type: String?, watchProviders: WatchProvider?, aggregateCredits: AggregateCredit?, externalIds: ExternalID?, images: TVImage?) {
        self.adult = adult
        self.backdropPath = backdropPath
        self.createdBy = createdBy
        self.episodeRunTime = episodeRunTime
        self.firstAirDate = firstAirDate
        self.genres = genres
        self.homepage = homepage
        self.id = id
        self.inProduction = inProduction
        self.languages = languages
        self.lastAirDate = lastAirDate
        self.lastEpisodeToAir = lastEpisodeToAir
        self.name = name
        self.nextEpisodeToAir = nextEpisodeToAir
        self.networks = networks
        self.numberOfEpisodes = numberOfEpisodes
        self.numberOfSeasons = numberOfSeasons
        self.originCountry = originCountry
        self.originalLanguage = originalLanguage
        self.originalName = originalName
        self.overview = overview
        self.popularity = popularity
        self.posterPath = posterPath
        self.productionCompanies = productionCompanies
        self.productionCountries = productionCountries
        self.seasons = seasons
        self.spokenLanguages = spokenLanguages
        self.status = status
        self.tagline = tagline
        self.type = type
        self.watchProviders = watchProviders
        self.aggregateCredits = aggregateCredits
        self.externalIds = externalIds
        self.images = images
    }
}

extension FullSingleTVResponse {
    struct CreatedBy: Codable {
        let id: Int?
        let creditID: String?
        let name: String?
        let gender: Int?
        let profilePath: String?
        
        private enum CodingKeys: String, CodingKey {
            case id
            case creditID = "credit_id"
            case name
            case gender
            case profilePath = "profile_path"
        }
        
        init(id: Int?, creditID: String?, name: String?, gender: Int?, profilePath: String?) {
            self.id = id
            self.creditID = creditID
            self.name = name
            self.gender = gender
            self.profilePath = profilePath
        }
    }
}

extension FullSingleTVResponse {
    struct Genre: Codable, Identifiable {
        let id: Int?
        let name: String?
        
        init(id: Int?, name: String?) {
            self.id = id
            self.name = name
        }
    }
}

extension FullSingleTVResponse {
    struct LastEpisodeToAir: Codable {
        let id: Int?
        let name: String?
        let overview: String?
        let airDate: String?
        let episodeNumber: Int?
        let episodeType: String?
        let productionCode: String?
        let runtime: Int?
        let seasonNumber: Int?
        let showID: Int?
        let stillPath: String?
        
        private enum CodingKeys: String, CodingKey {
            case id
            case name
            case overview
            case airDate = "air_date"
            case episodeNumber = "episode_number"
            case episodeType = "episode_type"
            case productionCode = "production_code"
            case runtime
            case seasonNumber = "season_number"
            case showID = "show_id"
            case stillPath = "still_path"
        }
        
        init(id: Int?, name: String?, overview: String?, airDate: String?, episodeNumber: Int?, episodeType: String?, productionCode: String?, runtime: Int?, seasonNumber: Int?, showID: Int?, stillPath: String?) {
            self.id = id
            self.name = name
            self.overview = overview
            self.airDate = airDate
            self.episodeNumber = episodeNumber
            self.episodeType = episodeType
            self.productionCode = productionCode
            self.runtime = runtime
            self.seasonNumber = seasonNumber
            self.showID = showID
            self.stillPath = stillPath
        }
    }
}

extension FullSingleTVResponse {
    struct NextEpisodeToAir: Codable {
        let id: Int?
        let name: String?
        let overview: String?
        let airDate: String?
        let episodeNumber: Int?
        let episodeType: String?
        let productionCode: String?
        let runtime: Int?
        let seasonNumber: Int?
        let showID: Int?
        let stillPath: String?
        
        private enum CodingKeys: String, CodingKey {
            case id
            case name
            case overview
            case airDate = "air_date"
            case episodeNumber = "episode_number"
            case episodeType = "episode_type"
            case productionCode = "production_code"
            case runtime
            case seasonNumber = "season_number"
            case showID = "show_id"
            case stillPath = "still_path"
        }
        
        init(id: Int?, name: String?, overview: String?, airDate: String?, episodeNumber: Int?, episodeType: String?, productionCode: String?, runtime: Int?, seasonNumber: Int?, showID: Int?, stillPath: String?) {
            self.id = id
            self.name = name
            self.overview = overview
            self.airDate = airDate
            self.episodeNumber = episodeNumber
            self.episodeType = episodeType
            self.productionCode = productionCode
            self.runtime = runtime
            self.seasonNumber = seasonNumber
            self.showID = showID
            self.stillPath = stillPath
        }
    }
}

extension FullSingleTVResponse {
    struct Network: Codable {
        let id: Int?
        let logoPath: String?
        let name: String?
        let originCountry: String?
        
        private enum CodingKeys: String, CodingKey {
            case id
            case logoPath = "logo_path"
            case name
            case originCountry = "origin_country"
        }
        
        init(id: Int?, logoPath: String?, name: String?, originCountry: String?) {
            self.id = id
            self.logoPath = logoPath
            self.name = name
            self.originCountry = originCountry
        }
    }
}

extension FullSingleTVResponse {
    struct ProductionCompany: Codable {
        let id: Int?
        let logoPath: String?
        let name: String?
        let originCountry: String?
        
        private enum CodingKeys: String, CodingKey {
            case id
            case logoPath = "logo_path"
            case name
            case originCountry = "origin_country"
        }
        
        init(id: Int?, logoPath: String?, name: String?, originCountry: String?) {
            self.id = id
            self.logoPath = logoPath
            self.name = name
            self.originCountry = originCountry
        }
    }
}

extension FullSingleTVResponse {
    struct ProductionCountry: Codable {
        let iso31661: String?
        let name: String?
        
        private enum CodingKeys: String, CodingKey {
            case iso31661 = "iso_3166_1"
            case name
        }
        
        init(iso31661: String?, name: String?) {
            self.iso31661 = iso31661
            self.name = name
        }
    }
}

extension FullSingleTVResponse {
    struct Season: Codable {
        let airDate: String?
        let episodeCount: Int?
        let id: Int?
        let name: String?
        let overview: String?
        let posterPath: String?
        let seasonNumber: Int?
        
        private enum CodingKeys: String, CodingKey {
            case airDate = "air_date"
            case episodeCount = "episode_count"
            case id
            case name
            case overview
            case posterPath = "poster_path"
            case seasonNumber = "season_number"
        }
        
        init(airDate: String?, episodeCount: Int?, id: Int?, name: String?, overview: String?, posterPath: String?, seasonNumber: Int?) {
            self.airDate = airDate
            self.episodeCount = episodeCount
            self.id = id
            self.name = name
            self.overview = overview
            self.posterPath = posterPath
            self.seasonNumber = seasonNumber
        }
    }
}

extension FullSingleTVResponse {
    struct SpokenLanguage: Codable {
        let englishName: String?
        let iso6391: String?
        let name: String?
        
        private enum CodingKeys: String, CodingKey {
            case englishName = "english_name"
            case iso6391 = "iso_639_1"
            case name
        }
        
        init(englishName: String?, iso6391: String?, name: String?) {
            self.englishName = englishName
            self.iso6391 = iso6391
            self.name = name
        }
    }
}

extension FullSingleTVResponse {
    struct WatchProvider: Codable {
        let results: Result?
        
        init(results: Result?) {
            self.results = results
        }
    }
}

extension FullSingleTVResponse.WatchProvider {
    struct Result: Codable {
        let CA: CountryResult?
        let US: CountryResult?
        
        init(CA: CountryResult?, US: CountryResult?) {
            self.CA = CA
            self.US = US
        }
    }
}


extension FullSingleTVResponse.WatchProvider.Result {
    struct CountryResult: Codable {
        let link: String?
        let ads: [Ad]?
        let buy: [Buy]?
        let flatrate: [Flatrate]?
        
        init(link: String?, ads: [Ad]?, buy: [Buy]?, flatrate: [Flatrate]?) {
            self.link = link
            self.ads = ads
            self.buy = buy
            self.flatrate = flatrate
        }
    }
}

extension FullSingleTVResponse.WatchProvider.Result.CountryResult {
    struct Ad: Codable {
        let logoPath: String?
        let providerID: Int?
        let providerName: String?
        let displayPriority: Int?
        
        private enum CodingKeys: String, CodingKey {
            case logoPath = "logo_path"
            case providerID = "provider_id"
            case providerName = "provider_name"
            case displayPriority = "display_priority"
        }
        
        init(logoPath: String?, providerID: Int?, providerName: String?, displayPriority: Int?) {
            self.logoPath = logoPath
            self.providerID = providerID
            self.providerName = providerName
            self.displayPriority = displayPriority
        }
    }
}

extension FullSingleTVResponse.WatchProvider.Result.CountryResult {
    struct Buy: Codable {
        let logoPath: String?
        let providerID: Int?
        let providerName: String?
        let displayPriority: Int?
        
        private enum CodingKeys: String, CodingKey {
            case logoPath = "logo_path"
            case providerID = "provider_id"
            case providerName = "provider_name"
            case displayPriority = "display_priority"
        }
        
        init(logoPath: String?, providerID: Int?, providerName: String?, displayPriority: Int?) {
            self.logoPath = logoPath
            self.providerID = providerID
            self.providerName = providerName
            self.displayPriority = displayPriority
        }
    }
}

extension FullSingleTVResponse.WatchProvider.Result.CountryResult {
    struct Flatrate: Codable, Identifiable {
        let id = UUID()
        let logoPath: String?
        let providerID: Int?
        let providerName: String?
        let displayPriority: Int?
        
        private enum CodingKeys: String, CodingKey {
            case logoPath = "logo_path"
            case providerID = "provider_id"
            case providerName = "provider_name"
            case displayPriority = "display_priority"
        }
        
        init(logoPath: String?, providerID: Int?, providerName: String?, displayPriority: Int?) {
            self.logoPath = logoPath
            self.providerID = providerID
            self.providerName = providerName
            self.displayPriority = displayPriority
        }
    }
}

extension FullSingleTVResponse {
    struct AggregateCredit: Codable {
        let cast: [Cast]?
        let crew: [Crew]?
        
        init(cast: [Cast]?, crew: [Crew]?) {
            self.cast = cast
            self.crew = crew
        }
    }
}

extension FullSingleTVResponse {
    struct ExternalID: Codable {
        let imdbID: String?
        let tvdbID: Int?
        let wikidataID: String?
        let facebookID: String?
        let instagramID: String?
        
        private enum CodingKeys: String, CodingKey {
            case imdbID = "imdb_id"
            case tvdbID = "tvdb_id"
            case wikidataID = "wikidata_id"
            case facebookID = "facebook_id"
            case instagramID = "instagram_id"
        }
        
        init(imdbID: String?, tvdbID: Int?, wikidataID: String?, facebookID: String?, instagramID: String?) {
            self.imdbID = imdbID
            self.tvdbID = tvdbID
            self.wikidataID = wikidataID
            self.facebookID = facebookID
            self.instagramID = instagramID
        }
    }
}

extension FullSingleTVResponse {
    struct TVImage: Codable {
        let backdrops: [Backdrop]?
        let logos: [Logo]?
        let posters: [Poster]?
        
        init(backdrops: [Backdrop]?, logos: [Logo]?, posters: [Poster]?) {
            self.backdrops = backdrops
            self.logos = logos
            self.posters = posters
        }
    }
}

extension FullSingleTVResponse.TVImage {
    struct Backdrop: Codable {
        let aspectRatio: Double?
        let height: Int?
        let iso6391: String?
        let filePath: String?
        let width: Int?
        
        private enum CodingKeys: String, CodingKey {
            case aspectRatio = "aspect_ratio"
            case height
            case iso6391 = "iso_639_1"
            case filePath = "file_path"
            case width
        }
        
        init(aspectRatio: Double?, height: Int?, iso6391: String?, filePath: String?, width: Int?) {
            self.aspectRatio = aspectRatio
            self.height = height
            self.iso6391 = iso6391
            self.filePath = filePath
            self.width = width
        }
    }
}

extension FullSingleTVResponse.TVImage {
    struct Logo: Codable {
        let aspectRatio: Double?
        let height: Int?
        let iso6391: String?
        let filePath: String?
        let width: Int?
        
        private enum CodingKeys: String, CodingKey {
            case aspectRatio = "aspect_ratio"
            case height
            case iso6391 = "iso_639_1"
            case filePath = "file_path"
            case width
        }
        
        init(aspectRatio: Double?, height: Int?, iso6391: String?, filePath: String?, width: Int?) {
            self.aspectRatio = aspectRatio
            self.height = height
            self.iso6391 = iso6391
            self.filePath = filePath
            self.width = width
        }
    }
}

extension FullSingleTVResponse.TVImage {
    struct Poster: Codable {
        let aspectRatio: Double?
        let height: Int?
        let iso6391: String?
        let filePath: String?
        let width: Int?
        
        private enum CodingKeys: String, CodingKey {
            case aspectRatio = "aspect_ratio"
            case height
            case iso6391 = "iso_639_1"
            case filePath = "file_path"
            case width
        }
        
        init(aspectRatio: Double?, height: Int?, iso6391: String?, filePath: String?, width: Int?) {
            self.aspectRatio = aspectRatio
            self.height = height
            self.iso6391 = iso6391
            self.filePath = filePath
            self.width = width
        }
    }
}
