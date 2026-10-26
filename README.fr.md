# tvQ

**Ne manquez plus aucun épisode.** tvQ affiche quand sortent les prochains épisodes des séries que vous suivez, à l'heure exacte de diffusion dans votre fuseau horaire, et où les regarder dans votre pays.

Une application iOS native, développée en solo en Swift 6 et SwiftUI.

*[English version](README.md)*

| Accueil | Horaire | Mes séries |
|---|---|---|
| <img src="https://tchendoh.github.io/tvq-site/screenshots/home-fr.png" alt="Accueil" width="250"> | <img src="https://tchendoh.github.io/tvq-site/screenshots/schedule-fr.png" alt="Horaire" width="250"> | <img src="https://tchendoh.github.io/tvq-site/screenshots/my-shows-fr.png" alt="Mes séries" width="250"> |

| Recherche | Fiche série (sombre) | Fiche série (clair) |
|---|---|---|
| <img src="https://tchendoh.github.io/tvq-site/screenshots/search-fr.png" alt="Recherche" width="250"> | <img src="https://tchendoh.github.io/tvq-site/screenshots/show-detail-fr-dark.png" alt="Fiche série, sombre" width="250"> | <img src="https://tchendoh.github.io/tvq-site/screenshots/show-detail-fr-light.png" alt="Fiche série, clair" width="250"> |

## Points forts

- **Concurrence stricte de Swift 6.** Compilée en mode Swift 6 : isolation au `MainActor` par défaut, SwiftData confiné dans des stores `@ModelActor`, et des modèles immuables `Sendable` qui circulent entre eux.
- **Un cache à trois niveaux avec stale-while-revalidate.** SwiftData en local d'abord, puis un cache Firestore partagé par tous les utilisateurs, puis les API de TMDB et de TVmaze. Une donnée périmée s'affiche aussitôt et se rafraîchit en arrière-plan : l'horaire n'attend jamais le réseau.
- **Deux API réunies en un seul horaire.** TMDB fournit le contenu (titres, synopsis, saisons, images) et TVmaze, l'heure de diffusion précise avec son fuseau horaire. Quand TVmaze n'a pas la série, l'app se rabat sur la date de TMDB sans inventer d'heure.
- **Aucune connexion obligatoire.** L'app s'ouvre sur une session anonyme Firebase : on peut suivre des séries tout de suite. Créer un compte plus tard (Sign in with Apple ou courriel) relie cette session, sans perdre aucune série suivie.
- **Où regarder, selon le pays.** Inclus dans un abonnement, gratuit, ou en location et à l'achat, pour le pays de l'appareil par défaut ou tout autre pays choisi depuis la fiche, avec la fusion des doublons de catalogue (Disney Plus et Disney+, Netflix avec pub).
- **Des notifications de nouveaux épisodes, sans serveur.** Des notifications locales programmées à partir de l'horaire en cache : à l'heure exacte de diffusion quand TVmaze la connaît (un instant fixe, juste dans n'importe quel fuseau), sinon à une heure du matin choisie. Avant le début, au début ou après la fin de chaque épisode selon sa durée, avec une cloche pour couper n'importe quelle série. Une notification reportée au matin dit pourquoi (« disponible depuis cette nuit », « diffusé hier soir ») au lieu d'annoncer un nouvel épisode avec des heures de retard.
- **Des Live Activities les soirs de diffusion.** Une extension affiche un compte à rebours sur l'écran verrouillé et dans la Dynamic Island, aux couleurs de la série, démarré à l'avance grâce aux démarrages programmés d'iOS 26. Elle remplace la notification « commence » pour ces épisodes.
- **Aucune clé d'API dans le binaire.** Le jeton TMDB vient de Firebase Remote Config et peut être changé depuis la console sans nouveau build : un jeton refusé (401) déclenche aussitôt une nouvelle récupération et un nouvel essai, au plus une fois par minute. Firestore est verrouillé par des règles de sécurité testées dans l'émulateur, et App Check limite l'accès aux vraies installations.
- **Sign in with Apple et suppression de compte** conformes aux exigences de l'App Store, y compris la révocation du jeton Apple.
- **Prête pour l'iPhone Duo.** Barre d'onglets adaptative (`.sidebarAdaptable`), barres d'outils qui passent à la barre verticale en paysage, et un avatar de compte qui ouvre une feuille avec une transition zoom, comme dans les apps d'Apple.
- **Bilingue** (français et anglais), pour l'interface comme pour le contenu des séries.

## Technologies

| | |
|---|---|
| Interface | SwiftUI, Observation (`@Observable`) |
| Langage | mode Swift 6, iOS 26.0 |
| Concurrence | `async`/`await`, actors, `@ModelActor`, groupes de tâches |
| Stockage local | SwiftData |
| Backend | Firebase Auth (anonyme, Sign in with Apple, courriel), Cloud Firestore, Remote Config, App Check, Crashlytics |
| Notifications | UserNotifications (locales), ActivityKit (Live Activities) |
| Données | [TMDB](https://www.themoviedb.org/), [TVmaze](https://www.tvmaze.com/), [JustWatch](https://www.justwatch.com/) par TMDB |
| Tests | Swift Testing, émulateur Firebase (règles de sécurité), XCTest (temps de lancement) |

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

Les protocoles n'apparaissent que là où ils sont utiles : à la frontière avec les systèmes externes (TMDB, TVmaze, Firestore, Remote Config), pour que les tests puissent injecter des doublures. Le code de l'app utilise toujours les vraies implémentations par défaut.

## Décisions techniques

- **Les règles de fraîcheur sont à un seul endroit** (`CachePolicy`). Une série terminée n'expire jamais, puisqu'elle n'aura plus de nouveaux épisodes.
- **Une copie du cache partagé garde sa date de synchronisation d'origine** quand elle est recopiée en local : une donnée ancienne ne redevient pas « fraîche » en changeant de place.
- **La clé de cache inclut la langue du contenu.** Le cache Firestore est commun à tous les utilisateurs et le contenu est traduit : deux utilisateurs de langues différentes ne peuvent pas écraser les données l'un de l'autre.
- **L'horaire est une seule requête par date.** Plutôt que de charger tous les épisodes de chaque série, l'app s'assure que chaque série est en cache local, puis lit les épisodes récents et à venir en une seule requête SwiftData.
- **Seules les trois dernières saisons sont mises en cache.** L'horaire et les notifications n'ont besoin que de la saison en cours ; les plus anciennes se chargent à la demande, quand on les ouvre dans la fiche. Une quotidienne de plusieurs centaines d'épisodes ne coûte plus des centaines de lignes.
- **Les notifications sont d'abord un plan, puis appliquées.** `NotificationPlanner` transforme les épisodes en une liste de notifications, sans effet de bord (et entièrement testé) ; un mince `NotificationScheduler` remplace celles qui sont en attente. Des identifiants stables rendent la reprogrammation idempotente, et le plan reste sous la limite de 64 notifications d'iOS.
- **La permission est demandée en contexte**, après le suivi d'une première série, jamais au lancement.
- **`currentUser` a une source de vérité unique** : le flux d'authentification de Firebase. La connexion, la déconnexion et la suppression de compte mettent toute l'app à jour sans code supplémentaire.
- **Les séries suivies se lisent d'abord en local.** Un écouteur Firestore répond depuis le cache hors ligne au lancement, au lieu d'attendre le serveur, et reçoit aussi les changements faits depuis un autre appareil.
- **Les alertes d'épisodes suivent la série, pas l'appareil.** Les séries coupées sont gardées dans le document de l'utilisateur, à côté des séries suivies, sans lecture de plus.

## Règles de l'app

Tous les seuils, limites et durées dont l'app dépend sont dans un seul fichier, [`tvQ/Core/AppRules.swift`](tvQ/Core/AppRules.swift), chacun avec la raison de son choix. Les types qui les appliquent n'en gardent qu'un alias. Les plafonds côté serveur sont dans [`firestore.rules`](firestore.rules).

## Tests

Des tests unitaires en Swift Testing, sans aucun accès au réseau : de vrais stores SwiftData en mémoire, des doublures pour TMDB, TVmaze et Firestore, et un `URLProtocol` factice pour la couche réseau.

- **Mappers et décodage** : la fusion de TMDB et de TVmaze (heure précise plutôt que date seule, priorité du statut de la série), le dédoublonnage des diffuseurs, et le décodage de toutes les formes de réponse des API, valeurs `null` comprises.
- **Repositories** : toute la cascade du cache (copie fraîche, périmée, partagée, série terminée), le dédoublonnage des requêtes simultanées, un échec d'écriture Firestore qui ne fait pas échouer la requête, la jointure et le tri des saisons.
- **Notifications et Live Activities** : heures exactes et flottantes, sorties de nuit déplacées au matin avec le bon message, replis pour la durée, séries coupées, limite de 64 notifications, choix des épisodes qui ont une Live Activity.
- **Session et compte** : session anonyme, connexion, liaison et suppression de compte.
- **Séries suivies** : les mises à jour optimistes annulées en cas d'échec, et aucune donnée d'un ancien compte après une déconnexion pendant le chargement.
- **Jeton TMDB** : premier lancement, lancement hors ligne, appels simultanés qui partagent un seul chargement, changement de jeton pendant que l'app tourne, limitation des récupérations.
- **Couche réseau** : le classement des erreurs (hors ligne, code HTTP, décodage, annulation).

Les règles de sécurité Firestore ont leurs propres tests dans `firestore-tests/` (émulateur Firebase, `npm test`) : un utilisateur ne peut jamais lire ni écrire les données d'un autre.

## Installation

Prérequis : Xcode 27, iOS 26.0.

1. Cloner le dépôt et ouvrir `tvQ.xcodeproj`. Les dépendances Swift Package Manager (Firebase) se résolvent au premier build.
2. Copier `Config/Secrets.xcconfig.template` en `Config/Secrets.xcconfig` et y ajouter un jeton de débogage App Check (`uuidgen`).
3. Ajouter votre propre `GoogleService-Info.plist` de Firebase dans le dossier `tvQ/`, avec l'authentification anonyme, Sign in with Apple et Firestore activés.
4. Dans Firebase Remote Config, créer un paramètre de type chaîne `tmdb_token` contenant un jeton d'accès en lecture [TMDB](https://www.themoviedb.org/settings/api) (gratuit), puis publier. Le jeton n'est jamais compilé dans l'app : on peut le changer depuis la console sans nouveau build.
5. Compiler et lancer.

Ces deux fichiers sont volontairement exclus du dépôt.

## Structure du projet

```
tvQ/
├── App/            Point d'entrée et navigation racine
├── Core/           Règles de l'app, réglages, journalisation, réseau, jeton TMDB (Remote Config)
├── Models/         Modèles du domaine (séries, épisodes, utilisateurs)
├── Notifications/  Planification des notifications et des Live Activities
├── Repositories/   Choix entre le cache et le réseau
├── Services/       TMDB, TVmaze, Firebase, mappers
├── Stores/         Entités et stores SwiftData, cache d'images
└── Views/          Écrans et leurs ViewModels
tvQActivity/        Extension de widget des Live Activities
Shared/             Code partagé par l'app et l'extension
tvQTests/           Tests unitaires (Swift Testing)
firestore-tests/    Tests des règles de sécurité Firestore (émulateur)
trends/             Script des tendances (Node, firebase-admin), sur un serveur maison
```

## Crédits

Données des séries fournies par [TMDB](https://www.themoviedb.org/) (ce produit utilise l'API de TMDB, mais n'est ni approuvé ni certifié par TMDB) et [TVmaze](https://www.tvmaze.com/). Disponibilité en streaming fournie par [JustWatch](https://www.justwatch.com/).

## Licence

Le code source est offert sous [licence MIT](LICENSE). Le nom, le logo et l'icône de tvQ n'en font pas partie, et les logos et données de tiers restent soumis aux conditions de leurs propriétaires.
