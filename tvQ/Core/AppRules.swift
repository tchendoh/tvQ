import Foundation

/// Toutes les règles de fonctionnement de tvQ, au même endroit : seuils, limites,
/// durées et listes. Chaque valeur dit pourquoi elle a été choisie.
///
/// Les types qui les appliquent n'en gardent qu'un alias (ex.
/// `FollowedShowsStore.maxFollowedShows`) : la valeur n'existe qu'ici. Pour savoir
/// « pourquoi telle série n'apparaît pas » ou « pourquoi cette notification n'est
/// pas partie », c'est le premier fichier à lire.
///
/// Exception : les plafonds côté serveur vivent dans `firestore.rules` (Firestore ne
/// peut pas lire ce fichier). Ils sont rappelés en commentaire là où ils comptent.
nonisolated enum AppRules {

    // MARK: - Recommandations (Home)

    nonisolated enum Recommendations {
        /// Genres TMDB écartés de Home : talk-shows (10767) et nouvelles (10763), des
        /// émissions quotidiennes qu'on ne « suit » pas comme une série. Seulement la
        /// mise en avant : la recherche les trouve toujours, et chacun peut les
        /// suivre. Les quotidiennes de fiction (ex. Antigang) sont classées comme
        /// fiction et restent. La téléréalité (10764) reste aussi, volontairement.
        static let excludedGenres: Set<Int> = [10767, 10763]

        /// Jeux télévisés quotidiens (Jeopardy!, La Roue de fortune) : écartés aussi,
        /// mais pas la téléréalité, où TMDB les range. Seuls les résultats de ce genre
        /// TMDB sont vérifiés (une fiche à charger chacun).
        static let gameShowCandidateGenre = 10764
        /// Le type TVmaze tranche quand il est connu.
        static let gameShowType = "Game Show"
        /// Sinon, repli sur TMDB : plus de 120 épisodes dans une saison récente. Les
        /// jeux en ont 150 et plus ; Survivor Québec, quotidien lui aussi, environ 67.
        static let gameShowMinSeasonEpisodes = 120
    }

    // MARK: - Horaire (Schedule)

    nonisolated enum Schedule {
        /// Saisons chargées et mises en cache pour chaque série : la saison en cours,
        /// la précédente (rattrapage) et une de marge. Évite de charger les 36 saisons
        /// des Simpson, ou les centaines d'épisodes d'une quotidienne.
        static let recentSeasonCount = 3

        /// L'horaire « à venir » garde aussi les épisodes sortis dans les 7 derniers
        /// jours, pour qu'un épisode sorti hier reste visible même si l'app n'a pas
        /// été ouverte le jour même. Sert aussi au tri « récent » de My Shows.
        static let recentlyAiredWindow: TimeInterval = 7 * 24 * 3600
    }

    // MARK: - Caches

    nonisolated enum Cache {
        /// Copie locale (SwiftData). Même durée que la copie partagée : la copie
        /// locale reprend la date d'origine de la copie Firestore, et une durée plus
        /// courte la rendait aussitôt périmée (relecture de Firestore à chaque
        /// chargement). Une série terminée ne périme jamais.
        static let localMaxAge: TimeInterval = 24 * 3600

        /// Copie partagée entre tous les utilisateurs (Firestore) : elle absorbe la
        /// charge de TMDB et TVmaze ; 24 h suffit pour un horaire de diffusion.
        static let sharedMaxAge: TimeInterval = 24 * 3600

        /// « Où regarder » : les diffuseurs d'une série changent rarement.
        static let watchAvailabilityMaxAge: TimeInterval = 72 * 3600

        /// Épisodes au-delà desquels une série n'est pas mise dans le cache partagé.
        /// Firestore refuse les documents de plus de 1 Mo (une quotidienne comme The
        /// Daily Show en fait 1,4) ; `firestore.rules` plafonne de son côté à 2000.
        static let maxSharedEpisodes = 1500
    }

    // MARK: - Séries suivies

    nonisolated enum Following {
        /// Limite douce : au-delà, suivre une série affiche un message (ne plus
        /// suivre reste possible). L'app n'a pas été conçue pour charger l'horaire de
        /// plus de séries (appels TMDB et TVmaze, limite de débit de TVmaze).
        /// `firestore.rules` plafonne de son côté à 2000.
        static let maxShows = 100
    }

    // MARK: - Notifications

    nonisolated enum Notifications {
        /// Horizon de programmation : au-delà, l'horaire aura été rechargé d'ici là.
        static let horizon: TimeInterval = 21 * 24 * 3600
        /// iOS garde au plus 64 notifications programmées par app : on garde une marge.
        static let maxCount = 60
        /// Début de la plage de nuit (23 h) ; elle se termine à l'heure du matin.
        /// Une sortie dans cette plage est annoncée le matin.
        static let nightStartMinutes = 23 * 60
        /// Durée supposée d'un épisode quand ni lui ni la série ne la donnent.
        static let defaultRuntimeMinutes = 60
    }

    // MARK: - Live Activities

    nonisolated enum LiveActivity {
        /// Apparition sur l'écran verrouillé avant le début de l'épisode.
        static let leadTime: TimeInterval = 15 * 60
        /// iOS limite le nombre d'activités simultanées, programmées comprises : on
        /// ne programme que la journée qui vient, reprogrammée à chaque ouverture.
        static let horizon: TimeInterval = 24 * 3600
        static let maxCount = 3
        /// « Terminé » reste affiché ce temps après la fin, quand l'app est ouverte
        /// (Apple recommande 15 à 30 min). Sans l'app, iOS le retire lui-même.
        static let dismissalDelay: TimeInterval = 15 * 60
    }

    // MARK: - Couleurs des séries

    nonisolated enum Colors {
        /// Part minimale de pixels pour qu'un groupe de teintes compte : 1 sur 20 (5 %).
        static let minShare = 20
        /// Écart minimal de teinte entre la dominante et l'accent : 2 groupes de 30°,
        /// soit 60°. En deçà, l'accent ressemblerait trop au fond.
        static let minAccentHueDistance = 2
        /// Contraste minimal de l'accent avec le fond : 3:1, le seuil WCAG pour les
        /// éléments graphiques (anneau, barre, compte à rebours en gros).
        static let minAccentContrast = 3.0
    }
}
