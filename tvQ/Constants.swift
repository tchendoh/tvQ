//
//  Constants.swift
//  BingeQ
//
//  Created by Eric Chandonnet on 2023-12-03.
//

/// Comes from a API request but will do for now
/// https://developer.themoviedb.org/reference/configuration-details

import Foundation

typealias TVId = Int

enum Constants {
    enum Setup {
        static let language = "en-US"
        static let dateFormat = "yyyy-MM-dd"
    }
    
    enum Tmdb {
        enum URL {
            static let scheme = "https"
            static let base = "api.themoviedb.org"
            static let searchTV = "/3/search/tv" /// Never add '/' at the end!
            static let discoverTV = "/3/discover/tv"
            static let personTV = "/3/person"
            static let singleTV = "/3/tv"
            static let seasonTV = "/3/tv"
        }
        enum Image {
            enum BaseUrl {
                static let regular = "http://image.tmdb.org/t/p/"
                static let secure = "https://image.tmdb.org/t/p/"
            }
            
            enum BackdropSize {
                static let w300 = "w300"
                static let w780 = "w780"
                static let w1280 = "w1280"
                static let original = "original"
            }
            
            enum LogoSize {
                static let w45 = "w45"
                static let w92 = "w92"
                static let w154 = "w154"
                static let w185 = "w185"
                static let w300 = "w300"
                static let w500 = "w500"
                static let original = "original"
            }
            
            enum PosterSize {
                static let w92 = "w92"
                static let w154 = "w154"
                static let w185 = "w185"
                static let w342 = "w342"
                static let w500 = "w500"
                static let w780 = "w780"
                static let original = "original"
            }
            
            enum ProfileSize {
                static let w45 = "w45"
                static let w185 = "w185"
                static let h632 = "h632"
                static let original = "original"
            }
            
            enum StillSize {
                static let w92 = "w92"
                static let w185 = "w185"
                static let w300 = "w300"
                static let original = "original"
            }
        }
        
    }
}


