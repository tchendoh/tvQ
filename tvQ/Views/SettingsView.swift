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

    @State private var didClearCache = false
    @State private var showingDeleteAccount = false
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
                Text("Affects show titles, descriptions, and episode info from TMDB. Restart the app for already-loaded screens to refresh.")
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
                    showingDeleteAccount = true
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
        }
        .navigationTitle("Settings")
        .sheet(isPresented: $showingDeleteAccount) {
            if let user = session.currentUser {
                DeleteAccountView(userID: user.id)
            }
        }
        .alert("Sign out failed.", isPresented: $signOutFailed) {
            Button("OK", role: .cancel) {}
        }
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
