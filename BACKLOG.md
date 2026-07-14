# Backlog technique — tvQ

Choses identifiées en cours de route, volontairement mises de côté pour rester fonctionnel rapidement. À revisiter, pas à ignorer.

## Performance

- **Horaire "À venir" (`RemoteScheduleRepository.getUpcomingEpisodes`)** — fait un appel réseau *par série suivie*, en séquentiel, sans cache. Avec 105 séries importées de TV Show Time, ça veut dire 100+ appels à chaque ouverture de l'app. Il faut :
  - une couche de cache local (SwiftData ou JSON) avec date de dernière synchro par série,
  - ne resynchroniser que les séries périmées (pas les 105 à chaque fois),
  - filtrer par `ShowStatus` — ignorer les séries `.ended` pour l'horaire (elles n'auront jamais de nouvel épisode), garder `.running`/`.upcoming`/`.unknown`.
  - Voir discussion du 2026-07-13.

- **`MyShowsViewModel.load(showIDs:)`** — se relance en entier à chaque follow/unfollow, donc re-résout *toutes* les séries suivies plutôt que juste celle qui a changé. Correct mais gaspille des appels réseau à mesure que la liste grossit.

- **`ShowDetailView` / `RemoteScheduleRepository.getEpisodes`** — aucun cache : rouvrir une fiche déjà vue refait tous les appels TMDB (un par saison) + TVmaze à chaque fois.

## Données / migration

- **Import des séries suivies depuis TV Show Time** — le CSV `followed_tv_show.csv` a été extrait et nettoyé (105 séries actives, `series_suivies_tvst.csv`), mais **jamais réellement importé** dans Firestore. Les IDs sont ceux de TheTVDB (TV Show Time utilisait TheTVDB comme source), pas TMDB — il faudra un script de correspondance TVDB → TMDB (TMDB a un endpoint `find` avec `external_source=tvdb_id`) avant de pouvoir peupler `users/{userID}/followedShows`.

## UX / fonctionnalités pas commencées

- **Déverrouillage biométrique automatique** (façon Tangerine) — Face ID qui redéverrouille la session au lancement sans aucun tap. Différent de Sign in with Apple (déjà fait) : ça suppose LocalAuthentication + Keychain, complètement séparé de Firebase. Pas commencé.
- **Rafraîchissement de la langue de contenu TMDB** — changer la langue dans Settings ne rafraîchit pas les écrans déjà chargés en mémoire (`TMDBClient.language` n'est lu qu'à la construction). Il faut relancer l'app. Mentionné dans le footer de `SettingsView`, pas résolu.

## Firebase / infra

- **Règles de sécurité Firestore** — à revoir/durcir une fois qu'il y a plus de collections que juste `followedShows` (ex. si on ajoute des préférences utilisateur synchronisées, des favoris, etc.).
- **`Package.resolved`** — à confirmer qu'il est bien committé (lockfile des dépendances SPM), pas juste présent localement.
- **Crashlytics** — recommandé mais pas confirmé actif dans le projet.

## Divers

- **Git** — plusieurs sessions de travail avec des changements non commités qui s'accumulent (`.gitignore`, `project.pbxproj`, et tout `Core/`, `Data/`, `Domain/`, `Presentation/` à un moment donné). Prendre une pause propre pour committer par lots logiques plutôt qu'un seul gros commit.
