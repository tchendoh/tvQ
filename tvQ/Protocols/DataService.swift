//
//  DataService.swift
//  tvQ
//
//  Created by Eric Chandonnet on 2023-12-28.
//

import Foundation

protocol DataService {
    func initializeUser(userId: String) async throws -> Bool
    
    func fetchUser(userId: String) async throws -> TVUser
    
    func follow(userId: String, tvItem: TVUser.TVItem) async throws
    
    func unfollow(userId: String, tvId: TVId) async throws
    
    func isFollowed(userId: String, tvId: TVId) async throws -> Bool
    
    func updateUserCountry(userId: String, country: TVUser.Country) async throws 

    func updateUserLanguage(userId: String, language: TVUser.Language) async throws

    func filterUserListForExpiredData(list: [TVId]) async throws -> [TVId]

    func filterSearchListForExpiredData(list: [TVId]) async throws -> [TVId]
    
    func fetchActiveCachedTVFromList(list: [TVId]) async throws -> [TVUser.TVItem]
    
    func fetchCachedTVFromList(list: [TVId]) async throws -> [TVUser.TVItem]
    
    func saveCachePlan(cachePlan: [TVUser.TVItem]) async throws
}
