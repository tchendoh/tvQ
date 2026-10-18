#if DEBUG
import SwiftUI

/// Debug seulement : les notifications que tvQ a programmées dans iOS, pour vérifier
/// le plan (heures, séries coupées, réglage du moment) sans attendre un soir de
/// diffusion. Textes en dur, non traduits : jamais visible dans une build Release.
struct NotificationsDebugView: View {
    @Environment(FollowedShowsStore.self) private var followedShowsStore: FollowedShowsStore?
    @Environment(\.scenePhase) private var scenePhase
    private let scheduler = NotificationScheduler.shared

    @State private var pending: [NotificationScheduler.PendingInfo] = []
    @State private var lastRefresh = Date.now

    var body: some View {
        List {
            Section {
                LabeledContent(verbatim("iOS permission"), value: permissionText)
                LabeledContent(verbatim("Scheduled"), value: "\(pending.count) / 64")
                LabeledContent(verbatim("Muted shows"), value: "\(followedShowsStore?.mutedShowIDs.count ?? 0)")
            } footer: {
                Text(verbatim: "Updated \(lastRefresh.formatted(date: .omitted, time: .standard)). iOS keeps at most 64 pending notifications per app.")
            }

            Section {
                Button(verbatim("Test notification in 10 s")) {
                    let tmdbID = followedShowsStore?.followedShowIDs.compactMap(Int.init).first
                    Task {
                        await scheduler.scheduleTestNotification(
                            tmdbID: tmdbID,
                            title: tmdbID.map { "tvQ test: show \($0)" } ?? "tvQ test"
                        )
                        await reload()
                    }
                }
            } footer: {
                Text(verbatim: "Go to the Home Screen (⇧⌘H in the simulator) to see the banner, then tap it: the show page should open.")
            }

            Section {
                if pending.isEmpty {
                    Text(verbatim: "Nothing scheduled. Check that notifications are on and that followed shows have episodes in the coming weeks.")
                        .foregroundStyle(.secondary)
                }
                ForEach(pending) { item in
                    row(item)
                }
            } header: {
                Text(verbatim: "Pending")
            }
        }
        .navigationTitle(Text(verbatim: "Notifications (debug)"))
        .refreshable { await reload() }
        .task { await reload() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await reload() } }
        }
    }

    private func row(_ item: NotificationScheduler.PendingInfo) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(verbatim: item.fireDate.map(Self.format) ?? "?")
                    .font(.subheadline.monospacedDigit().weight(.semibold))
                Spacer()
                Text(verbatim: item.isExact ? "exact" : "floating")
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(item.isExact ? Color.blue.opacity(0.2) : Color.orange.opacity(0.2), in: Capsule())
            }
            Text(verbatim: item.title)
                .font(.body)
            if !item.body.isEmpty {
                Text(verbatim: item.body)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(verbatim: item.id + (item.tmdbID.map { "  ·  tmdb \($0)" } ?? ""))
                .font(.caption2.monospaced())
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 2)
    }

    private func reload() async {
        await scheduler.refreshAuthorizationStatus()
        pending = await scheduler.pendingInfo()
        lastRefresh = .now
    }

    private var permissionText: String {
        switch scheduler.authorizationStatus {
        case .authorized: "authorized"
        case .provisional: "provisional"
        case .denied: "denied"
        case .ephemeral: "ephemeral"
        case .notDetermined: "not asked yet"
        @unknown default: "unknown"
        }
    }

    private static func format(_ date: Date) -> String {
        date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated).hour().minute())
    }

    private func verbatim(_ string: String) -> String { string }
}
#endif
