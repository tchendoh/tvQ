//
//  DataManager.swift
//  tvQ
//
//  Created by Eric Chandonnet on 2023-12-13.
//

import Foundation
import FirebaseFirestore
import FirebaseFirestoreSwift

enum DataManagerError: Error {
    case userWithoutList
    case userDoesntExist
}

final class DataManager: DataService {
    
    let db = Firestore.firestore()
    
    init() {
    }

    func initializeUser(userId: String) async throws -> Bool {
        let collectionRef = db.collection("tvUsers")
        let documentRef = collectionRef.document(userId)
        let documentSnapshot = try await documentRef.getDocument()
        if documentSnapshot.exists {
            return true
        } else {
            try documentRef.setData(from: TVUser())
            return true
        }
    }
    

    func fetchUser(userId: String) async throws -> TVUser {
        let collectionRef = db.collection("tvUsers")
        let documentRef = collectionRef.document(userId)
        do {
            let documentSnapshot = try await documentRef.getDocument()

            if documentSnapshot.exists {
                let tvUser = try documentSnapshot.data(as: TVUser.self)
                return tvUser

            } else {
                throw DataManagerError.userDoesntExist
            }
        } catch {
            print("Error while fetching list from Firestore : \(error)")
            throw error
        }
    }
    
    func follow(userId: String, tvItem: TVUser.TVItem) async throws {

        let collection = db.collection("tvUsers")
        let docRef = collection.document(userId)
        do {
            let documentSnapshot = try await docRef.getDocument()
            
            if documentSnapshot.exists {
                var snapshot = try documentSnapshot.data(as: TVUser.self)
                if snapshot.items.contains(where: { $0.tvId == tvItem.tvId }) {
                }
                else {
                    snapshot.items.append(tvItem)
                    try docRef.setData(from: snapshot)
                }
                
            } else {
                throw DataManagerError.userWithoutList
            }
        } catch {
            print("Error while trying to add a follow to Firestore : \(error)")
            throw error
        }
    }
    
    func unfollow(userId: String, tvId: TVId) async throws {

        let collection = db.collection("tvUsers")
        let docRef = collection.document(userId)
        do {
            let documentSnapshot = try await docRef.getDocument()
            
            if documentSnapshot.exists {
                var snapshot = try documentSnapshot.data(as: TVUser.self)
                snapshot.items.removeAll(where: { $0.tvId == tvId })
                try docRef.setData(from: snapshot)
            } else {
                throw DataManagerError.userWithoutList
            }
        } catch {
            print("Error while trying to remove a follow from Firestore : \(error)")
            throw error
        }
    }

    func isFollowed(userId: String, tvId: TVId) async throws -> Bool {

        let collection = db.collection("tvUsers")
        let docRef = collection.document(userId)
        do {
            let documentSnapshot = try await docRef.getDocument()
            
            if documentSnapshot.exists {
                let snapshot = try documentSnapshot.data(as: TVUser.self)
                if snapshot.items.contains(where: { $0.tvId == tvId }) {
                    return true
                }
            } else {
                throw DataManagerError.userWithoutList
            }
        } catch {
            print("Error while trying to know if series is followed in Firestore : \(error)")
            throw error
        }
        return false
    }
    
    func filterUserListForExpiredData(list: [TVId]) async throws -> [TVId] {
        guard !list.isEmpty else {
            return []
        }
        var list = list
        let twentyFourHoursAgo = Calendar.current.date(byAdding: .hour, value: -24, to: Date())!
        let cacheRef = db.collection("tvSeries")
            .whereField("tvId", in: list)
            .whereField("lastSeasonUpdate", isGreaterThan: twentyFourHoursAgo)
        let docRef = try await cacheRef.getDocuments()
        
        try docRef.documents.forEach { document in
            let snapshot = try document.data(as: TVUser.TVItem.self)
            list.removeAll(where: { $0 == snapshot.tvId } )
        }
        return list
    }

    func filterSearchListForExpiredData(list: [TVId]) async throws -> [TVId] {
        guard !list.isEmpty else {
            return []
        }
        var list = list
        let aWeekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
        let cacheRef = db.collection("tvSeries")
            .whereField("tvId", in: list)
            .whereField("lastUpdate", isGreaterThan: aWeekAgo)
        let docRef = try await cacheRef.getDocuments()
        
        try docRef.documents.forEach { document in
            let snapshot = try document.data(as: TVUser.TVItem.self)
            list.removeAll(where: { $0 == snapshot.tvId } )
        }
        return list
    }

    func fetchActiveCachedTVFromList(list: [TVId]) async throws -> [TVUser.TVItem] {
        guard !list.isEmpty else {
            return []
        }

        let cacheRef = db.collection("tvSeries")
            .whereField("tvId", in: list)
            .whereField("isActive", isEqualTo: true)
        let docRef = try await cacheRef.getDocuments()
        
        var cachedTVList:[TVUser.TVItem] = []
        
        try docRef.documents.forEach { item in
            try cachedTVList.append(item.data(as: TVUser.TVItem.self))
        }
        return cachedTVList
    }
    
    func fetchCachedTVFromList(list: [TVId]) async throws -> [TVUser.TVItem] {
        guard !list.isEmpty else {
            return []
        }
        let cacheRef = db.collection("tvSeries")
            .whereField("tvId", in: list)
        let docRef = try await cacheRef.getDocuments()
        
        var cachedTVList:[TVUser.TVItem] = []
        
        try docRef.documents.forEach { item in
            try cachedTVList.append(item.data(as: TVUser.TVItem.self))
        }
        return cachedTVList
    }

    func saveCachePlan(cachePlan: [TVUser.TVItem]) async throws {
        
        let collection = db.collection("tvSeries")
        for cachingTV in cachePlan {
            let docRef = collection.document(String(cachingTV.tvId))
            do {
                let documentSnapshot = try await docRef.getDocument()
                
                if documentSnapshot.exists {
                    // c'est ici qu'on vérifie la date pour savoir si ça vaut la peine d'updater
                    try docRef.setData(from: cachingTV)
                } else {
                    try docRef.setData(from: cachingTV)
                }
            } catch {
                print("Error while saving cachePlan to Firestore : \(error)")
                throw error
            }

        }
    }
    
    func updateUserCountry(userId: String, country: TVUser.Country) async throws {
        let userRef = db.collection("tvUsers").document(userId)
        do {
            try await userRef.updateData(["country": country.rawValue])
        } catch {
            print("Error while trying to updateUserCountry to Firestore : \(error)")
            throw error
        }
    }
    
    func updateUserLanguage(userId: String, language: TVUser.Language) async throws {
        let userRef = db.collection("tvUsers").document(userId)
        do {
            try await userRef.updateData(["language": language.rawValue])
        } catch {
            print("Error while trying to updateUserLanguage to Firestore : \(error)")
            throw error
        }
    }
}
