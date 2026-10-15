# tvQ

**Never miss an episode.** tvQ shows when the next episodes of the series you follow air, down to the exact local time, and where to watch them in your country.

A native iOS app built solo in Swift 6 and SwiftUI.

*[Version française](README.fr.md)*

| Home | Schedule | My Shows |
|---|---|---|
| ![Home](Screenshots/tvQ-accueil.png) | ![Schedule](Screenshots/tvQ-horaire-dark-mode.png) | ![My Shows](Screenshots/tvQ-mesSeries-dark-mode.jpeg) |

| Search | Show detail (dark) | Show detail (light) |
|---|---|---|
| ![Search](Screenshots/tvQ-recherche-dark-mode.jpeg) | ![Show detail, dark](Screenshots/tvQ-serie-detail-dark-mode.png) | ![Show detail, light](Screenshots/tvQ-serie-detail.png) |

## Highlights

- **Swift 6 strict concurrency.** Compiled in Swift 6 language mode: main actor isolation by default, SwiftData confined to `@ModelActor` stores, immutable `Sendable` models crossing between them.
- **Three-tier cache with stale-while-revalidate.** Local SwiftData first, then a Firestore cache shared by all users, then the TMDB and TVmaze APIs. Stale data is shown instantly and refreshed in the background, so the schedule never waits on the network.
- **Two APIs merged into one schedule.** TMDB provides the content (titles, synopses, seasons, artwork); TVmaze provides the precise air time with its time zone. When TVmaze has no match, the app falls back to TMDB's date without inventing an hour.
- **Where to watch, per country.** Streaming, rental and purchase options for Canada, the US, France and the UK, with duplicate catalog entries merged (Disney Plus and Disney+, Netflix with ads).
- **Sign in with Apple and account deletion** that meet App Store requirements, including Apple token revocation.
- **Bilingual** (English and French), for both the interface and the show content.

## Tech stack

| | |
|---|---|
| UI | SwiftUI, Observation (`@Observable`) |
| Language | Swift 6 language mode, iOS 27.2 |
| Concurrency | `async`/`await`, actors, `@ModelActor`, task groups |
| Local storage | SwiftData |
| Backend | Firebase Auth (Sign in with Apple, email), Cloud Firestore |
| Data | [TMDB](https://www.themoviedb.org/), [TVmaze](https://www.tvmaze.com/), [JustWatch](https://www.justwatch.com/) via TMDB |
| Tests | Swift Testing |

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

## Design decisions

- **Freshness rules live in one place** (`CachePolicy`). An ended series never expires, since it will never get new episodes.
- **A shared cache keeps its original sync date** when copied locally, so old data never becomes "fresh" by moving.
- **The cache key includes the content language.** The Firestore cache is shared by every user and the content is localized, so two users with different languages can't overwrite each other's data.
- **The schedule is one date query.** Instead of loading every episode of every show, the app makes sure each show is cached locally, then reads recent and upcoming episodes in a single SwiftData query.
- **`currentUser` has one source of truth**: the Firebase auth stream. Sign in, sign out and account deletion update the whole app without extra code.

## What I learned

- **Scale the architecture to the project.** I started with a full Clean Architecture (Domain, Data and Presentation layers, a protocol for every repository) and removed it: for one developer, it added indirection without adding safety.
- **Measure before optimizing.** The slow schedule screen wasn't caused by the schedule itself but by shows being resolved one at a time. Resolving them in parallel removed several seconds at launch.
- **Moving to Swift 6 mode was worth it.** The compiler found real issues: a non-`Sendable` Firebase handle crossing actors, and a `[weak self]` that was silently strong for the lifetime of a stream.
- **Read your own comments critically.** A comment promised that two screens would share in-flight requests, but each screen had its own repository instance. Sharing the repositories fixed it.

## Tests

Swift Testing, with an in-memory SwiftData database:

- `LocalStoresTests`: round trips, replacement and clearing of stores, the upcoming-episodes query (date and show filters, sort order), and two languages without collisions.
- `CachePolicyTests`: freshness rules, including ended series.

## Getting started

Requirements: Xcode 27, iOS 27.2.

1. Clone the repository and open `tvQ.xcodeproj`. Swift Package Manager dependencies (Firebase) resolve on the first build.
2. Copy `Config/Secrets.xcconfig.template` to `Config/Secrets.xcconfig` and add a free [TMDB](https://www.themoviedb.org/settings/api) API read access token.
3. Add your own Firebase `GoogleService-Info.plist` to the `tvQ/` folder, with Sign in with Apple and Firestore enabled.
4. Build and run.

Both files are excluded from the repository on purpose.

## Next steps

- TestFlight beta
- A "Trending" page based on what tvQ users follow most
- Face ID to unlock the app at launch

## Project structure

```
tvQ/
├── App/            Entry point and root navigation
├── Core/           Settings and API configuration
├── Models/         Show, Episode, ShowSummary, WatchAvailability, AppUser
├── Repositories/   ShowRepository, ScheduleRepository, CachePolicy
├── Services/       TMDB, TVmaze, Firebase, mappers, NetworkService
├── Stores/         SwiftData entities and stores, image cache
├── ViewModels/
└── Views/
```

## Credits

Show data from [TMDB](https://www.themoviedb.org/) (this product uses the TMDB API but is not endorsed or certified by TMDB) and [TVmaze](https://www.tvmaze.com/). Streaming availability from [JustWatch](https://www.justwatch.com/).
