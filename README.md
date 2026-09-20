# tvQ

Application iOS (SwiftUI) pour suivre l'horaire de diffusion des séries télé qu'on suit, savoir où les regarder, et ne rien manquer.

> Ce README est mis à jour au fur et à mesure du développement. Il reflète l'état du projet à la date indiquée en fin de fichier, pas nécessairement l'état futur.

## Aperçu

| Accueil | Horaire | Mes séries |
|---|---|---|
| ![Accueil](Screenshots/tvQ-accueil.png) | ![Horaire](Screenshots/tvQ-horaire-dark-mode.png) | ![Mes séries](Screenshots/tvQ-mesSeries-dark-mode.jpeg) |

| Recherche | Fiche série (sombre) | Fiche série (clair) |
|---|---|---|
| ![Recherche](Screenshots/tvQ-recherche-dark-mode.jpeg) | ![Fiche série (sombre)](Screenshots/tvQ-serie-detail-dark-mode.png) | ![Fiche série (clair)](Screenshots/tvQ-serie-detail.png) |

## Stack technique

- **UI** : SwiftUI, `@Observable`
- **Auth** : Firebase Auth (Sign in with Apple)
- **Cache partagé** : Firestore (séries et épisodes communs à tous les utilisateurs) et liste des séries suivies par utilisateur
- **Persistance locale** : SwiftData
- **Données séries** : [TMDB](https://www.themoviedb.org/) (métadonnées, épisodes) et [TVmaze](https://www.tvmaze.com/) (horaires précis)
- **Où regarder** : [JustWatch](https://www.justwatch.com/) (via TMDB `watch/providers`)
- **Concurrence** : `async/await`, actors (`@ModelActor`), `TaskGroup`
- **Tests** : Swift Testing

## Architecture

MVVM léger, pensé pour une app développée en solo : pas de couche Domain séparée, pas de protocoles ajoutés par principe. Le flux va toujours dans le même sens :

```
Views  →  ViewModels  →  Repositories  →  Services  (TMDB, TVmaze, Firebase)
                                       →  Stores    (SwiftData)
```

- **Views / ViewModels** : l'affichage et l'état des écrans. Les ViewModels ne connaissent que les repositories.
- **Repositories** (`ShowRepository`, `ScheduleRepository`) : décident *quand* utiliser le cache ou le réseau, en composant Services et Stores. C'est le seul endroit qui connaît à la fois TMDB et TVmaze.
- **Services** : un par système externe (`TMDBService`, `TVmazeService`, `AuthService`, `UserShowsService`, caches Firestore). Ils ne retournent que des DTO ou des modèles, sans logique de cache. `NetworkService` factorise la mécanique HTTP (statut, décodage, classement des erreurs).
- **Stores** : persistance locale SwiftData (`ShowStore`, `EpisodeStore`, `WatchAvailabilityStore`), qui retournent des modèles et jamais d'entités SwiftData.
- **Models** : `Show`, `Episode`, `ShowSummary`, `WatchAvailability`, `AppUser`.

## Installation

Prérequis : Xcode 27, iOS 26.5 (cible de déploiement actuelle).

1. Cloner le repo et ouvrir `tvQ.xcodeproj`. Les dépendances SPM (Firebase, etc.) se résolvent automatiquement au premier build.
2. Copier `Config/Secrets.xcconfig.template` en `Config/Secrets.xcconfig` et y renseigner une clé [TMDB](https://www.themoviedb.org/settings/api) (gratuite).
3. Ajouter un `GoogleService-Info.plist` (config Firebase) dans le dossier `tvQ/`. Il est nécessaire pour Sign in with Apple et le cache Firestore partagé.
4. Build & run sur simulateur ou appareil.

Ces fichiers sont volontairement exclus du repo (`.gitignore`) : chaque environnement (dev, démo, prod) a les siens.

## État des fonctionnalités

### Fait

- Horaire "À venir" servi par un cache à deux niveaux (SwiftData local, puis Firestore partagé, puis TMDB et TVmaze)
- Fiche série (`ShowDetailView`) avec liste des épisodes et "Où regarder"
- Suivi et retrait de séries, résolution en parallèle des séries suivies
- Sign in with Apple
- "Où regarder" par pays (CA/US/FR/GB) via TMDB + JustWatch, avec fusion des doublons de catalogue (ex. Disney Plus/Disney+)
- Logo et identité visuelle de base

### Pas commencé / en réflexion

- Look de l'app (couleurs, typographie, ambiance générale) : pas encore défini
- Page "Tendances" (séries les plus suivies) : demande une agrégation des follows, design à faire
- Déverrouillage biométrique automatique (Face ID au lancement)
- Rafraîchissement à chaud de la langue de contenu TMDB (il faut relancer l'app après un changement dans Settings)
- Mise à jour visible d'un écran quand une donnée est rafraîchie en arrière-plan (elle n'apparaît qu'à la prochaine ouverture)

Le détail (raisonnement, dates, décisions) est dans `BACKLOG.md`. Attention : ses entrées historiques utilisent les anciens noms de la structure d'avant la refonte (`RemoteScheduleRepository`, `LocalEpisodeCache`, etc.).

## Quelques décisions techniques

- **Cache à deux niveaux avec stale-while-revalidate** : la copie locale (SwiftData) est lue d'abord. Si elle est périmée, elle est retournée quand même et rafraîchie en arrière-plan, ce qui évite un écran vide quand le réseau est lent ou absent. Sans copie locale, on lit Firestore (partagé entre utilisateurs), puis TMDB et TVmaze. Les durées de validité sont définies à un seul endroit (`CachePolicy`) et une série terminée (`.ended`) ne périme jamais.
- **Date de synchronisation conservée** quand une copie Firestore est recopiée en local : une donnée déjà vieille ne redevient pas "fraîche".
- **Requêtes en vol partagées** : si deux écrans demandent la même série en même temps, un seul appel réseau est fait.
- **Horaire par requête sur la date** : l'écran Schedule vérifie que chaque série est présente en local, puis lit les épisodes récents et à venir en une seule requête SwiftData, au lieu de charger tout l'historique de chaque série.
- **Clé de cache avec la langue** : la copie Firestore est commune à tous les utilisateurs et le contenu est localisé, donc la clé inclut la langue effective.
- **Architecture allégée** : abandon d'une Clean Architecture complète (couches Domain/Data/Presentation, protocoles pour chaque repository), jugée disproportionnée pour une app solo. Le vocabulaire est simple : Service pour parler à un système externe, Store pour le disque, Repository pour orchestrer.
- **Résolution en parallèle (`TaskGroup`)** pour charger les séries suivies : un des premiers goulots d'étranglement (plusieurs secondes à l'ouverture) venait d'une boucle séquentielle.
- **Fusion des doublons de catalogue JustWatch** : JustWatch liste parfois la même offre sous deux noms légèrement différents (Disney Plus/Disney+, Netflix avec pub). Une table d'alias les fusionne sans fusionner des offres réellement distinctes (ex. achat vs abonnement Apple TV).

## Tests

Swift Testing, avec une base SwiftData en mémoire (aucune écriture sur disque) :

- `LocalStoresTests` : aller-retour, remplacement et vidage des stores, requête des épisodes à venir (filtre par date et par série, tri), deux langues sans collision.
- `CachePolicyTests` : règles de fraîcheur, dont les séries terminées.

Pas encore testés : les repositories (les services sont des types concrets, donc non injectables), `NetworkService` et les mappers.

## Structure du projet

```
tvQ/
├── tvQ/
│   ├── App/            Point d'entrée et navigation racine
│   ├── Core/           Réglages, clés d'API, diagnostic de performance du Schedule
│   ├── Debug/          Outils de développement
│   ├── Models/         Show, Episode, ShowSummary, WatchAvailability, AppUser
│   ├── Repositories/   ShowRepository, ScheduleRepository, CachePolicy
│   ├── Services/       TMDB/, TVmaze/, Firebase/, Mappers/, NetworkService
│   ├── Stores/         SwiftData (entités, stores, LocalDatabase) et ImageCache
│   ├── ViewModels/
│   ├── Views/
│   └── Assets.xcassets/
├── tvQTests/
├── tvQUITests/
└── Config/             Clés (exclues du repo) et modèle de configuration
```

---
*Dernière mise à jour : 2026-09-20*
