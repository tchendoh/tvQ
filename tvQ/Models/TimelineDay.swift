//
//  TimelineDay.swift
//  tvQ
//
//  Created by Eric Chandonnet on 2023-12-17.
//

import Foundation

struct TimelineDay: Identifiable {
    var id = UUID()
    var date: Date
    var timelineTVs:[TimelineTV]
}

struct TimelineTV: Identifiable {
    var id = UUID()
    var tvId: Int
    var originalName: String
    var timelineEpisodes:[TimelineEpisode]
    var backdropPath: String?
    var posterPath: String?
}


struct TimelineEpisode: Identifiable {
    var id = UUID()
    var tvId: Int
    var episodeNumber: Int
    var seasonNumber: Int
}
