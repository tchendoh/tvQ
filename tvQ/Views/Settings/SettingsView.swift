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

            notificationsSection

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

            // Copie locale uniquement — le cache Firestore partagé reste intact,
            // pour ne pas effacer les données des autres utilisateurs. Utile pour
            // retester le chemin de chargement à froid (voir
            // FollowedShowsStore.prefetchContent) sans désinstaller l'app.
            Section {
                Button("Clear local cache") {
                    clearLocalCache()
                }
            } footer: {
                if didClearCache {
                    Text("Local cache cleared.")
                } else {
                    Text("Forces shows and episodes to reload from scratch on next view. Useful for testing.")
                }
            }

            // Test de la chaîne Crashlytics (plantage → envoi → dSYM → rapport lisible).
            // Lancer l'app SANS le débogueur, appuyer, puis rouvrir l'app pour envoyer
            // le rapport. Pour un rapport lisible, tester en Release (le dSYM est vide
            // en Debug à cause de ENABLE_DEBUG_DYLIB) en retirant temporairement le
            // #if DEBUG. Absent des builds Release tel quel.
            #if DEBUG
            Section {
                Button("Test Crashlytics", role: .destructive) {
                    fatalError("Test Crashlytics")
                }
            } footer: {
                Text("Debug only. Crashes the app on purpose to test crash reporting.")
            }
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

    @ViewBuilder
    private var notificationsSection: some View {
        Section {
            Toggle("New episodes", isOn: Binding(
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
            ))
            .disabled(isDeniedBySystem)

            if notificationsEnabled && !isDeniedBySystem {
                Picker("Timing", selection: $notificationTiming) {
                    Text("10 min before").tag(NotificationTiming.tenMinutesBefore)
                    Text("At air time").tag(NotificationTiming.atAirTime)
                    Text("10 min after it ends").tag(NotificationTiming.tenMinutesAfterEnd)
                }
                DatePicker("Morning time", selection: morningTime, displayedComponents: .hourAndMinute)
            }

            #if DEBUG
            // Toujours visible en Debug, même notifications désactivées : la page
            // montre justement la permission et l'absence de notifications.
            debugNotificationButtons
            #endif

            if isDeniedBySystem {
                Button("Open iOS Settings") {
                    if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
                        openURL(url)
                    }
                }
            }
        } header: {
            Text("Notifications")
        } footer: {
            if isDeniedBySystem {
                Text("Notifications are turned off for tvQ in iOS Settings.")
            } else {
                Text("Episodes without a known time, and those released overnight, are announced at the morning time. Use the bell in Schedule to mute a show.")
            }
        }
    }

    #if DEBUG
    /// Page de débogage des notifications (Debug seulement, textes non traduits).
    private var debugNotificationButtons: some View {
        let label: String = "Scheduled notifications (debug)"
        return NavigationLink(label) {
            NotificationsDebugView()
        }
    }
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
