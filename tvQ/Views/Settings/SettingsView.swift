import SwiftUI

struct SettingsView: View {
    @Environment(SessionStore.self) private var session

    @AppStorage(AppSettings.Keys.appearance)
    private var appearance: AppAppearance = .system

    @AppStorage(AppSettings.Keys.contentLanguage)
    private var contentLanguage: String = ContentLanguage.english.rawValue

    @AppStorage(AppSettings.Keys.useOriginalLanguage)
    private var useOriginalLanguage: Bool = false

    @AppStorage(AppSettings.Keys.watchProviderRegion)
    private var watchProviderRegion: String = WatchProviderRegion.canada.rawValue

    @AppStorage(AppSettings.Keys.notificationsEnabled)
    private var notificationsEnabled = false

    @AppStorage(AppSettings.Keys.notificationTiming)
    private var notificationTiming: NotificationTiming = .atAirTime

    @AppStorage(AppSettings.Keys.notificationMorningMinutes)
    private var morningMinutes = AppSettings.defaultMorningMinutes

    @Environment(\.openURL) private var openURL
    private let notificationScheduler = NotificationScheduler.shared

    @State private var didClearCache = false
    @State private var isPresentingDeleteAccount = false
    @State private var signOutFailed = false

    var body: some View {
        Form {
            if let user = session.currentUser {
                Section {
                    Text(user.displayName ?? user.email)
                }
            }

            Section("Appearance") {
                Picker("Appearance", selection: $appearance) {
                    ForEach(AppAppearance.allCases) { option in
                        Text(option.displayName).tag(option)
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()
            }

            Section {
                Picker("Show & episode language", selection: $contentLanguage) {
                    ForEach(ContentLanguage.allCases) { option in
                        Text(option.displayName).tag(option.rawValue)
                    }
                }
            } header: {
                Text("Content Language")
            } footer: {
                Text("Affects show titles, descriptions, and episode info from TMDB.")
            }

            Section {
                Toggle("Prefer show's original language", isOn: $useOriginalLanguage)
            } footer: {
                Text("When on, a show's page and episodes use its original language instead of the setting above. Search results are unaffected.")
            }

            Section {
                Picker("Country", selection: $watchProviderRegion) {
                    ForEach(WatchProviderRegion.allCases) { option in
                        Text(option.displayName).tag(option.rawValue)
                    }
                }
            } header: {
                Text("Where to Watch")
            } footer: {
                Text("Used to show which services carry a show in your country.")
            }

            episodeAlertsSection

            Section {
                NavigationLink("About") {
                    AboutView()
                }
            }

            Section {
                Button("Sign Out", role: .destructive) {
                    do {
                        try session.signOut()
                    } catch {
                        signOutFailed = true
                    }
                }
            }

            Section {
                Button("Delete Account", role: .destructive) {
                    isPresentingDeleteAccount = true
                }
            } footer: {
                Text("Permanently deletes your account and the shows you follow.")
            }

            #if DEBUG
            debugSection
            #endif
        }
        .navigationTitle("Settings")
        .sheet(isPresented: $isPresentingDeleteAccount) {
            if let user = session.currentUser {
                DeleteAccountView(userID: user.id)
            }
        }
        .alert("Sign out failed.", isPresented: $signOutFailed) {
            Button("OK", role: .cancel) {}
        }
    }

    // MARK: - Notifications

    /// Permission refusée dans iOS : tvQ ne peut pas la redemander, seulement
    /// envoyer vers les Réglages.
    private var isDeniedBySystem: Bool {
        notificationScheduler.authorizationStatus == .denied
    }

    @AppStorage(AppSettings.Keys.liveActivitiesEnabled)
    private var liveActivitiesEnabled = true

    /// Live Activities refusées pour tvQ dans les Réglages d'iOS.
    private var liveActivitiesDeniedBySystem: Bool {
        !LiveActivityScheduler.shared.areActivitiesEnabled
    }

    // MARK: - Alertes d'épisodes

    /// Live Activities et notifications dans une même section : l'ordre dit la
    /// priorité (un épisode à heure exacte, en soirée, a un compte à rebours plutôt
    /// qu'une notification), et la phrase sous chaque interrupteur dit qui fait quoi.
    @ViewBuilder
    private var episodeAlertsSection: some View {
        Section {
            Toggle(isOn: Binding(
                get: { liveActivitiesEnabled && !liveActivitiesDeniedBySystem },
                set: { liveActivitiesEnabled = $0 }
            )) {
                SettingLabel(
                    title: Text("Live Activities"),
                    detail: liveActivitiesDeniedBySystem
                        ? Text("Turned off in iOS Settings.")
                        : Text("Live countdown on the Lock Screen, 15 min before episodes with an exact time.")
                )
            }
            .disabled(liveActivitiesDeniedBySystem)

            Toggle(isOn: Binding(
                get: { notificationsEnabled && !isDeniedBySystem },
                set: { isOn in
                    guard isOn else {
                        notificationsEnabled = false
                        return
                    }
                    Task {
                        notificationsEnabled = await notificationScheduler.requestAuthorization()
                    }
                }
            )) {
                SettingLabel(title: Text("Notifications"), detail: notificationsDetail)
            }
            .disabled(isDeniedBySystem)

            // Réglages propres aux notifications, sous leur interrupteur.
            if notificationsEnabled && !isDeniedBySystem {
                Picker("Timing", selection: $notificationTiming) {
                    Text("10 min before").tag(NotificationTiming.tenMinutesBefore)
                    Text("At air time").tag(NotificationTiming.atAirTime)
                    Text("10 min after it ends").tag(NotificationTiming.tenMinutesAfterEnd)
                }
                DatePicker("Morning time", selection: morningTime, displayedComponents: .hourAndMinute)
            }

            if isDeniedBySystem || liveActivitiesDeniedBySystem {
                Button("Open iOS Settings") {
                    let address = isDeniedBySystem
                        ? UIApplication.openNotificationSettingsURLString
                        : UIApplication.openSettingsURLString
                    if let url = URL(string: address) {
                        openURL(url)
                    }
                }
            }
        } header: {
            Text("Episode Alerts")
        } footer: {
            Text("Episodes without a known time, and those released overnight, are announced at the morning time. Use the bell in Schedule to mute a show.")
        }
    }

    /// Avec les Live Activities, les notifications couvrent le reste ; sans elles, tout.
    private var notificationsDetail: Text {
        if isDeniedBySystem {
            Text("Turned off in iOS Settings.")
        } else if liveActivitiesEnabled && !liveActivitiesDeniedBySystem {
            Text("For all other episodes.")
        } else {
            Text("For all episodes.")
        }
    }

    // MARK: - Débogage

    #if DEBUG
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
    #endif

    /// L'heure du matin est stockée en minutes depuis minuit ; DatePicker veut une Date.
    private var morningTime: Binding<Date> {
        Binding(
            get: {
                Calendar.current.date(
                    bySettingHour: morningMinutes / 60, minute: morningMinutes % 60, second: 0, of: .now
                ) ?? .now
            },
            set: { date in
                let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
                morningMinutes = (parts.hour ?? 9) * 60 + (parts.minute ?? 0)
            }
        )
    }

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

#Preview {
    NavigationStack {
        SettingsView()
    }
    .environment(SessionStore())
}

/// Titre d'un réglage avec une phrase grise en dessous, comme dans les Réglages d'iOS.
private struct SettingLabel: View {
    let title: Text
    let detail: Text

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            title
            detail
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }
}
