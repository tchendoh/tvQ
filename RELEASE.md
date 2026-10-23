# Procédure de publication — tvQ

À suivre à chaque version, de haut en bas. Quand une étape cause un problème, ajouter ici la ligne qui l'aurait évité.

> Première version écrite le 2026-10-23, pendant la préparation du premier build TestFlight. Les étapes marquées *(à valider)* n'ont pas encore été faites une seule fois.

## 1. Avant de compiler

- [ ] Tout est commité et poussé ; `git status` est propre.
- [ ] Augmenter la version (`MARKETING_VERSION`, ex. 1.0 → 1.1) si c'est une nouvelle version publique ; sinon, seulement le numéro de build (`CURRENT_PROJECT_VERSION`). Chaque téléversement exige un numéro de build plus élevé que le précédent.
- [ ] Tests unitaires réussis (Product > Test).
- [ ] Si `firestore.rules` a changé : `npm test` dans `firestore-tests/`, puis `firebase deploy --only firestore:rules` **avant** de distribuer le build.
- [ ] Si un paquet SPM a été ajouté ou mis à jour : refaire `tvQ/Resources/Acknowledgements.json`.
- [ ] Si le code utilise une nouvelle API « required reason » (dates de fichiers, espace disque, temps depuis le démarrage, claviers) ou recueille une nouvelle donnée : mettre à jour `tvQ/Resources/PrivacyInfo.xcprivacy`, la politique (dépôt `tvq-site`) et App Store Connect > App Privacy.
- [ ] Essai rapide sur l'iPhone en Release : lancement, Schedule, suivre et ne plus suivre une série, fiche, notifications.

## 2. Archiver et téléverser *(à valider)*

- [ ] Destination « Any iOS Device (arm64) », puis Product > Archive.
- [ ] Organizer : clic droit sur l'archive > Generate Privacy Report (vérifier qu'il n'y a pas de surprise).
- [ ] Distribute App > App Store Connect > Upload.
- [ ] Vérifier que Crashlytics a reçu les dSYM (phase « Upload dSYM to Crashlytics »).

## 3. TestFlight *(à valider)*

- [ ] Attendre la fin du traitement du build dans App Store Connect (courriel d'Apple).
- [ ] Remplir « What to Test » (français et anglais).
- [ ] Testeurs internes : disponible tout de suite. Testeurs externes : Beta App Review au premier build d'une version.
- [ ] Laisser roder quelques jours ; surveiller Crashlytics.

## 4. App Store *(à valider)*

- [ ] Notes de version « What's New » en français (Canada) et en anglais.
- [ ] Captures d'écran à refaire si l'interface a beaucoup changé.
- [ ] Choisir le build, soumettre pour révision.
- [ ] Publication progressive (*phased release*) activée.

## 5. Après la publication

- [ ] Surveiller Crashlytics et Organizer > Launch Time pendant la première semaine.
- [ ] Étiqueter le commit : `git tag v1.0-12` (version-build) puis `git push --tags`.
- [ ] Mettre à jour `BACKLOG.md`.

## Liens

- Politique de confidentialité : https://tchendoh.github.io/tvq-site/privacy.html
- Soutien : https://tchendoh.github.io/tvq-site/ (`tvq.app.support@gmail.com`)
- Site : dépôt `tchendoh/tvq-site`, dans `~/iOS/tvq-site`
