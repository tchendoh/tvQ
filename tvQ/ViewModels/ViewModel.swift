//
//  ViewModel.swift
//  tvQ
//
//  Created by Eric Chandonnet on 2023-12-13.
//

import Foundation
import Observation
import Firebase
import FirebaseFirestore
import FirebaseFirestoreSwift

enum ViewModelError: Error {
    case noUserLoggedIn
    case userNotInitialized
    case invalidDate
}

@Observable
final class ViewModel {
    private var api: APIService
    private var db: DataService
    private let dateFormatter = DateFormatter()
    private var isUserInitialized: Bool = false
    private var userId: String?
    
    init(apiService: APIService, dataService: DataService) {
        self.api = apiService
        self.db = dataService
        dateFormatter.dateFormat = "yyyy-MM-dd"
    }
    
    func initializeUser(userId: String) async throws -> Bool {
        if isUserInitialized {
            return true
        }
        if try await db.initializeUser(userId: userId) {
            self.userId = userId
            return true
        }
        return false
    }
    
    func fetchUser(userId: String) async throws -> TVUser {
        return try await db.fetchUser(userId: userId)
    }
    
    func fetchSingleTV(tvId: TVId) async throws -> SingleTVResponse {
        return try await api.fetchSingleTV(tvId: tvId)
    }

    func fetchFullSingleTV(tvId: TVId) async throws -> FullSingleTVResponse {
        return try await api.fetchFullSingleTV(tvId: tvId)
    }

    func fetchPerson(personId: Int) async throws -> Person {
        return try await api.fetchPerson(personId: personId)
    }

    func follow(tvItem: TVUser.TVItem) async throws {
        guard let userId else {
            throw ViewModelError.noUserLoggedIn
        }
        try await db.follow(userId: userId, tvItem: tvItem)
    }
    
    func unfollow(tvId: TVId) async throws {
        guard let userId else {
            throw ViewModelError.noUserLoggedIn
        }
        try await db.unfollow(userId: userId, tvId: tvId)
    }
    
    func isFollowed(tvId: TVId) async throws -> Bool {
        guard let userId else {
            throw ViewModelError.noUserLoggedIn
        }
        return try await db.isFollowed(userId: userId, tvId: tvId)
    }
    
    func updateUserCountry(country: TVUser.Country) async throws {
        guard let userId else {
            throw ViewModelError.noUserLoggedIn
        }
        try await db.updateUserCountry(userId: userId, country: country)
    }
    
    func updateUserLanguage(language: TVUser.Language) async throws {
        guard let userId else {
            throw ViewModelError.noUserLoggedIn
        }
        try await db.updateUserLanguage(userId: userId, language: language)
    }
    
    func fromStringToDate(_ stringDate: String) throws -> Date {
        guard let stringDate = dateFormatter.date(from: stringDate) else {
            throw ViewModelError.invalidDate
        }
        return stringDate
    }
    
    private func isScripted(type: String) -> Bool {
        if type == "Scripted" || type == "Miniseries" {
            return true
        } else {
            return false
        }
    }
    
    func fetchUserTVItems(userId: String) async throws -> [TVUser.TVItem] {
        let tvUser = try await fetchUser(userId: userId)
        let list = getListFromTVItems(items: tvUser.items)
        try await cacheUserList(list: list)
        return try await fetchCachedTVFromList(list: list)
    }
    
    
    func search(query: String) async throws -> [TVUser.TVItem] {
        let results = try await fetchTVSearchResults(query: query)
        let searchList:[TVId] = results.map { $0.id }
        try await cacheSearchList(list: searchList)
        let fetchedList:[TVUser.TVItem] = try await fetchCachedTVFromList(list: searchList)
        return filterSearchList(list: fetchedList)
    }

    private func fetchTVSearchResults(query: String) async throws -> [SearchTVResponse.Result] {
        return try await api.fetchTVSearchResults(query: query, numberOfResults: 14)
    }

    private func filterSearchList(list: [TVUser.TVItem]) -> [TVUser.TVItem] {
        var scriptedList = list
        scriptedList.removeAll(where: { !$0.isScripted } )
        return scriptedList.sorted { $0.popularity > $1.popularity }
    }
    
    private func cacheSearchList(list: [TVId]) async throws {
        let searchListToUpdate: [TVId] = try await filterSearchListForExpiredData(list: list)
        let toCachePlan: [TVToCache] = try await createCachePlanFromList(list: searchListToUpdate, withSeasons: false)
        let cachingPlan: [TVUser.TVItem] = try await addAPIDataToCachePlan(cachePlan: toCachePlan)
        try await saveCachePlan(cachingPlan)
    }

    func populateTimeline(userId: String) async throws -> [TimelineDay] {
        let tvUser = try await fetchUser(userId: userId)
        let list = getListFromTVItems(items: tvUser.items)
        try await cacheUserList(list: list)
        let cachedTVList = try await fetchActiveCachedTVFromList(list: list)
        return try await processTimeline(cachedTVList: cachedTVList)
    }
    
    private func getListFromTVItems(items: [TVUser.TVItem]) -> [Int] {
        return items.map { $0.tvId }
    }

    private func cacheUserList(list: [TVId]) async throws {
        let userListToUpdate: [TVId] = try await filterUserListForExpiredData(list: list)
        let toCachePlan: [TVToCache] = try await createCachePlanFromList(list: userListToUpdate)
        let cachingPlan: [TVUser.TVItem] = try await addAPIDataToCachePlan(cachePlan: toCachePlan)
        try await saveCachePlan(cachingPlan)
    }
    
    private func filterSearchListForExpiredData(list: [TVId]) async throws -> [TVId] {
        return try await db.filterSearchListForExpiredData(list: list)
    }

    private func filterUserListForExpiredData(list: [TVId]) async throws -> [TVId] {
        return try await db.filterUserListForExpiredData(list: list)
    }

    private func createCachePlanFromList(list: [TVId], withSeasons: Bool = true) async throws -> [TVToCache] {
        var cachePlan: [TVToCache] = []
        do {
            for tvId in list {
                let singleTV = try await fetchSingleTV(tvId: tvId)
                if let inProduction = singleTV.inProduction, let type = singleTV.type {
                    var toCacheSeasons:[TVToCache.ToCacheSeason] = []
                    if withSeasons {
                        if let seasons = singleTV.seasons, let numberOfSeasons = singleTV.numberOfSeasons {
                            for season in seasons {
                                if let seasonNumber = season.seasonNumber {
                                    /// Only cache the last two seasons
                                    if seasonNumber == numberOfSeasons || seasonNumber == (numberOfSeasons - 1) {
                                        toCacheSeasons.append(TVToCache.ToCacheSeason(seasonNumber: seasonNumber, posterPath: season.posterPath ?? ""))
                                    }
                                    
                                }
                            }
                        }
                    }
                    cachePlan.append(TVToCache(tvId: tvId, originalName: singleTV.originalName, isActive: inProduction, isScripted: isScripted(type: type), posterPath: singleTV.posterPath ?? "", backdropPath: singleTV.backdropPath ?? "", popularity: singleTV.popularity ?? 0.0, seasons: toCacheSeasons))
                }
            }
        } catch {
            print(error.localizedDescription)
            throw(error)
        }
        return cachePlan
    }
    
    
    private func addAPIDataToCachePlan(cachePlan: [TVToCache]) async throws -> [TVUser.TVItem] {
        var cachingPlan:[TVUser.TVItem] = []
        let oneMonthAgo = Calendar.current.date(byAdding: .month, value: -1, to: Date())!

        for toCacheTV in cachePlan {
            var cachingSeasons:[TVUser.TVItem.Season] = []
            if toCacheTV.isActive {
                for toCacheSeason in toCacheTV.seasons {
                    var cachingEpisodes:[TVUser.TVItem.Episode] = []
                    let season = try await api.fetchTVSeason(tvId: toCacheTV.tvId, seasonNumber: toCacheSeason.seasonNumber)
                    if let episodes = season.episodes {
                        try episodes.forEach { episode in
                            if let episodeNumber = episode.episodeNumber, let stringDate = episode.airDate {
                                let airDate = try fromStringToDate(stringDate)
                                cachingEpisodes.append(TVUser.TVItem.Episode(episodeNumber: episodeNumber, seasonNumber: toCacheSeason.seasonNumber, airDate: airDate, lastUpdate: Date.now))
                            }
                        }
                    }
                    cachingSeasons.append(TVUser.TVItem.Season(seasonNumber: toCacheSeason.seasonNumber, episodes: cachingEpisodes, posterPath: toCacheSeason.posterPath, lastUpdate: Date.now))
                }
            }
            /// if we don't update seasons to save time, lastSeasonUpdate is given an expired date so we know it needs an update
            cachingPlan.append(TVUser.TVItem(tvId: toCacheTV.tvId, originalName: toCacheTV.originalName, isActive: toCacheTV.isActive, isScripted: toCacheTV.isScripted, posterPath: toCacheTV.posterPath, backdropPath: toCacheTV.backdropPath, popularity: toCacheTV.popularity, lastUpdate: Date.now, lastSeasonUpdate: (cachingSeasons.isEmpty ? oneMonthAgo : Date.now), seasons: cachingSeasons))
        }
        return cachingPlan
    }
    
    private func saveCachePlan(_ cachePlan: [TVUser.TVItem]) async throws {
        try await db.saveCachePlan(cachePlan: cachePlan)
    }
    
    private func fetchCachedTVFromList(list: [TVId]) async throws -> [TVUser.TVItem] {
        return try await db.fetchCachedTVFromList(list: list)
        
    }

    

    private func fetchActiveCachedTVFromList(list: [TVId]) async throws -> [TVUser.TVItem] {
        return try await db.fetchActiveCachedTVFromList(list: list)
        
    }
    
    private func processTimeline(cachedTVList: [TVUser.TVItem]) async throws -> [TimelineDay] {
        guard let oneMonthAgo = Calendar.current.date(byAdding: .month, value: -1, to: Date.now) else {
            print("invalid date")
            return []
        }

        var days:[Date:[TimelineEpisode]] = [:]
        var tvDictionnary: [TVId: TimelineTV] = [:]
        
        for tv in cachedTVList {
            if tvDictionnary[tv.tvId] == nil {
                tvDictionnary[tv.tvId] = TimelineTV(tvId: tv.tvId, originalName: tv.originalName, timelineEpisodes: [], backdropPath: tv.backdropPath, posterPath: tv.posterPath)
            }
            for season in tv.seasons {
                for episode in season.episodes {
                    if episode.airDate > oneMonthAgo {
                        if days[episode.airDate] == nil {
                            days[episode.airDate] = []
                        }
                        days[episode.airDate]?.append(TimelineEpisode(tvId: tv.tvId, episodeNumber: episode.episodeNumber, seasonNumber: episode.seasonNumber))
                    }
                }
            }
        }

        let tupleTimeline = days.map { (date, episodes) in (date, episodes) }
        let sortedTupleTimeline = tupleTimeline.sorted { $0.0 < $1.0 }
        
        var timeline: [TimelineDay] = []
        for (date, episodes) in sortedTupleTimeline {
            var day = TimelineDay(date: date, timelineTVs: [])
            let uniqueTVIds = Set(episodes.map { $0.tvId })
            var groupedEpisodesByTVId: [TVId: [TimelineEpisode]] = [:]
            for tvId in uniqueTVIds {
                groupedEpisodesByTVId[tvId] = []
            }
            for episode in episodes {
                groupedEpisodesByTVId[episode.tvId]?.append(episode)
            }
            for tvId in uniqueTVIds {
                day.timelineTVs.append(TimelineTV(tvId: tvId, originalName: tvDictionnary[tvId]?.originalName ?? "", timelineEpisodes: groupedEpisodesByTVId[tvId] ?? [], backdropPath: tvDictionnary[tvId]?.backdropPath, posterPath: tvDictionnary[tvId]?.posterPath))
            }
            timeline.append(day)
        }
        return timeline
    }

}
