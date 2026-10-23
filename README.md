# tvQ

**Never miss an episode.** tvQ shows when the next episodes of the series you follow air, down to the exact local time, and where to watch them in your country.

A native iOS app built solo in Swift 6 and SwiftUI.

*[Version française](README.fr.md)*

| Home | Schedule | My Shows |
|---|---|---|
| ![Home](https://tchendoh.github.io/tvq-site/screenshots/home-en.png) | ![Schedule](https://tchendoh.github.io/tvq-site/screenshots/schedule-en.png) | ![My Shows](https://tchendoh.github.io/tvq-site/screenshots/my-shows-en.png) |

| Search | Show detail (dark) | Show detail (light) |
|---|---|---|
| ![Search](https://tchendoh.github.io/tvq-site/screenshots/search-fr-dark.jpeg) | ![Show detail, dark](https://tchendoh.github.io/tvq-site/screenshots/show-detail-en-dark.png) | ![Show detail, light](https://tchendoh.github.io/tvq-site/screenshots/show-detail-en-light.png) |

## Highlights

- **Swift 6 strict concurrency.** Compiled in Swift 6 language mode: main actor isolation by default, SwiftData confined to `@ModelActor` stores, immutable `Sendable` models crossing between them.
- **Three-tier cache with stale-while-revalidate.** Local SwiftData first, then a Firestore cache shared by all users, then the TMDB and TVmaze APIs. Stale data is shown instantly and refreshed in the background, so the schedule never waits on the network.
- **Two APIs merged into one schedule.** TMDB provides the content (titles, synopses, seasons, artwork); TVmaze provides the precise air time with its time zone. When TVmaze has no match, the app falls back to TMDB's date without inventing an hour.
- **No sign-in required.** The app opens on an anonymous Firebase session, so you can follow shows right away. Creating an account later (Sign in with Apple or email) links that session, keeping every followed show.
- **Where to watch, per country.** Included with a subscription, free, or to rent or buy, for the device's country by default or any other one chosen from the show page, with duplicate catalog entries merged (Disney Plus and Disney+, Netflix with ads).
- **New-episode notifications, without a server.** Local notifications scheduled from the cached schedule: at the exact air time when TVmaze knows it (a fixed instant, correct in any time zone), otherwise at a chosen morning hour. Before, at, or after the end of each episode based on its runtime, with a bell to mute any show. A notification moved to the morning says why ("out since last night", "aired last night") instead of announcing a new episode hours late.
- **Live Activities on air nights.** A widget extension shows a countdown on the Lock Screen and in the Dynamic Island, tinted with the show's colors, started ahead of time with iOS 26 scheduled starts. It replaces the "starts now" notification for those episodes.
- **No API key in the binary.** The TMDB token comes from Firebase Remote Config and can be rotated from the console without a new build: a rejected token (401) triggers an immediate refetch and a retry, at most once a minute. Firestore is locked down by security rules tested against the emulator, and App Check restricts access to genuine installs.
- **Sign in with Apple and account deletion** that meet App Store requirements, including Apple token revocation.
- **Ready for iPhone Duo.** Adaptive tab bar (`.sidebarAdaptable`), toolbars that move to the vertical bar in landscape, and an account avatar that opens a sheet with a zoom transition, as in Apple's own apps.
- **Bilingual** (English and French), for both the interface and the show content.

## Tech stack

| | |
|---|---|
| UI | SwiftUI, Observation (`@Observable`) |
| Language | Swift 6 language mode, iOS 27.0 |
| Concurrency | `async`/`await`, actors, `@ModelActor`, task groups |
| Local storage | SwiftData |
| Backend | Firebase Auth (anonymous, Sign in with Apple, email), Cloud Firestore, Remote Config, App Check, Crashlytics |
| Notifications | UserNotifications (local), ActivityKit (Live Activities) |
| Data | [TMDB](https://www.themoviedb.org/), [TVmaze](https://www.tvmaze.com/), [JustWatch](https://www.justwatch.com/) via TMDB |
| Tests | Swift Testing, Firebase emulator (security rules), XCTest (launch time) |

## Architecture

Lightweight MVVM, sized for a solo project. Data always flows in one direction:

```
Views  →  ViewModels  →  Repositories  →  Services  (TMDB, TVmaze, Firebase)
                                       →  Stores    (SwiftData)
```

- **Views and ViewModels** hold screen state. ViewModels only know repositories.
- **Repositories** decide *when* to use the cache or the network. They are the only layer that knows both TMDB and TVmaze, and a single shared instance lets two screens asking for the same show share one network call.
- **Services** wrap one external system each and contain no caching logic.
- **Stores** are actors around SwiftData. They return plain models, never SwiftData entities, so nothing non-`Sendable` leaves them.

Protocols appear only where they pay for themselves: at the boundary with external systems (TMDB, TVmaze, Firestore, Remote Config), so tests can inject test doubles. Production code always uses the real implementations as defaults.

## Design decisions

- **Freshness rules live in one place** (`CachePolicy`). An ended series never expires, since it will never get new episodes.
- **A shared cache keeps its original sync date** when copied locally, so old data never becomes "fresh" by moving.
- **The cache key includes the content language.** The Firestore cache is shared by every user and the content is localized, so two users with different languages can't overwrite each other's data.
- **The schedule is one date query.** Instead of loading every episode of every show, the app makes sure each show is cached locally, then reads recent and upcoming episodes in a single SwiftData query.
- **Only the three latest seasons are cached.** The schedule and notifications only need the current season; older ones load on demand when opened in the show page. A daily soap with hundreds of episodes no longer costs hundreds of rows.
- **Notifications are a pure plan, then applied.** `NotificationPlanner` turns episodes into a list of notifications with no side effects (fully unit tested); a thin `NotificationScheduler` replaces the pending ones. Stable identifiers make rescheduling idempotent, and the plan stays under iOS's 64-notification limit.
- **Permission is asked in context**, after the first show is followed, never at launch.
- **`currentUser` has one source of truth**: the Firebase auth stream. Sign in, sign out and account deletion update the whole app without extra code.
- **Followed shows are read local-first.** A Firestore snapshot listener answers from the offline cache at launch instead of waiting for the server, and also picks up changes made on another device.
- **Episode alerts belong to the show, not the device.** Muted shows are stored in the user document, next to the followed shows, at no extra read.

## App rules

Every threshold, limit and duration the app relies on (genres hidden from Home, seasons loaded for the schedule, cache lifetimes, the soft limit on followed shows, notification and Live Activity timing, color thresholds) lives in one file, [`tvQ/Core/AppRules.swift`](tvQ/Core/AppRules.swift), each with the reason it was chosen. The types that apply them only keep an alias. Server-side caps live in [`firestore.rules`](firestore.rules).

## What I learned

- **Scale the architecture to the project.** I started with a full Clean Architecture (Domain, Data and Presentation layers, a protocol for every repository) and removed it: for one developer, it added indirection without adding safety.
- **Measure before optimizing.** The slow schedule screen wasn't caused by the schedule itself but by shows being resolved one at a time. Resolving them in parallel removed several seconds at launch.
- **Moving to Swift 6 mode was worth it.** The compiler found real issues: a non-`Sendable` Firebase handle crossing actors, and a `[weak self]` that was silently strong for the lifetime of a stream.
- **Manual tests find what unit tests don't.** Rotating the token in the console showed that the app needed two relaunches to recover. The fix (refetch on 401) is now covered by tests that simulate a rotation while the app runs.
- **Read your own comments critically.** A comment promised that two screens would share in-flight requests, but each screen had its own repository instance. Sharing the repositories fixed it.

## Tests

More than 180 unit tests in Swift Testing, with no network access: real SwiftData stores in memory, test doubles for TMDB, TVmaze and Firestore, and a `URLProtocol` stub for the network layer.

- **Mappers and decoding**: merging TMDB and TVmaze (precise time over date only, show status priority), where-to-watch deduplication, and decoding of every API response shape, `null` values included.
- **Repositories**: the full cache cascade (fresh, stale, shared copy, ended series), deduplication of concurrent requests, a Firestore write failure that doesn't fail the request, season joins and sorting.
- **Notifications and Live Activities**: exact versus floating times, overnight releases moved to the morning with the right message, runtime fallbacks, muted shows, the 64-notification limit, which episodes get a Live Activity.
- **Session and account**: anonymous session, sign-in, account linking and deletion.
- **Followed shows**: optimistic updates rolled back on failure, and no data from a previous account after a sign-out during loading.
- **TMDB token**: first launch, offline launch, concurrent callers sharing one fetch, rotation while the app runs, throttling.
- **Network layer**: error classification (offline, HTTP status, decoding, cancellation).

The Firestore security rules have their own tests in `firestore-tests/` (Firebase emulator, `npm test`): a user can never read or write another user's data.

## Getting started

Requirements: Xcode 27, iOS 27.0.

1. Clone the repository and open `tvQ.xcodeproj`. Swift Package Manager dependencies (Firebase) resolve on the first build.
2. Copy `Config/Secrets.xcconfig.template` to `Config/Secrets.xcconfig` and add an App Check debug token (`uuidgen`).
3. Add your own Firebase `GoogleService-Info.plist` to the `tvQ/` folder, with Anonymous and Sign in with Apple authentication and Firestore enabled.
4. In Firebase Remote Config, create a `tmdb_token` string parameter holding a free [TMDB](https://www.themoviedb.org/settings/api) API read access token, then publish. The token is never compiled into the app, so it can be rotated from the console without a new build.
5. Build and run.

Both files are excluded from the repository on purpose.

## Next steps

- TestFlight beta
- Shared cache split by season, for daily shows with hundreds of episodes
- A "Trending" page based on what tvQ users follow most
- Face ID to unlock the app at launch

## Project structure

```
tvQ/
├── App/            Entry point and root navigation
├── Core/           App rules, settings, logging, networking, TMDB token (Remote Config)
├── Models/         Show, Episode, ShowSummary, WatchAvailability, AppUser
├── Notifications/  Notification and Live Activity planners and schedulers
├── Repositories/   ShowRepository, ScheduleRepository, CachePolicy
├── Services/       TMDB, TVmaze, Firebase, mappers, NetworkService
├── Stores/         SwiftData entities and stores, image cache
└── Views/          Screens and their ViewModels
tvQActivity/        Live Activity widget extension
Shared/             Code shared by the app and the extension
tvQTests/           Unit tests (Swift Testing)
firestore-tests/    Firestore security rules tests (emulator)
```

## Credits

Show data from [TMDB](https://www.themoviedb.org/) (this product uses the TMDB API but is not endorsed or certified by TMDB) and [TVmaze](https://www.tvmaze.com/). Streaming availability from [JustWatch](https://www.justwatch.com/).
