import SwiftUI

struct SettingsView: View {
    @Environment(AuthViewModel.self) private var authViewModel

    @AppStorage(AppSettings.Keys.appearance)
    private var appearance: String = AppAppearance.system.rawValue

    @AppStorage(AppSettings.Keys.contentLanguage)
    private var contentLanguage: String = ContentLanguage.english.rawValue

    @AppStorage(AppSettings.Keys.useOriginalLanguage)
    private var useOriginalLanguage: Bool = false

    @AppStorage(AppSettings.Keys.watchProviderRegion)
    private var watchProviderRegion: String = WatchProviderRegion.canada.rawValue

    var body: some View {
        Form {
            Section("Appearance") {
                Picker("Appearance", selection: $appearance) {
                    ForEach(AppAppearance.allCases) { option in
                        Text(option.displayName).tag(option.rawValue)
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
                    authViewModel.signOut()
                }
            }
        }
        .navigationTitle("Settings")
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
    .environment(AuthViewModel())
}
