import Foundation
import FirebaseRemoteConfig

/// Jeton TMDB tiré de Firebase Remote Config (clé `tmdb_token`).
///
/// - Lancements suivants : Remote Config garde sur disque la dernière valeur activée,
///   disponible immédiatement ; un rafraîchissement part en arrière-plan.
/// - Premier lancement : aucune valeur en cache, donc la première requête TMDB attend
///   la fin du premier `fetchAndActivate()`. Hors ligne, l'erreur réseau habituelle
///   remonte (pas de jeton par défaut dans l'app, volontairement).
/// Source du jeton : Remote Config dans l'app, une doublure dans les tests.
nonisolated protocol TMDBTokenSource: Sendable {
    /// Dernière valeur activée, lue localement sans réseau ; nil si vide.
    func cachedToken() -> String?
    func fetchAndActivate() async throws
    /// Comme fetchAndActivate, mais sans tenir compte de l'intervalle minimal entre
    /// deux récupérations (12 h en Release).
    func forceFetchAndActivate() async throws
}

nonisolated struct RemoteConfigTokenSource: TMDBTokenSource {
    init() {
        #if DEBUG
        // En développement, voir tout de suite un changement fait dans la console.
        let settings = RemoteConfigSettings()
        settings.minimumFetchInterval = 0
        RemoteConfig.remoteConfig().configSettings = settings
        #endif
    }

    func cachedToken() -> String? {
        let token = RemoteConfig.remoteConfig()[TMDBToken.key].stringValue
        return token.isEmpty ? nil : token
    }

    func fetchAndActivate() async throws {
        _ = try await RemoteConfig.remoteConfig().fetchAndActivate()
    }

    func forceFetchAndActivate() async throws {
        let remoteConfig = RemoteConfig.remoteConfig()
        _ = try await remoteConfig.fetch(withExpirationDuration: 0)
        _ = try await remoteConfig.activate()
    }
}

actor TMDBToken {
    static let shared = TMDBToken()
    nonisolated static let key = "tmdb_token"

    enum TokenError: LocalizedError {
        case missing
        var errorDescription: String? {
            String(localized: "Configuration TMDB indisponible. Réessayez plus tard.")
        }
    }

    /// Chargement en cours, partagé par tous les appelants simultanés.
    private var inFlight: Task<Void, Error>?
    /// Une seule récupération par lancement suffit.
    private var fetchedThisLaunch = false
    /// Récupération forcée après un refus du jeton, partagée par les requêtes refusées
    /// en même temps.
    private var forcedFetch: Task<Void, Error>?
    /// Au plus une récupération forcée par minute : un jeton invalide dans la console
    /// ne doit pas déclencher une récupération par requête TMDB.
    private var lastForcedFetch: Date?
    static let forcedFetchInterval: TimeInterval = 60

    private let source: any TMDBTokenSource

    init(source: any TMDBTokenSource = RemoteConfigTokenSource()) {
        self.source = source
    }

    /// Appelé au démarrage : lance le chargement sans attendre.
    func prefetch() {
        _ = startFetch()
    }

    func value() async throws -> String {
        if let token = currentToken() {
            if !fetchedThisLaunch { _ = startFetch() }   // rafraîchir en arrière-plan
            return token
        }
        try await startFetch().value
        guard let token = currentToken() else { throw TokenError.missing }
        return token
    }

    /// TMDB a refusé `rejected` : va chercher la valeur actuelle dans Remote Config.
    /// Retourne le nouveau jeton, ou nil s'il n'a pas changé.
    func refreshAfterRejection(of rejected: String, now: Date = .now) async throws -> String? {
        // Une autre requête refusée a peut-être déjà fait le travail.
        if let current = currentToken(), current != rejected { return current }
        if let forcedFetch {
            try await forcedFetch.value
        } else if lastForcedFetch.map({ now.timeIntervalSince($0) >= Self.forcedFetchInterval }) ?? true {
            lastForcedFetch = now
            let source = self.source
            let task = Task { try await source.forceFetchAndActivate() }
            forcedFetch = task
            defer { forcedFetch = nil }
            try await task.value
        }
        guard let token = currentToken(), token != rejected else { return nil }
        return token
    }

    private func currentToken() -> String? {
        source.cachedToken()
    }

    private func startFetch() -> Task<Void, Error> {
        if let inFlight { return inFlight }
        fetchedThisLaunch = true
        let source = self.source
        let task = Task {
            do {
                try await source.fetchAndActivate()
                self.clearInFlight(failed: false)
            } catch {
                self.clearInFlight(failed: true)
                throw error
            }
        }
        inFlight = task
        return task
    }

    private func clearInFlight(failed: Bool) {
        inFlight = nil
        if failed { fetchedThisLaunch = false }   // réessayer à la prochaine requête
    }
}
