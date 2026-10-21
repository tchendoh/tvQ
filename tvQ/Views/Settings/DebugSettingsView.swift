import SwiftUI

#if DEBUG
/// Settings › Debug : outils de développement, absents en Release (textes non traduits).
struct DebugSettingsView: View {
    @State private var didClearCache = false

    var body: some View {
        Form {
            debugSection
        }
        .navigationTitle(Text(verbatim: "Debug"))
        .navigationBarTitleDisplayMode(.inline)
    }

    /// Outils de développement, regroupés au bas de Settings et absents en Release
    /// (textes non traduits).
    private var debugSection: some View {
        Section {
            NavigationLink(verbatimLabel("Scheduled notifications")) {
                NotificationsDebugView(kind: .notifications)
            }
            NavigationLink(verbatimLabel("Live Activities")) {
                NotificationsDebugView(kind: .liveActivities)
            }
            NavigationLink(verbatimLabel("Style Lab")) {
                StyleLabView()
            }
            // Copie locale uniquement : le cache Firestore partagé reste intact, pour
            // ne pas effacer les données des autres utilisateurs. Sert à retester le
            // chargement à froid (FollowedShowsStore.prefetchContent) sans désinstaller.
            Button(verbatimLabel("Clear local cache")) {
                clearLocalCache()
            }
            // Test de la chaîne Crashlytics (plantage, envoi, dSYM, rapport lisible).
            // Lancer l'app SANS le débogueur, appuyer, puis rouvrir l'app pour envoyer
            // le rapport. Pour un rapport lisible, tester en Release (le dSYM est vide
            // en Debug à cause de ENABLE_DEBUG_DYLIB) en retirant temporairement le
            // #if DEBUG.
            Button(verbatimLabel("Test Crashlytics"), role: .destructive) {
                fatalError("Test Crashlytics")
            }
        } header: {
            Text(verbatim: "Debug")
        } footer: {
            Text(verbatim: didClearCache
                 ? "Local cache cleared."
                 : "Debug builds only. Clear local cache forces shows and episodes to reload from scratch; Test Crashlytics crashes the app on purpose.")
        }
    }

    private func verbatimLabel(_ string: String) -> String { string }

    private func clearLocalCache() {
        didClearCache = false
        Task {
            try? await ShowStore.shared.clear()
            try? await EpisodeStore.shared.clear()
            try? await WatchAvailabilityStore.shared.clear()
            await ImageCache.shared.clear()
            didClearCache = true
        }
    }
}
#endif
