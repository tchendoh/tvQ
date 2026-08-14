# tvQ

Application iOS (SwiftUI) pour suivre l'horaire de diffusion des séries télé qu'on suit, savoir où les regarder, et ne rien manquer.

> Ce README est mis à jour au fur et à mesure du développement — il reflète l'état du projet à la date indiquée en fin de fichier, pas nécessairement l'état futur.

## Aperçu

| Accueil | Horaire | Mes séries |
|---|---|---|
| ![Accueil](Screenshots/tvQ-accueil.png) | ![Horaire](Screenshots/tvQ-horaire-dark-mode.png) | ![Mes séries](Screenshots/tvQ-mesSeries-dark-mode.jpeg) |

| Recherche | Fiche série (sombre) | Fiche série (clair) |
|---|---|---|
| ![Recherche](Screenshots/tvQ-recherche-dark-mode.jpeg) | ![Fiche série (sombre)](Screenshots/tvQ-serie-detail-dark-mode.png) | ![Fiche série (clair)](Screenshots/tvQ-serie-detail.png) |

## Stack technique

- **UI** : SwiftUI
- **Auth** : Firebase Auth (Sign in with Apple)
- **Base de données** : Firestore (cache partagé séries/épisodes, liste des séries suivies)
- **Données séries** : [TMDB](https://www.themoviedb.org/) (métadonnées séries/épisodes)
- **Où regarder** : [JustWatch](https://www.justwatch.com/) (via TMDB `watch/providers`)
- **Architecture** : Clean Architecture — séparation en 4 couches :
  - `Domain/` — entités et cas d'usage, indépendants de toute techno
  - `Data/` — repositories, réseau (TMDB, Firestore), mappers, persistance locale
  - `Core/` — injection de dépendances, auth, réseau bas niveau, cache, settings, utilitaires
  - `Presentation/` — vues SwiftUI et view models

## Installation

Prérequis : Xcode 16+, iOS 26.5 (cible de déploiement actuelle).

1. Cloner le repo et ouvrir `tvQ.xcodeproj` — les dépendances SPM (Firebase, etc.) se résolvent automatiquement au premier build.
2. Copier `Config/Secrets.xcconfig.template` en `Config/Secrets.xcconfig` et y renseigner une clé [TMDB](https://www.themoviedb.org/settings/api) (gratuite).
3. Ajouter un `GoogleService-Info.plist` (config Firebase) dans `Config/` — nécessaire pour Sign in with Apple et le cache Firestore partagé. Sans ce fichier, l'app peut tourner en mode dégradé (cache local seulement) mais l'auth ne fonctionnera pas.
4. Build & run sur simulateur ou appareil.

Ces fichiers sont volontairement exclus du repo (`.gitignore`) — chaque environnement (dev, démo, prod) a les siens.

## État des fonctionnalités

### Fait

- Horaire "À venir" avec cache à 3 paliers (local disque → Firestore partagé → TMDB/TVmaze)
- Fiche série (`ShowDetailView`) avec liste des épisodes, même cache à 3 paliers
- Suivi/retrait de séries (follow/unfollow), résolution en parallèle des séries suivies
- Sign in with Apple
- "Où regarder" par pays (CA/US/FR/GB) via TMDB + JustWatch, avec fusion des doublons de catalogue (ex. Disney Plus/Disney+)
- Logo et identité visuelle de base

### Pas commencé / en réflexion

- Look de l'app (couleurs, typographie, ambiance générale) — pas encore défini
- Page "Tendances" (séries les plus suivies) — demande une agrégation des follows, design à faire
- Déverrouillage biométrique automatique (Face ID au lancement, façon Tangerine)
- Rafraîchissement à chaud de la langue de contenu TMDB (actuellement il faut relancer l'app après un changement dans Settings)

Le détail complet (raisonnement, dates, décisions techniques) est dans `BACKLOG.md`.

## Quelques décisions techniques

- **Cache à 3 paliers (local disque → Firestore partagé → API)** pour l'horaire et les fiches série : l'app affiche quasi instantanément du contenu déjà vu par n'importe quel utilisateur, plutôt que de refaire un appel TMDB à chaque ouverture. Le TTL est désactivé pour les séries terminées (`.ended`), puisque leurs épisodes ne changeront plus jamais.
- **Résolution en parallèle (`TaskGroup`)** plutôt que séquentielle pour charger les séries suivies — un des premiers goulots d'étranglement rencontrés (plusieurs secondes à l'ouverture de l'app) venait d'une boucle séquentielle sur chaque série suivie.
- **Fusion des doublons de catalogue JustWatch** ("Où regarder") : JustWatch liste parfois la même offre sous deux noms légèrement différents (Disney Plus/Disney+, Netflix avec pub) — une table d'alias les fusionne sans fusionner des offres réellement distinctes (ex. achat vs abonnement Apple TV).
- **Firebase + TMDB/JustWatch ne sont pas monétisables sans accord commercial séparé** — un des arbitrages produit rencontrés en cours de route (voir `BACKLOG.md`) : l'app reste gratuite pour cette raison, pas par choix initial.

Le raisonnement complet (avec dates et alternatives considérées) est documenté au fil de l'eau dans `BACKLOG.md`.

## Tests

Les cibles de test (`tvQTests`, `tvQUITests`) sont en place mais les tests eux-mêmes restent à écrire — pas encore fait à ce stade.

## Structure du projet

```
tvQ/
├── Core/            # DI, Auth, Networking, Caching, Settings, Extensions, Utilities
├── Data/             # Network, Repositories, Mappers, Persistence
├── Domain/           # Entities, Repositories (protocoles), UseCases
├── Presentation/      # Views, ViewModels
├── Config/
└── Assets.xcassets/
```

---
*Dernière mise à jour : 2026-07-20*
