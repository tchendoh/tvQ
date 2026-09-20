# Backlog technique — tvQ

Choses identifiées en cours de route, volontairement mises de côté pour rester fonctionnel rapidement. À revisiter, pas à ignorer.

## Performance

- ~~**Horaire "À venir" (`RemoteScheduleRepository.getUpcomingEpisodes`)**~~ — résolu le 2026-07-14 : cache à 3 paliers (local disque 6h → Firestore partagé entre utilisateurs 24h → TMDB/TVmaze), filtrage des séries `.ended`, récupération en parallèle (TaskGroup) plutôt que séquentielle. Voir `LocalEpisodeCache`, `FirestoreEpisodeCacheRepository`, `RemoteScheduleRepository`.

- ~~**`ShowDetailView` / `RemoteScheduleRepository.getEpisodes`**~~ — résolu par le même cache à 3 paliers ci-dessus (`getEpisodes` est le point d'entrée commun). De plus, pour les séries `.ended` (dont les épisodes ne changeront plus jamais), le TTL est désactivé (`maxAge: nil`) sur les deux paliers — une fois en cache, elles ne redéclenchent plus jamais d'appel réseau.

- ~~**`RemoteShowRepository.getShow` sans cache + résolution séquentielle**~~ — résolu le 2026-07-14 : c'était en fait le vrai goulot de l'écran Schedule (plusieurs secondes à l'ouverture), plus lourd que l'horaire lui-même. Cache à 3 paliers pour `Show` (`LocalShowCache`, `FirestoreShowCacheRepository`, même modèle que les épisodes, TTL infini une fois `.ended`), et résolution en parallèle (`TaskGroup`) dans `MyShowsViewModel.load` et `ScheduleViewModel.load` plutôt qu'en boucle séquentielle. Au passage, correction d'un bug latent : la clé de cache (épisodes et séries) n'incluait pas la langue de contenu (`AppSettings.cacheLanguageKey`) — deux utilisateurs avec des préférences de langue différentes auraient pu s'écraser mutuellement le cache Firestore partagé.

- ~~**`MyShowsViewModel.load(showIDs:)`**~~ — résolu le 2026-07-14 : se relançait en entier à chaque follow/unfollow, donc re-résolvait *toutes* les séries suivies plutôt que juste celle qui a changé. Bug de correction découvert au passage : si un seul appel du lot échouait, `shows` n'était jamais mis à jour — une série unfollow restait affichée même si elle avait bien disparu de `FollowedShowsStore`. Le retrait est maintenant local/immédiat (indépendant du réseau), et seuls les IDs manquants (nouveaux follows) sont résolus via le cache à 3 paliers.

- ~~**Horaire préchargé au lancement**~~ — résolu le 2026-09-20 : un `TabView` n'évalue un onglet qu'à sa première apparition, donc le chargement de Schedule ne démarrait qu'à l'ouverture de l'onglet. Le `ScheduleViewModel` est maintenant créé dans `RootView` (injecté en environment) et le déclencheur `.task(id: followedShowIDs)` vit dans `MainTabView`. Sans nettoyage explicite à la déconnexion : voir « Divers ».
- **Gel au premier clic sur l'onglet Search (identifié le 2026-09-20)** — cause non confirmée. Pistes, de la plus probable à la moins probable : (1) première initialisation du clavier et de `.searchable`, connue pour figer dans le simulateur ou sous le débogueur (les messages « cannot add handler to 0 from 0 » de la console viennent du même sous-système); (2) ouverture synchrone de la base SwiftData sur le thread principal (`LocalDatabase.container`, initialisé au premier `ShowStore.shared`); (3) concurrence avec le préchargement de l'horaire. À trancher avec Instruments (Time Profiler ou Hangs) sur l'iPhone, en build Release et sans débogueur, avant de toucher au code.
- **`@State` qui recrée des dépendances lourdes (identifié le 2026-09-20)** — `@State private var viewModel = SearchViewModel()` (et les équivalents dans les autres vues) reconstruit un `ShowRepository`, un `TMDBService` et un `Firestore.firestore()` à chaque recréation de la vue par son parent. Coût faible, mais à éviter en créant les view models une seule fois (dans `RootView`, comme pour l'horaire) ou en les injectant.

## UX / fonctionnalités pas commencées

- **Look de l'app à définir** — l'UI actuelle est fonctionnelle mais aucune direction visuelle (couleurs, typographie, style d'icônes, ambiance générale) n'a encore été arrêtée. À faire avant de peaufiner l'UI existante ou d'en ajouter de nouvelle, pour éviter de refaire le travail deux fois.
- **Page "Tendances"** — afficher ce qui est suivi par le plus d'utilisateurs en ce moment (idée du 2026-07-14). Demande une agrégation des follows (compteur par série mis à jour à chaque follow/unfollow plutôt qu'un scan à la volée de toutes les sous-collections `followedShows`) — design à faire avant de commencer.
- **Déverrouillage biométrique automatique** (façon Tangerine) — Face ID qui redéverrouille la session au lancement sans aucun tap. Différent de Sign in with Apple (déjà fait) : ça suppose LocalAuthentication + Keychain, complètement séparé de Firebase. Pas commencé.
- **Rafraîchissement de la langue de contenu TMDB** — changer la langue dans Settings ne rafraîchit pas les écrans déjà chargés en mémoire (`TMDBClient.language` n'est lu qu'à la construction). Il faut relancer l'app. Mentionné dans le footer de `SettingsView`, pas résolu.
- ~~**"Où regarder" par pays**~~ — implémenté le 2026-07-15 : `TMDBClient.fetchWatchProviders` (`TMDBWatchProvidersDTO`), setting pays dans `SettingsView` (`WatchProviderRegion`, défaut Canada), `WatchAvailabilityMapper` (texte seulement, streaming avant achat/location, table `providerNameAliases` pour fusionner les doublons JustWatch de même catalogue — Netflix avec pub, Disney Plus/Disney+, HBO Max/Max — sans fusionner les cas où le catalogue diffère comme Apple TV magasin vs Apple TV+ abonnement), section inline dans `ShowDetailView` entre le lien IMDb et Episodes avec lien discret "via JustWatch" (CTA "Where to watch?" si aucun diffuseur trouvé pour le pays), attribution JustWatch ajoutée dans `AboutView.swift`. `LocalWatchAvailabilityCache` (cache local par appareil, TTL 24h aligné sur le rythme de sync JustWatch→TMDB) ajouté le 2026-07-15 pour éviter un appel TMDB à chaque réouverture de fiche — pas de palier Firestore partagé, la donnée dépend du pays choisi donc peu de réutilisation entre utilisateurs. Liste de pays volontairement courte (CA/US/FR/GB) — à élargir si des utilisateurs d'autres pays se manifestent.

- ~~**« Aujourd'hui » mal placé à la première arrivée sur Schedule**~~ — corrigé le 2026-09-20 : avec les données préchargées, le `scrollTo` se déclenchait avant que le `LazyVStack` ait mesuré les sections au-dessus (hauteurs estimées). `scrollToTodayAfterLayout` rejoue le défilement 250 ms plus tard. Solution de repli si ça persiste : remplacer le `LazyVStack` par un `VStack` (positions exactes, mais toutes les affiches se chargent d'un coup).
- ~~**Ligne entière cliquable dans Schedule**~~ — corrigé le 2026-09-20 : `.contentShape(Rectangle())` sur `ScheduleRow`, car avec `.buttonStyle(.plain)` seuls les pixels dessinés captaient le tap.
- **Animation de l'icône de suivi (`FollowIcon`)** — essayé le 2026-09-20 : `.contentTransition(.symbolEffect(.replace.magic(fallback: .downUp), options: .speed(1.2)))` en plus du `.bounce` existant. Le mode `magic` marche mieux entre symboles apparentés (`plus.viewfinder` et `checkmark.circle` se rabattent sur `.downUp`), donc envisager `plus.circle` et `checkmark.circle`. Si les deux effets se brouillent, retirer le `.bounce`. Idée non essayée : rotation 3D d'un tour complet avec un compteur, pour un effet plus marqué. À juger sur appareil.

## Firebase / infra

- **`followedShows` en sous-collection plutôt qu'un tableau (idée du 2026-07-15)** — `FirestoreUserShowsRepository.followedShowIDs` fait actuellement un `getDocuments()` sur `users/{userID}/followedShows/{showID}` (un document par série suivie), et Firestore facture une lecture par document retourné : suivre 25 séries coûte 25 lectures juste pour obtenir la liste des IDs, à chaque ouverture de Schedule/My Shows. Remplacer par un seul champ `followedShowIDs: [String]` sur `users/{userID}` ramènerait ça à 1 lecture peu importe le nombre de séries suivies (via `arrayUnion`/`arrayRemove` pour follow/unfollow). Gain estimé dans le pire cas (cache local 12h expiré) : ~75 lectures → ~51 lectures pour 25 séries suivies (25 pour les métadonnées + 25 pour les épisodes restent inchangées, seule la lecture de la liste passe de 25 à 1). Pas encore de vrais utilisateurs à migrer — bon moment pour le faire avant que ça devienne une migration de données réelle.
- **⚠️ Idée de monétisation : abonnement 1$/mois pour suivre plus de 50 séries (idée du 2026-07-15) — probablement bloquée par les conditions TMDB/JustWatch** — plafond gratuit à 50 séries suivies, déblocage illimité (jusqu'à un plafond absolu anti-abus, ~500, même pour les abonnés — éviter le cas "quelqu'un follow 4 millions de séries pour le fun") via StoreKit. Analyse de coût Firestore faite : le coût marginal d'un utilisateur dépassant 50 séries est négligeable (fractions de cent/mois), donc l'abonnement n'aurait pas besoin de "couvrir un coût" d'infra — 3 à 5 abonnés suffiraient largement à couvrir Firebase même à 2000 utilisateurs actifs/jour.
  
  **Mais conflit légal identifié le 2026-07-15, probablement rédhibitoire :** les conditions TMDB stipulent que monétiser l'app de quelque façon que ce soit (faire payer, ajouter de la pub, etc.) sort de la licence gratuite standard et exige un accord commercial — 149$/mois pour une entreprise sous 1M$ de revenu annuel — et ça semble s'appliquer à l'app entière, pas seulement à la fonctionnalité qui utilise directement TMDB. Ce montant écrase l'économie de 3-5 abonnés à 1$. Pire : l'API JustWatch (utilisée pour "Où regarder") interdit carrément tout usage commercial sans exception à prix fixe — la seule voie commerciale (JustWatch Media) est réservée à "de plus gros partenaires", probablement hors de portée pour une app individuelle. Un usage commercial sans accord constituerait une violation de leurs conditions respectives.
  
  **Implication :** monétiser tvQ sous une forme quelconque nécessiterait soit de négocier ces licences (peu réaliste à cette échelle), soit de retirer/remplacer TMDB et JustWatch par des sources de données permettant un usage commercial, soit d'abandonner l'idée et de garder l'app gratuite. À trancher avant d'aller plus loin sur cette piste. Pas commencé.
- **StoreKit 2 — ce que l'implémentation de l'abonnement demanderait concrètement** — (1) un produit d'abonnement configuré dans App Store Connect (nom, prix, groupe d'abonnement), pas faisable depuis le code, à faire manuellement dans le compte développeur Apple; (2) un `StoreKit Configuration file` local pour tester les achats dans le simulateur/Xcode sans vrai produit App Store Connect, en attendant; (3) le code d'achat/restauration via `Transaction` et `Product` de StoreKit 2 (pas l'ancien StoreKit 1 basé sur des delegates); (4) une vérification du statut d'abonnement (`Transaction.currentEntitlements`) côté app, mais aussi une vérification côté règles de sécurité Firestore avant d'accepter un `follow` au-delà de 50 — sinon un utilisateur pourrait contourner le plafond directement contre Firestore sans jamais passer par l'achat; (5) une décision sur ce qui arrive aux séries au-delà de 50 déjà suivies si l'abonnement expire ou est annulé (les délier automatiquement? les garder en lecture seule?); (6) Apple prend 15% (programme Small Business, probablement applicable vu le faible volume) à 30% de commission sur l'abonnement. Pas commencé.

- **Règles de sécurité Firestore** (voir la section « Avant TestFlight / App Store » plus bas pour la liste détaillée) — à revoir/durcir une fois qu'il y a plus de collections que juste `followedShows` (ex. si on ajoute des préférences utilisateur synchronisées, des favoris, etc.). Depuis le 2026-07-14, `showsCache` (cache d'épisodes partagé entre utilisateurs) a aussi lecture+écriture ouvertes à tout utilisateur authentifié — risque faible (contenu tiers, pas de donnée sensible), mais à revisiter avec une Cloud Function dédiée à l'écriture si l'app grossit.
- ~~**`Package.resolved`**~~ — confirmé le 2026-09-20 : le lockfile SPM est bien suivi par Git.
- **Crashlytics** — mis à jour le 2026-09-20 : le produit `FirebaseCrashlytics` est lié au projet, mais aucune phase de build « Run Script » n'envoie les dSYM (seul le script TMDB existe) et le format de débogage en Debug est `dwarf`. Sans envoi des dSYM, les rapports de plantage restent illisibles (adresses non symbolisées). À faire avant TestFlight : ajouter la phase d'envoi des dSYM (`upload-symbols`), puis provoquer un plantage de test pour confirmer que le rapport arrive dans la console Firebase.

## Avant TestFlight / App Store

Ce qui doit être réglé avant de distribuer l'app à des amis, puis au public. Rien ci-dessous n'est commencé, sauf mention contraire.

### Règles de sécurité Firestore

Contexte : `GoogleService-Info.plist` est embarqué dans l'app, donc n'importe qui peut interroger le projet Firebase. Seules les règles de sécurité protègent les données.

- [ ] **Vérifier les règles actuellement publiées** dans la console Firebase (Firestore Database > Rules). Repérer surtout toute règle du genre `allow read, write: if true` ou en mode test (qui expire après 30 jours et bloque alors tout).
- [ ] **Versionner les règles dans le dépôt** : créer `firestore.rules` (et `firebase.json`) à la racine pour qu'elles soient sous Git, et les déployer avec la CLI (`firebase deploy --only firestore:rules`) plutôt que de les éditer à la main dans la console.
- [ ] **Données utilisateur** : `users/{userID}/followedShows/{showID}` doit être lisible et modifiable seulement par son propriétaire (`request.auth != null && request.auth.uid == userID`). Vérifier que la règle couvre aussi la suppression, nécessaire à la suppression de compte (`UserShowsService.deleteAllData`, qui supprime la sous-collection puis `users/{userID}`).
- [ ] **Caches partagés** : `showMetadataCache/{cacheKey}` et `showsCache/{cacheKey}` sont lus et écrits par tous les utilisateurs authentifiés. Restreindre l'écriture : exiger `request.auth != null`, limiter la taille des documents, valider la forme des champs (`syncedAt` de type timestamp, présence de `show` ou `episodes`). Risque restant à accepter ou à régler : un utilisateur malveillant pourrait y écrire de fausses données qui s'afficheraient chez les autres. La vraie solution serait d'écrire ces caches seulement depuis une Cloud Function.
- [ ] **Tout le reste refusé par défaut** : terminer par `match /{document=**} { allow read, write: if false; }`.
- [ ] **Tester les règles** avec l'émulateur Firestore ou l'outil « Rules Playground » de la console : un utilisateur A ne doit pas pouvoir lire ni écrire les données d'un utilisateur B, et un visiteur non connecté ne doit rien pouvoir faire.
- [ ] **Firebase App Check** (App Attest sur iOS) : limite l'accès à Firestore aux vraies installations de tvQ, en plus des règles. À activer en mode « moniteur » d'abord, puis en mode application des règles une fois que les builds TestFlight sont validés.
- [ ] **Quotas et budget** : configurer une alerte de facturation dans Google Cloud pour éviter une mauvaise surprise si quelqu'un abuse des lectures (voir aussi l'idée `followedShows` en tableau plus haut).

### Jeton TMDB embarqué dans l'app

Contexte : `Config/Secrets.xcconfig` alimente `Config/Secrets.generated.swift`, qui est compilé dans le binaire. Les deux fichiers sont bien ignorés par Git, mais le jeton reste extractable de l'app distribuée (chaînes de caractères du binaire, ou trafic réseau observé). C'est un jeton d'accès en lecture seule (`api_read`), donc le risque est limité à un usage abusif de votre quota TMDB, pas à une fuite de données.

- [ ] **Vérifier l'historique Git** : confirmer que le jeton n'a jamais été commité (`git log --all -p -- Config/Secrets.generated.swift Config/Secrets.xcconfig`). S'il l'a été, le régénérer dans le compte TMDB.
- [ ] **Décider du niveau de risque acceptable** :
  - Pour TestFlight entre amis : garder le jeton dans l'app est raisonnable.
  - Pour l'App Store : préférer un petit proxy qui détient le jeton et relaie les requêtes TMDB (Cloud Function Firebase, ou Cloudflare Worker gratuit), avec limitation de débit par utilisateur et vérification App Check. L'app appelle alors le proxy, sans jamais voir le jeton. À vérifier : les Cloud Functions qui appellent une API externe exigent le forfait Firebase Blaze (facturation à l'usage, avec un palier gratuit).
- [ ] **Préparer une rotation rapide** : savoir régénérer le jeton dans le compte TMDB en cas d'abus, et documenter ici les étapes (nouveau jeton dans `Secrets.xcconfig`, nouveau build, nouvelle soumission). Sans proxy, les anciennes versions installées cessent de fonctionner au moment de la rotation.
- [ ] **Surveiller l'usage** : consulter le tableau de bord de l'API TMDB de temps en temps pendant la phase TestFlight pour détecter un volume anormal.
- [ ] **Rappel des conditions d'utilisation** : l'app doit rester gratuite et sans publicité (voir l'analyse de monétisation plus haut), et l'attribution TMDB/JustWatch doit rester visible dans `AboutView`.

### Icône de l'app

- [x] Réglé le 2026-09-20 : les PNG exportés d'Icon Composer avaient les coins arrondis et un biseau clair cuits dans l'image, ce qui donnait un liseré blanc pixellisé autour de l'icône. Règle à retenir : ne jamais exporter de PNG d'Icon Composer pour un asset catalog; enregistrer le fichier `.icon` et le glisser directement dans le projet Xcode (le champ App Icon de la cible et `ASSETCATALOG_COMPILER_APPICON_NAME` doivent porter son nom, actuellement `tvQ-icon`).
- [ ] Vérifier le rendu sur l'appareil en clair, sombre et teinté (désinstaller l'app avant de réinstaller, iOS met les icônes en cache).

### Étapes TestFlight

- [x] Abonnement au programme Apple Developer actif.
- [ ] Bundle ID définitif, identique à celui enregistré dans Firebase (`GoogleService-Info.plist`); numéros de version et de build.
- [ ] Créer la fiche de l'app dans App Store Connect (My Apps > New App).
- [ ] Archiver (Product > Archive, destination Any iOS Device) puis envoyer via l'Organizer.
- [ ] Testeurs internes d'abord (jusqu'à 100, sans examen Apple), puis testeurs externes (examen bêta d'Apple, description à tester, courriel de contact, informations de connexion ou explication de Sign in with Apple).
- [ ] Prévoir la politique de confidentialité (URL publique) et les réponses « App Privacy » (compte, identifiants, données d'usage via Firebase) pour la soumission à l'App Store.
- [ ] Tester sur des appareils et des versions d'iOS variés, pas seulement l'iPhone 11.
- [ ] Les builds TestFlight expirent après 90 jours.

### Suppression de compte (exigence App Store)

- [x] Implémentée : `DeleteAccountView` (accessible depuis Settings), `AuthViewModel.deleteAccount`, `AuthService` (re-authentification, révocation du jeton Apple, suppression du compte Auth) et `UserShowsService.deleteAllData`. Compte email : re-saisie du mot de passe. Compte Apple : re-authentification via le bouton Sign in with Apple, puis révocation du jeton.
- [ ] **À tester sur appareil** avec un compte email et un compte Apple, y compris la re-authentification. Vérifier dans la console Firebase que le compte Auth et le document `users/{userID}` (avec sa sous-collection) ont bien disparu.
- [ ] **Ajouter les traductions françaises** des nouvelles chaînes dans `Localizable.xcstrings` (Delete Account, messages de confirmation et d'erreur).
- [ ] **Compte non anonyme après suppression** : vérifier qu'un même courriel peut se réinscrire proprement, et que Sign in with Apple recrée un compte neuf.

## Nettoyage (revue du 2026-09-20)

Retailles trouvées en parcourant le projet. Rien de bloquant.

- [ ] **Style Lab** : retirer `Debug/TagStyleLabView.swift` (une dizaine de types `Lab...`) et la section « Style Lab » de `SettingsView`, marquée TEMPORAIRE. Le style « glass » a été choisi le 2026-08-09. Sinon, l'envelopper dans `#if DEBUG` pour qu'elle ne parte pas dans les builds TestFlight.
- [ ] **Tests de gabarit Xcode** : `tvQTests.swift`, `tvQUITests.swift` et `tvQUITestsLaunchTests.swift` sont des squelettes générés. Les vrais tests sont `CachePolicyTests` et `LocalStoresTests`.
- [ ] **`ContentView.swift`** : simple enveloppe autour de `RootView`, encore instanciée par `tvQApp`. Vérifier si elle sert à quelque chose, sinon lancer `RootView` directement.
- [ ] **`AccentColor`** : la couleur n'est référencée nulle part dans le code (utilisée implicitement par `Color.accentColor` et le réglage de build, donc ne pas la supprimer sans vérifier).
- [ ] **`.claude/`** : dossier non suivi par Git; l'ajouter au `.gitignore` ou le commiter.
- [ ] **`build/`** : 2,3 Go, ignoré par Git. Peut être supprimé pour récupérer de l'espace, Xcode le recrée.
- [ ] **Jeton TMDB** : confirmé le 2026-09-20 que `Config/Secrets.generated.swift` est ignoré par Git; reste à vérifier l'historique (voir « Avant TestFlight »).

## Divers

- **Nettoyage de l'horaire à la déconnexion (identifié le 2026-09-20)** — le `ScheduleViewModel` vit maintenant dans `RootView`, donc à la déconnexion `items` n'est pas vidé explicitement. Un autre compte qui se connecte juste après pourrait voir brièvement l'horaire précédent, jusqu'à ce que `FollowedShowsStore` publie les nouveaux IDs. Corriger en vidant le view model à la déconnexion ou en le recréant avec `.id(user.id)`. À vérifier aussi : `FollowedShowsStore.clear()` existe mais rien ne semble l'appeler à la déconnexion ou à la suppression de compte.
- **Git** — plusieurs sessions de travail avec des changements non commités qui s'accumulent (`.gitignore`, `project.pbxproj`, et tout `Core/`, `Data/`, `Domain/`, `Presentation/` à un moment donné). Prendre une pause propre pour committer par lots logiques plutôt qu'un seul gros commit. Mis à jour le 2026-09-20 : 17 fichiers modifiés ou non suivis (préchargement de l'horaire, scroll d'Aujourd'hui, ligne cliquable, animation de l'icône, suppression de compte, nouvelle icône, `BACKLOG.md`); proposition de lots : icône, horaire (préchargement, scroll, clic), suppression de compte, backlog.
