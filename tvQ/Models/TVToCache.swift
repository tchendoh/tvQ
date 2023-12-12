//
//  TVToCache.swift
//  tvQ
//
//  Created by Eric Chandonnet on 2023-12-15.
//

import Foundation

struct TVToCache: Codable {
    var tvId: Int
    var originalName: String
    var isActive: Bool
    var isScripted: Bool
    var posterPath: String
    var backdropPath: String
    var popularity: Double
    var seasons: [ToCacheSeason]

    struct ToCacheSeason: Codable {
        var seasonNumber: Int
        var posterPath: String
    }
}
