import SwiftUI

/// Garde les notifications programmées en phase avec l'horaire : se relance quand
/// les épisodes, les séries coupées, les réglages ou la permission iOS changent,
/// et au retour au premier plan (permission retirée dans les Réglages d'iOS).
private struct EpisodeNotificationsModifier: ViewModifier {
    @Environment(FollowedShowsStore.self) private var followedShowsStore
    @Environment(ScheduleViewModel.self) private var scheduleViewModel
    @Environment(\.scenePhase) private var scenePhase

    @AppStorage(AppSettings.Keys.notificationsEnabled) private var isEnabled = false
    @AppStorage(AppSettings.Keys.notificationTiming) private var timing: NotificationTiming = .atAirTime
    @AppStorage(AppSettings.Keys.notificationMorningMinutes)
    private var morningMinutes = AppSettings.defaultMorningMinutes

    private let scheduler = NotificationScheduler.shared

    private struct Inputs: Equatable {
        let items: [ScheduleViewModel.ScheduleItem]
        let muted: Set<String>
        let isEnabled: Bool
        let isAuthorized: Bool
        let timing: NotificationTiming
        let morningMinutes: Int
    }

    func body(content: Content) -> some View {
        content
            .task(id: Inputs(
                items: scheduleViewModel.items,
                muted: followedShowsStore.mutedShowIDs,
                isEnabled: isEnabled,
                isAuthorized: scheduler.isAuthorized,
                timing: timing,
                morningMinutes: morningMinutes
            )) {
                guard isEnabled, scheduler.isAuthorized else {
                    await scheduler.removeAll()
                    return
                }
                let planner = NotificationPlanner(timing: timing, morningMinutes: morningMinutes)
                let plan = planner.plan(
                    items: scheduleViewModel.items.map { .init(episode: $0.episode, show: $0.show) },
                    mutedShowIDs: followedShowsStore.mutedShowIDs,
                    now: .now
                )
                await scheduler.apply(plan)
            }
            .onChange(of: scenePhase, initial: true) { _, phase in
                if phase == .active {
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
