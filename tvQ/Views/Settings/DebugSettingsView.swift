import SwiftUI

#if DEBUG
/// Settings › Debug : outils de développement, absents en Release (textes non traduits).
struct DebugSettingsView: View {
    @State private var didClearCache = false
    @AppStorage(AppSettings.Keys.tabHaptic)
    private var tabHaptic: TabHaptic = AppRules.Haptics.tabDefault
    @AppStorage(AppSettings.Keys.tabHapticIntensity)
    private var tabHapticIntensity = AppRules.Haptics.tabDefaultIntensity
    @State private var hapticTestTick = 0

    var body: some View {
        Form {
            debugSection
            hapticsSection
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
            NavigationLink(verbatimLabel("Trends")) {
                TrendsDebugView()
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

    /// Vibration au changement d'onglet : type, intensité et essai sur place.
    private var hapticsSection: some View {
        Section {
            Picker(selection: $tabHaptic) {
                ForEach(TabHaptic.allCases) { haptic in
                    Text(verbatim: haptic.label).tag(haptic)
                }
            } label: {
                Text(verbatim: "Tab switch")
            }
            if tabHaptic.supportsIntensity {
                LabeledContent {
                    Slider(value: $tabHapticIntensity, in: 0.1...1, step: 0.1)
                } label: {
                    Text(verbatim: "Intensity \(tabHapticIntensity.formatted(.number.precision(.fractionLength(1))))")
                }
            }
            Button(verbatimLabel("Try it")) {
                hapticTestTick += 1
            }
            .disabled(tabHaptic == .off)
            .sensoryFeedback(trigger: hapticTestTick) { _, _ in
                tabHaptic.feedback(intensity: tabHapticIntensity)
            }
            Button(verbatimLabel("Reset to default")) {
                tabHaptic = AppRules.Haptics.tabDefault
                tabHapticIntensity = AppRules.Haptics.tabDefaultIntensity
            }
        } header: {
            Text(verbatim: "Haptics")
        } footer: {
            Text(verbatim: "Played on every tab change and when a second tap on Schedule returns to Today. Other builds use AppRules.Haptics. Silent in the simulator.")
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
