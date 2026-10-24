import Foundation

/// Repository des séries : orchestre TMDBService et TVmazeService,
/// puis délègue à ShowMapper la construction du modèle `Show` final.
/// C'est le seul endroit (avec ScheduleRepository) qui connaît l'existence
/// des deux sources externes — le reste de l'app passe par ce repository.
///
/// Lecture en cascade : copie locale (ShowStore, SwiftData), puis copie partagée
/// (Firestore), puis TMDB/TVmaze. Une copie locale périmée est retournée quand même
/// et rafraîchie en arrière-plan, pour que résoudre ~100 séries suivies (Schedule,
/// My Shows) ne bloque jamais l'écran sur le réseau.
final class ShowRepository {
    /// Instance unique partagée par tous les écrans : c'est ce qui permet à `inFlight`
    /// de dédoublonner les requêtes d'un écran à l'autre. L'`init` reste public
    /// pour injecter une autre instance dans les tests.
    static let shared = ShowRepository()

    private let tmdbService: any TMDBFetching
    private let tvmazeService: any TVmazeFetching
    private let showStore: ShowStore
    private let watchAvailabilityStore: WatchAvailabilityStore
    private let sharedCache: any SharedShowCaching
    private let colorExtractor: any ShowColorExtracting

    /// Résolutions distantes déjà en cours, par clé de cache : deux écrans qui demandent
    /// la même série en même temps partagent un seul appel au lieu de le doubler.
    private var inFlight: [String: Task<Show, Error>] = [:]
    /// Séries dont la couleur manquante a déjà été cherchée pendant ce lancement :
    /// une image introuvable ne doit pas relancer le calcul à chaque lecture.
    private var colorBackfillAttempted: Set<String> = []

    init(
        tmdbService: any TMDBFetching = TMDBService(),
        tvmazeService: any TVmazeFetching = TVmazeService(),
        showStore: ShowStore = .shared,
        watchAvailabilityStore: WatchAvailabilityStore = .shared,
        sharedCache: any SharedShowCaching = FirestoreShowCacheService(),
        colorExtractor: any ShowColorExtracting = ShowColorExtractor()
    ) {
        self.colorExtractor = colorExtractor
        self.tmdbService = tmdbService
        self.tvmazeService = tvmazeService
        self.showStore = showStore
        self.watchAvailabilityStore = watchAvailabilityStore
        self.sharedCache = sharedCache
    }

    // MARK: - Recherche et découverte

    func search(query: String) async throws -> [ShowSummary] {
        let results = try await tmdbService.searchShows(query: query)
        return results.map(mapToSummary)
    }

    func trendingShows() async throws -> [ShowSummary] {
        try await recommendations(from: tmdbService.fetchTrendingTV())
    }

    func onTheAirShows() async throws -> [ShowSummary] {
        try await recommendations(from: tmdbService.fetchOnTheAirTV())
    }

    func airingTodayShows() async throws -> [ShowSummary] {
        try await recommendations(from: tmdbService.fetchAiringTodayTV())
    }

    /// Filtre par genre, puis écarte les jeux quotidiens. Seuls les résultats du genre
    /// candidat (téléréalité chez TMDB) demandent leur fiche, en parallèle et par les
    /// caches ; une fiche introuvable garde la série (dans le doute, on montre).
    private func recommendations(from results: [TMDBSearchResultDTO]) async -> [ShowSummary] {
        let byGenre = results.filter(Self.isRecommendable)
        let candidateIDs = byGenre
            .filter { ($0.genreIDs ?? []).contains(AppRules.Recommendations.gameShowCandidateGenre) }
            .map(\.id)

        let gameShowIDs: Set<Int> = await withTaskGroup(of: Int?.self) { group in
            for id in candidateIDs {
                group.addTask {
                    guard let show = try? await self.getShow(tmdbID: id) else { return nil }
                    return Self.isGameShow(show) ? id : nil
                }
            }
            var ids: Set<Int> = []
            for await id in group {
                if let id { ids.insert(id) }
            }
            return ids
        }
        return byGenre.filter { !gameShowIDs.contains($0.id) }.map(mapToSummary)
    }

    /// Jeu quotidien : type TVmaze « Game Show » ; sans TVmaze, une saison récente de
    /// plus de 120 épisodes chez TMDB. Voir AppRules.Recommendations.
    nonisolated static func isGameShow(_ show: Show) -> Bool {
        if let type = show.tvmazeType {
            return type == AppRules.Recommendations.gameShowType
        }
        guard let count = show.recentSeasonEpisodeCount else { return false }
        return count > AppRules.Recommendations.gameShowMinSeasonEpisodes
    }

    /// Genres écartés de Home : voir AppRules.Recommendations.
    static func isRecommendable(_ dto: TMDBSearchResultDTO) -> Bool {
        AppRules.Recommendations.excludedGenres.isDisjoint(with: dto.genreIDs ?? [])
    }

    private func mapToSummary(_ dto: TMDBSearchResultDTO) -> ShowSummary {
        ShowSummary(
            tmdbID: dto.id,
            title: dto.name,
            overview: dto.overview,
            posterURL: dto.posterPath.map { ShowMapper.imageBaseURL.appendingPathComponent($0) }
        )
    }

    // MARK: - Série complète

    func getShow(tmdbID: Int) async throws -> Show {
        // La clé inclut la langue effective : la copie Firestore est partagée entre
        // utilisateurs et le contenu (titre, résumé) est localisé.
        let cacheKey = "\(tmdbID)_\(AppSettings.cacheLanguageKey)"

        if let local = try? await showStore.entry(cacheKey: cacheKey) {
            let isEnded = local.value.status == .ended
            if !CachePolicy.local.isFresh(syncedAt: local.syncedAt, isEnded: isEnded) {
                Task {
                    do {
                        _ = try await self.resolveRemotely(tmdbID: tmdbID, cacheKey: cacheKey)
                    } catch {
                        // Hors ligne, par exemple : la copie périmée reste en place.
                        Log.network.info("Rafraîchissement de la série \(cacheKey) échoué : \(error)")
                    }
                }
            } else {
                backfillColorIfNeeded(local, cacheKey: cacheKey)
            }
            return local.value
        }

        return try await resolveRemotely(tmdbID: tmdbID, cacheKey: cacheKey)
    }

    /// Copie locale seulement : aucun réseau, aucun rafraîchissement. Sert à relire
    /// l'écran après un changement de la base locale (voir LocalDataVersion) ; nil si
    /// la série n'a encore jamais été synchronisée sur cet appareil.
    func localShow(tmdbID: Int) async -> Show? {
        let cacheKey = "\(tmdbID)_\(AppSettings.cacheLanguageKey)"
        return try? await showStore.entry(cacheKey: cacheKey)?.value
    }

    /// Copie partagée puis TMDB/TVmaze, avec écriture dans les deux copies.
    private func resolveRemotely(tmdbID: Int, cacheKey: String) async throws -> Show {
        if let task = inFlight[cacheKey] {
            return try await task.value
        }

        let task = Task { try await self.loadFromSharedOrRemote(tmdbID: tmdbID, cacheKey: cacheKey) }
        inFlight[cacheKey] = task
        defer { inFlight[cacheKey] = nil }
        return try await task.value
    }

    private func loadFromSharedOrRemote(tmdbID: Int, cacheKey: String) async throws -> Show {
        if let shared = try? await sharedCache.show(cacheKey: cacheKey),
           CachePolicy.shared.isFresh(syncedAt: shared.syncedAt, isEnded: shared.value.status == .ended) {
            // On garde la date d'origine : une copie déjà vieille ne redevient pas "fraîche".
            try? await showStore.save(shared.value, cacheKey: cacheKey, syncedAt: shared.syncedAt)
            backfillColorIfNeeded(shared, cacheKey: cacheKey)
            return shared.value
        }

        let show = try await fetchShow(tmdbID: tmdbID)
        let now = Date.now

        // Écriture best-effort dans la copie partagée : un échec (hors ligne, règles
        // Firestore) ne doit pas empêcher de retourner le résultat à l'utilisateur.
        try? await sharedCache.store(cacheKey: cacheKey, show: show, syncedAt: now)
        do {
            try await showStore.save(show, cacheKey: cacheKey, syncedAt: now)
        } catch {
            Log.data.error("Sauvegarde locale de la série \(cacheKey) échouée", error, report: true)
        }
        return show
    }

    /// Appel direct aux APIs externes, sans passer par aucun cache.
    private func fetchShow(tmdbID: Int) async throws -> Show {
        var tmdbShow = try await tmdbService.fetchShowDetails(id: tmdbID)

        // Si l'utilisateur préfère la langue d'origine et qu'elle diffère de la langue
        // de contenu par défaut, on refait un appel ciblé — TMDB ne garantit pas un
        // repli fiable vers la langue d'origine sur cet endpoint.
        if AppSettings.useOriginalLanguage, !AppSettings.contentLanguage.hasPrefix(tmdbShow.originalLanguage) {
            tmdbShow = try await tmdbService.fetchShowDetails(id: tmdbID, language: tmdbShow.originalLanguage)
        }

        // Pas d'erreur si l'IMDB ID est absent : la série reste utilisable,
        // elle perd juste l'horaire précis TVmaze (repli sur les dates TMDB).
        var tvmazeShow: TVmazeShowDTO?
        if let imdbID = tmdbShow.externalIDs?.imdbID {
            tvmazeShow = try await tvmazeService.lookupShow(imdbID: imdbID)
        }

        var show = ShowMapper.map(tmdb: tmdbShow, tvmaze: tvmazeShow)
        // Une fois par résolution distante (au plus toutes les 12-24 h), puis gardée
        // dans les deux copies : les écrans et la Live Activity ne la recalculent pas.
        if let url = show.colorSourceURL {
            show.apply(await colorExtractor.palette(for: url))
        }
        return show
    }

    // MARK: - Couleur dominante

    /// Copie en cache sans couleur (antérieure à son ajout, image indisponible à
    /// l'époque, ou calculée par une ancienne version : voir Show.colorVersion) : la calcule en arrière-plan et met à jour les deux copies, sans
    /// toucher à leur date de synchronisation. Utile surtout pour les séries
    /// terminées, dont la copie ne se rafraîchit jamais.
    private func backfillColorIfNeeded(_ cached: Cached<Show>, cacheKey: String) {
        // Couleurs absentes, ou calculées par une autre version (ex. sur l'image
        // de fond avant le passage à l'affiche) : Show.currentColorVersion.
        guard cached.value.dominantColor == nil || cached.value.colorVersion != Show.currentColorVersion,
              let url = cached.value.colorSourceURL,
              !colorBackfillAttempted.contains(cacheKey)
        else { return }
        colorBackfillAttempted.insert(cacheKey)
        Task {
            guard let palette = await colorExtractor.palette(for: url) else { return }
            var show = cached.value
            show.apply(palette)
            guard show != cached.value else { return }
            try? await showStore.save(show, cacheKey: cacheKey, syncedAt: cached.syncedAt)
            try? await sharedCache.store(cacheKey: cacheKey, show: show, syncedAt: cached.syncedAt)
        }
    }

    // MARK: - Où regarder

    /// Disponibilité de visionnement dans la région choisie (AppSettings.watchProviderRegion).
    /// Best-effort : nil si rien n'est connu, sans jamais faire échouer la fiche de la série.
    /// Copie locale seulement (pas de copie partagée, la donnée dépend de la région).
    func getWatchAvailability(tmdbID: Int) async -> WatchAvailability? {
        let region = AppSettings.watchProviderRegion
        let cacheKey = "\(tmdbID)_\(region)"
        let cached = try? await watchAvailabilityStore.entry(cacheKey: cacheKey)

        if let cached, CachePolicy.watchAvailability.isFresh(syncedAt: cached.syncedAt) {
            return cached.value
        }

        guard let dto = try? await tmdbService.fetchWatchProviders(seriesID: tmdbID) else {
            // Réseau indisponible : une donnée périmée vaut mieux que rien.
            return cached?.value
        }

        let availability = WatchAvailabilityMapper.map(dto: dto, region: region)
        try? await watchAvailabilityStore.save(availability, cacheKey: cacheKey)
        return availability
    }
}
