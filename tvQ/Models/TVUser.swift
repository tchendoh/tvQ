//
//  TVUser.swift
//  tvQ
//
//  Created by Eric Chandonnet on 2023-12-13.
//

import Foundation
import FirebaseFirestore


struct TVUser: Codable {
    enum Country: String, Codable, CaseIterable {
        case canada = "CA"
        case unitedStates = "US"
        
        var englishName: String {
            switch self {
            case .canada:
                "Canada"
            case .unitedStates:
                "United States"
            }
        }
        var frenchName: String {
            switch self {
            case .canada:
                "Canada"
            case .unitedStates:
                "États-Unis"
            }

        }
    }
    
    enum Language: String, Codable, CaseIterable {
        case french = "fr"
        case english = "en"
        
        var englishName: String {
            switch self {
            case .french:
                "French"
            case .english:
                "English"
            }
        }
        var frenchName: String {
            switch self {
            case .french:
                "Français"
            case .english:
                "Anglais"
            }
        }

    }
    
    @DocumentID var id: String?
    var items: [TVItem]
    var country: Country
    var language: Language
    
    struct TVItem: Codable, Identifiable {
        @DocumentID var id: String?
        var tvId: Int
        var originalName: String
        var isActive: Bool
        var isScripted: Bool
        var posterPath: String
        var backdropPath: String
        var popularity: Double
        var lastUpdate: Date
        var lastSeasonUpdate: Date
        var seasons: [Season]
        
        struct Season: Codable {
            var seasonNumber: Int
            var episodes: [Episode]
            var posterPath: String?
            var lastUpdate: Date
        }
        
        struct Episode: Codable {
            var episodeNumber: Int
            var seasonNumber: Int
            var airDate: Date
            var lastUpdate: Date
        }
    }
    
    init(items: [TVItem] = [], country: Country = .canada, language: Language = .english) {
        self.items = items
        self.country = country
        self.language = language
    }
    
}

