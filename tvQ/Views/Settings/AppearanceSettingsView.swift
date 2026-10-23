import SwiftUI

/// Settings › Appearance : suivre iOS, ou forcer le mode clair ou sombre pour tvQ
/// seulement. Appliqué par RootView (preferredColorScheme).
struct AppearanceSettingsView: View {
    @AppStorage(AppSettings.Keys.appearance)
    private var appearance: AppAppearance = .system

    var body: some View {
        Form {
            Section {
                Picker("Appearance", selection: $appearance) {
                    ForEach(AppAppearance.allCases) { option in
                        Text(option.displayName).tag(option)
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()
            } footer: {
                Text("System follows your iPhone's setting.")
            }
        }
        .navigationTitle("Appearance")
        .navigationBarTitleDisplayMode(.inline)
    }
}
