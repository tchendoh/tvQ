import Foundation

/// Une valeur lue dans un store local, avec sa date de synchronisation. Le store ne
/// décide jamais si c'est trop vieux : la politique de fraîcheur (durée de validité,
/// stale-while-revalidate, séries terminées) appartient au repository.
nonisolated struct Cached<Value: Sendable>: Sendable {
    let value: Value
    let syncedAt: Date
}
