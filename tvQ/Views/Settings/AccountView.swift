import SwiftUI

/// Feuille Account, ouverte par l'avatar de la barre d'outils (accountToolbarItem) :
/// l'identité en tête, puis une ligne par réglage avec sa valeur actuelle à droite.
/// Le détail vit dans les sous-pages (EpisodeAlertsSettingsView,
/// ContentLanguageSettingsView, AccountSettingsView, AboutView, DebugSettingsView).
struct AccountView: View {
    @Environment(SessionStore.self) private var session
    @Environment(\.dismiss) private var dismiss

    @AppStorage(AppSettings.Keys.contentLanguage)
    private var contentLanguage: String = ContentLanguage.english.rawValue

    @AppStorage(AppSettings.Keys.useOriginalLanguage)
    private var useOriginalLanguage: Bool = false

    @AppStorage(AppSettings.Keys.notificationsEnabled)
    private var notificationsEnabled = false

    @AppStorage(AppSettings.Keys.notificationTiming)
    private var notificationTiming: NotificationTiming = .atAirTime

    @AppStorage(AppSettings.Keys.liveActivitiesEnabled)
    private var liveActivitiesEnabled = true

    private let notificationScheduler = NotificationScheduler.shared

    @State private var isPresentingLogin = false
    @State private var isPresentingEraseData = false

    var body: some View {
        Form {
            accountSection

            Section {
                NavigationLink {
                    EpisodeAlertsSettingsView()
                } label: {
                    SettingsRow(
                        title: "Episode Alerts",
                        systemImage: "bell.badge.fill",
                        color: .red,
                        value: alertsSummary.text,
                        valueColor: alertsSummary.isProblem ? .orange : .secondary
                    )
                }

                NavigationLink {
                    ContentLanguageSettingsView()
                } label: {
                    SettingsRow(
                        title: "Content Language",
                        systemImage: "globe",
                        color: .blue,
                        value: languageSummary
                    )
                }
            }

            Section {
                NavigationLink {
                    AboutView()
                } label: {
                    SettingsRow(title: "About", systemImage: "info", color: .gray)
                }
            }

            #if DEBUG
            Section {
                NavigationLink {
                    DebugSettingsView()
                } label: {
                    Label {
                        Text(verbatim: "Debug")
                    } icon: {
                        SettingsIcon(systemImage: "ladybug.fill", color: .green)
                    }
                }
            }
            #endif
        }
        .navigationTitle("Account")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(role: .close) { dismiss() }
            }
        }
        .sheet(isPresented: $isPresentingLogin) {
            LoginView()
        }
        .sheet(isPresented: $isPresentingEraseData) {
            if let user = session.currentUser {
                DeleteAccountView(userID: user.id)
            }
        }
    }

    // MARK: - Compte

    /// Vrai compte : carte qui mène à Account. Session anonyme : invitation à créer
    /// un compte (ouvre LoginView) et, à part, l'effacement des données.
    @ViewBuilder
    private var accountSection: some View {
        let user = session.currentUser
        if let user, !user.isAnonymous {
            Section {
                NavigationLink {
                    AccountSettingsView()
                } label: {
                    accountCard(
                        user: user,
                        title: Text(user.displayName ?? user.email),
                        subtitle: user.displayName == nil ? Text("Account Details") : Text(user.email)
                    )
                }
            }
        } else {
            Section {
                Button {
                    isPresentingLogin = true
                } label: {
                    accountCard(
                        user: user,
                        title: Text("Create an Account"),
                        subtitle: Text("Keep your shows if you reinstall tvQ or change phones.")
                    )
                }
                .foregroundStyle(.primary)
            } footer: {
                Button("Erase My Data") {
                    isPresentingEraseData = true
                }
                .font(.footnote)
                .tint(.red)
            }
        }
    }

    private func accountCard(user: AppUser?, title: Text, subtitle: Text) -> some View {
        HStack(spacing: 14) {
            AccountAvatar(user: user)
            VStack(alignment: .leading, spacing: 2) {
                title
                    .font(.title3.weight(.semibold))
                    .lineLimit(1)
                subtitle
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 6)
    }

    // MARK: - Valeurs résumées

    /// Ce que les alertes font réellement, compte tenu des refus dans iOS.
    private var alertsSummary: (text: Text, isProblem: Bool) {
        let notificationsDenied = notificationScheduler.authorizationStatus == .denied
        let liveActivitiesOn = liveActivitiesEnabled && LiveActivityScheduler.shared.areActivitiesEnabled
        let notificationsOn = notificationsEnabled && !notificationsDenied

        if notificationsEnabled && notificationsDenied {
            return (Text("Off in iOS"), true)
        }
        if notificationsOn {
            return (Text(notificationTiming.shortName), false)
        }
        return (liveActivitiesOn ? Text("Live Activities") : Text("Off"), false)
    }

    private var languageSummary: Text {
        let language = useOriginalLanguage
            ? Text("Original")
            : Text(ContentLanguage(rawValue: contentLanguage)?.displayName ?? "")
        return language
    }
}

private extension NotificationTiming {
    /// Libellé court pour la ligne Episode Alerts (mêmes clés que le Picker de la sous-page).
    var shortName: LocalizedStringKey {
        switch self {
        case .tenMinutesBefore: "10 min before"
        case .atAirTime: "At air time"
        case .tenMinutesAfterEnd: "10 min after it ends"
        }
    }
}

#Preview {
    NavigationStack {
        AccountView()
    }
    .environment(SessionStore())
}
