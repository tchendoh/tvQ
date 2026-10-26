import SwiftUI

/// Settings › Content Language : langue des titres, résumés et épisodes (TMDB).
/// Le pays des diffuseurs se choisit dans la fiche d'une série (ShowDetailView).
struct ContentLanguageSettingsView: View {
    @AppStorage(AppSettings.Keys.contentLanguage)
    private var contentLanguage: String = ContentLanguage.interfaceDefault.rawValue

    @AppStorage(AppSettings.Keys.useOriginalLanguage)
    private var useOriginalLanguage: Bool = false

    var body: some View {
        Form {
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
        }
        .navigationTitle("Content Language")
        .navigationBarTitleDisplayMode(.inline)
    }
}
