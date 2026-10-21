import SwiftUI

/// Settings › Episode Alerts : Live Activities, notifications, moment et heure du matin.
struct EpisodeAlertsSettingsView: View {
    @AppStorage(AppSettings.Keys.notificationsEnabled)
    private var notificationsEnabled = false

    @AppStorage(AppSettings.Keys.notificationTiming)
    private var notificationTiming: NotificationTiming = .atAirTime

    @AppStorage(AppSettings.Keys.notificationMorningMinutes)
    private var morningMinutes = AppSettings.defaultMorningMinutes

    @Environment(\.openURL) private var openURL
    private let notificationScheduler = NotificationScheduler.shared

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
    var body: some View {
        Form {
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
        .navigationTitle("Episode Alerts")
        .navigationBarTitleDisplayMode(.inline)
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

}
