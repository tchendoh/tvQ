# tvQ

**Ne manquez plus aucun épisode.** tvQ affiche quand sortent les prochains épisodes des séries que vous suivez, à l'heure exacte de diffusion dans votre fuseau horaire, et où les regarder dans votre pays.

Une application iOS native, développée en solo en Swift 6 et SwiftUI.

*[English version](README.md)*

| Accueil | Horaire | Mes séries |
|---|---|---|
| ![Accueil](Screenshots/tvQ-accueil.png) | ![Horaire](Screenshots/tvQ-horaire-dark-mode.png) | ![Mes séries](Screenshots/tvQ-mesSeries-dark-mode.jpeg) |

| Recherche | Fiche série (sombre) | Fiche série (clair) |
|---|---|---|
| ![Recherche](Screenshots/tvQ-recherche-dark-mode.jpeg) | ![Fiche série, sombre](Screenshots/tvQ-serie-detail-dark-mode.png) | ![Fiche série, clair](Screenshots/tvQ-serie-detail.png) |

## Points forts

- **Concurrence stricte de Swift 6.** Compilée en mode Swift 6 : isolation au `MainActor` par défaut, SwiftData confiné dans des stores `@ModelActor`, et des modèles immuables `Sendable` qui circulent entre eux.
- **Un cache à trois niveaux avec stale-while-revalidate.** SwiftData en local d'abord, puis un cache Firestore partagé par tous les utilisateurs, puis les API de TMDB et de TVmaze. Une donnée périmée s'affiche aussitôt et se rafraîchit en arrière-plan : l'horaire n'attend jamais le réseau.
- **Deux API réunies en un seul horaire.** TMDB fournit le contenu (titres, synopsis, saisons, images) et TVmaze, l'heure de diffusion précise avec son fuseau horaire. Quand TVmaze n'a pas la série, l'app se rabat sur la date de TMDB sans inventer d'heure.
- **Où regarder, selon le pays.** Les offres en streaming, en location et à l'achat pour le Canada, les États-Unis, la France et le Royaume-Uni, avec la fusion des doublons de catalogue (Disney Plus et Disney+, Netflix avec pub).
- **Sign in with Apple et suppression de compte** conformes aux exigences de l'App Store, y compris la révocation du jeton Apple.
- **Bilingue** (français et anglais), pour l'interface comme pour le contenu des séries.

## Technologies

| | |
|---|---|
| Interface | SwiftUI, Observation (`@Observable`) |
| Langage | mode Swift 6, iOS 27.2 |
| Concurrence | `async`/`await`, actors, `@ModelActor`, groupes de tâches |
| Stockage local | SwiftData |
| Backend | Firebase Auth (Sign in with Apple, courriel), Cloud Firestore |
| Données | [TMDB](https://www.themoviedb.org/), [TVmaze](https://www.tvmaze.com/), [JustWatch](https://www.justwatch.com/) par TMDB |
| Tests | Swift Testing |

## Architecture

Un MVVM léger, à la mesure d'un projet en solo. Les données circulent toujours dans le même sens :

```
Views  →  ViewModels  →  Repositories  →  Services  (TMDB, TVmaze, Firebase)
                                       →  Stores    (SwiftData)
```

- **Les vues et les ViewModels** gèrent l'état des écrans. Les ViewModels ne connaissent que les repositories.
- **Les repositories** décident *quand* utiliser le cache ou le réseau. C'est la seule couche qui connaît à la fois TMDB et TVmaze, et une instance unique partagée permet à deux écrans qui demandent la même série de partager un seul appel réseau.
- **Les services** enveloppent chacun un système externe, sans aucune logique de cache.
- **Les stores** sont des actors autour de SwiftData. Ils retournent des modèles simples, jamais des entités SwiftData : rien de non `Sendable` n'en sort.

## Décisions techniques

- **Les règles de fraîcheur sont à un seul endroit** (`CachePolicy`). Une série terminée n'expire jamais, puisqu'elle n'aura plus de nouveaux épisodes.
- **Une copie du cache partagé garde sa date de synchronisation d'origine** quand elle est recopiée en local : une donnée ancienne ne redevient pas « fraîche » en changeant de place.
- **La clé de cache inclut la langue du contenu.** Le cache Firestore est commun à tous les utilisateurs et le contenu est traduit : deux utilisateurs de langues différentes ne peuvent pas écraser les données l'un de l'autre.
- **L'horaire est une seule requête par date.** Plutôt que de charger tous les épisodes de chaque série, l'app s'assure que chaque série est en cache local, puis lit les épisodes récents et à venir en une seule requête SwiftData.
- **`currentUser` a une source de vérité unique** : le flux d'authentification de Firebase. La connexion, la déconnexion et la suppression de compte mettent toute l'app à jour sans code supplémentaire.

## Ce que j'ai appris

- **Adapter l'architecture au projet.** J'ai commencé avec une Clean Architecture complète (couches Domain, Data et Presentation, un protocole par repository), puis je l'ai retirée : pour un seul développeur, elle ajoutait des intermédiaires sans ajouter de sécurité.
- **Mesurer avant d'optimiser.** La lenteur de l'écran Horaire ne venait pas de l'horaire lui-même, mais des séries résolues une à une. Les résoudre en parallèle a fait gagner plusieurs secondes au lancement.
- **Le passage au mode Swift 6 en valait la peine.** Le compilateur a trouvé de vrais problèmes : un jeton Firebase non `Sendable` qui traversait une frontière entre actors, et un `[weak self]` qui restait en fait une référence forte pendant toute la durée d'un flux.
- **Relire ses propres commentaires d'un œil critique.** Un commentaire promettait que deux écrans partageraient les requêtes en cours, alors que chaque écran avait sa propre instance de repository. Partager les repositories a réglé le problème.

## Tests

Swift Testing, avec une base SwiftData en mémoire :

- `LocalStoresTests` : aller-retour, remplacement et vidage des stores, requête des épisodes à venir (filtres par date et par série, ordre de tri), et deux langues sans collision.
- `CachePolicyTests` : les règles de fraîcheur, y compris pour les séries terminées.

## Installation

Prérequis : Xcode 27, iOS 27.2.

1. Cloner le dépôt et ouvrir `tvQ.xcodeproj`. Les dépendances Swift Package Manager (Firebase) se résolvent au premier build.
2. Copier `Config/Secrets.xcconfig.template` en `Config/Secrets.xcconfig` et y ajouter un jeton de débogage App Check (`uuidgen`).
3. Ajouter votre propre `GoogleService-Info.plist` de Firebase dans le dossier `tvQ/`, avec Sign in with Apple et Firestore activés.
4. Dans Firebase Remote Config, créer un paramètre de type chaîne `tmdb_token` contenant un jeton d'accès en lecture [TMDB](https://www.themoviedb.org/settings/api) (gratuit), puis publier. Le jeton n'est jamais compilé dans l'app : on peut le changer depuis la console sans nouveau build.
5. Compiler et lancer.

Ces deux fichiers sont volontairement exclus du dépôt.

## Prochaines étapes

- Une version bêta sur TestFlight
- Une page « Tendances » basée sur les séries les plus suivies par les utilisateurs de tvQ
- Le déverrouillage par Face ID au lancement

## Structure du projet

```
tvQ/
├── App/            Point d'entrée et navigation racine
├── Core/           Réglages et configuration des API
├── Models/         Show, Episode, ShowSummary, WatchAvailability, AppUser
├── Repositories/   ShowRepository, ScheduleRepository, CachePolicy
├── Services/       TMDB, TVmaze, Firebase, mappers, NetworkService
├── Stores/         Entités et stores SwiftData, cache d'images
├── ViewModels/
└── Views/
```

## Crédits

Données des séries fournies par [TMDB](https://www.themoviedb.org/) (ce produit utilise l'API de TMDB, mais n'est ni approuvé ni certifié par TMDB) et [TVmaze](https://www.tvmaze.com/). Disponibilité en streaming fournie par [JustWatch](https://www.justwatch.com/).
