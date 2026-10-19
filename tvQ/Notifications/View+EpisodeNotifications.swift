import SwiftUI

/// Garde les notifications et les Live Activities programmées en phase avec
/// l'horaire : se relance quand les épisodes, les séries coupées, les réglages ou
/// les permissions iOS changent, et au retour au premier plan.
///
/// Les Live Activities (épisodes à heure exacte, ce soir) passent en premier :
/// leurs épisodes n'ont alors pas de notification « commence » en double.
private struct EpisodeNotificationsModifier: ViewModifier {
    @Environment(FollowedShowsStore.self) private var followedShowsStore
    @Environment(ScheduleViewModel.self) private var scheduleViewModel
    @Environment(\.scenePhase) private var scenePhase

    @AppStorage(AppSettings.Keys.notificationsEnabled) private var isEnabled = false
    @AppStorage(AppSettings.Keys.notificationTiming) private var timing: NotificationTiming = .atAirTime
    @AppStorage(AppSettings.Keys.notificationMorningMinutes)
    private var morningMinutes = AppSettings.defaultMorningMinutes
    @AppStorage(AppSettings.Keys.liveActivitiesEnabled) private var liveActivitiesEnabled = true

    private let scheduler = NotificationScheduler.shared
    private let liveActivityScheduler = LiveActivityScheduler.shared
    /// Rafraîchi au retour au premier plan : réglage modifiable dans iOS.
    @State private var activitiesAllowedBySystem = true
    /// Incrémenté à chaque retour au premier plan : relance le plan pour retirer
    /// les activités terminées et programmer celles de la journée qui vient.
    @State private var foregroundCount = 0

    private struct Inputs: Equatable {
        let items: [ScheduleViewModel.ScheduleItem]
        let muted: Set<String>
        let isEnabled: Bool
        let isAuthorized: Bool
        let timing: NotificationTiming
        let morningMinutes: Int
        let liveActivitiesOn: Bool
        let foregroundCount: Int
    }

    func body(content: Content) -> some View {
        content
            .task(id: Inputs(
                items: scheduleViewModel.items,
                muted: followedShowsStore.mutedShowIDs,
                isEnabled: isEnabled,
                isAuthorized: scheduler.isAuthorized,
                timing: timing,
                morningMinutes: morningMinutes,
                liveActivitiesOn: liveActivitiesEnabled && activitiesAllowedBySystem,
                foregroundCount: foregroundCount
            )) {
                let items = scheduleViewModel.items.map { NotificationPlanner.Item(episode: $0.episode, show: $0.show) }
                let now = Date.now

                // Horaire pas encore chargé au lancement : ne pas retirer pour rien
                // une activité en cours (la reprogrammer referait apparaître l'alerte).
                let scheduleIsLoaded = !items.isEmpty || followedShowsStore.followedShowIDs.isEmpty
                var liveActivities: [PlannedLiveActivity] = []
                if liveActivitiesEnabled && activitiesAllowedBySystem {
                    liveActivities = LiveActivityPlanner(morningMinutes: morningMinutes)
                        .plan(items: items, mutedShowIDs: followedShowsStore.mutedShowIDs, now: now)
                    if scheduleIsLoaded {
                        await liveActivityScheduler.apply(liveActivities, now: now)
                    }
                } else {
                    await liveActivityScheduler.endAll()
                }

                guard isEnabled, scheduler.isAuthorized else {
                    await scheduler.removeAll()
                    return
                }
                let planner = NotificationPlanner(timing: timing, morningMinutes: morningMinutes)
                let plan = planner.plan(
                    items: items,
                    mutedShowIDs: followedShowsStore.mutedShowIDs,
                    now: now,
                    liveActivityEpisodeIDs: Set(liveActivities.flatMap(\.coveredEpisodeIDs))
                )
                await scheduler.apply(plan)
            }
            .onChange(of: scenePhase, initial: true) { _, phase in
                if phase == .active {
                    activitiesAllowedBySystem = liveActivityScheduler.areActivitiesEnabled
                    foregroundCount += 1
                    Task { await scheduler.refreshAuthorizationStatus() }
                }
            }
    }
}

extension View {
    func schedulesEpisodeNotifications() -> some View {
        modifier(EpisodeNotificationsModifier())
    }
}
