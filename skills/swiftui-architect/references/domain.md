# Domain models and services

XCore holds a feature's domain: the models its screens show, the errors they can fail with, and a service protocol per screen. Its adapter targets implement those protocols, one target per source (the API, the device's store, a provider's SDK), and map everything they receive into the domain, so XCore and XUI never know a source exists.

## Contents
- Domain models
- Errors
- Service protocols
- Naming services and their methods
- Live services
- Data stored on the device
- Mocks
- Cross-feature services: consumer-owned ports
- Lifetime services

## Domain models

A domain model describes what the app shows, not what the API sends. The API's shape (optional everything, snake_case fields, image paths, date strings, envelopes, pagination metadata) stops at the API's adapter targets.

```swift
// What TMDB sends, as Networking's types: optional fields, a date as text, an image as a path.

// What the Catalog feature shows, in CatalogCore:
public struct Movie: Identifiable, Equatable, Sendable {
    public let id: Int
    public let title: String
    public let year: Int?
    public let rating: Double?
    public let posterURL: URL?
    public let genres: [String]

    public init(id: Int, title: String, year: Int?, …) { … }
}
```

- **Value types, `Equatable` and `Sendable`.** They cross from live services to the main actor. `Identifiable` when a list shows them or a screen links to them.
- **`Identifiable` names the id's type.** Store `public let id: Int`, or whatever the id really is, and refer to it as the model's `ID`, with no `typealias ID`. A whole thing and its summary share one id, and signatures name the summary's, which lists and destinations carry: `movie(id: MovieSummary.ID) -> Movie`.
- **The whole thing is a plain noun; what a list shows of it adds `Summary`**: `Movie` and `MovieSummary`. A summary links to its whole thing by id. A model name never ends in `Detail`, which only screens use, or in a transport word (`DTO`, `Response`).
- **A model is complete for its role.** When reusing a model would leave fields empty or filled with placeholders, that role gets its own type. The whole thing leaves out what loads separately, such as a paged list (`view-models.md#a-thing-and-its-paged-list`).
- **Each fact is stated once, so an illogical value can't be written.** When two properties could disagree, carry one inside the other and compute it, rather than checking in an initializer:

```swift
// Can disagree: nothing stops the id from naming one genre and the source another.
public let id: DiscoverShelf.ID
public let source: Source

// Can't: the source says where the shelf comes from (`.genre(28)`), and the id follows.
public let source: Source
public var id: Source { source }
```

## Errors

Every feature has its own error enum, cased by what its screens show, or one per screen when their failures differ: Discover's feed can't be "not found", but a genre opened by its id can (`DiscoverError` and `GenreDetailError`). Errors are never shared between features.

```swift
public enum CatalogError: Error, Equatable {
    case offline
    case notFound
    case unavailable
}
```

- Cases are situations a screen tells apart, not transport details. `unavailable` is the catch-all for every failure that isn't offline or not found.
- A case carries no message: the screen's views say what each case shows (`views.md#what-a-screen-shows-without-content`).
- An empty answer is never an error. Never add a case, or throw one, to avoid an empty state the design doesn't have.

## Service protocols

XCore declares one service protocol per screen, holding what that screen loads and changes, with one ready-made method per resource. The service maps and aggregates what one call returns, so a view model only assigns it.

```swift
/// What a movie's details show: the movie and its cast.
public protocol MovieDetailService: Sendable {
    /// - Throws: `CatalogError`. Cancellation propagates as `CancellationError`.
    func movie(id: MovieSummary.ID) async throws -> Movie

    /// - Throws: `CatalogError`. Cancellation propagates as `CancellationError`.
    func cast(movieID: MovieSummary.ID) async throws -> [CastMember]
}
```

- Methods return domain values ready to show. A paged list returns `Page<Item>` from Shared; a screen that pages one thing's list has a method for each (`view-models.md#a-thing-and-its-paged-list`). Never wrap a page in a feature type to carry more: a count the screen shows is a read of its own.
- Methods use untyped `throws` and name the error in the doc comment. Cancellation must reach the view model as `CancellationError`, which `throws(CatalogError)` couldn't carry.
- Protocols refine `Sendable`, so `any MovieDetailService` crosses into the environment and a main-actor view model.
- Nothing else sits between a view model and its sources: no repository, use case, interactor or manager. A live service calls the client itself.
- A concern with a source of its own, such as recent searches, is a separate service the view model takes beside the screen's (`RecentSearchesService`), so every service has one source. A capability another feature owns is a [port](#cross-feature-services-consumer-owned-ports).

## Naming services and their methods

Names follow the [Swift API Design Guidelines](https://www.swift.org/documentation/api-design-guidelines/) and Apple's own async APIs. The networking client keeps the API's operation names; these rules start at the domain.

| Kind | Rule | Examples |
|---|---|---|
| Service protocol | The role's plain noun; protocols that describe what something is read as nouns | `MovieDetailService`, `DiscoverService` |
| Implementation | Its source, then the protocol's name, like `JSONDecoder` for `Decoder` | `TMDBMovieDetailService`, `TMDBWatchlistService` |
| Mock | `Mock` + the protocol's name, exposed as `.mock` | `MockMovieDetailService` |
| Reads | Noun phrases for what they return, with no side effects, like `WeatherService.weather(for:)` | `movie(id:)`, `cast(movieID:)`, `shelves(page:)` |
| Changes | Imperative verb phrases | `addToWatchlist(_:)`, `removeFromWatchlist(movieID:)` |
| Booleans | Assertions | `isInWatchlist(movieID:)` |
| Labels | `id:` for the thing itself, `<owner>ID:` for what belongs to an owner, `page:` last | `movie(id:)`, `movies(genreID:page:)` |

The split keeps call sites readable: the view model's `loadShelves()` changes state and calls the service's `shelves(page:)`, which returns a value.

## Live services

The API's adapter target implements each protocol over the networking client. A live service is a struct holding the client, or an actor when it holds state.

```swift
public struct TMDBMovieDetailService: MovieDetailService {
    private let client: TMDBClient

    public init(client: TMDBClient) {
        self.client = client
    }

    public func movie(id: MovieSummary.ID) async throws -> Movie {
        do {
            let response = try await client.movieDetails(id: id)
            guard let movie = Movie(response) else {
                throw CatalogError.unavailable
            }
            return movie
        } catch let error as TMDBError {
            throw CatalogError(error)
        }
    }

    // cast(movieID:) has the same shape.
}
```

- Mapping lives in `Model+Source.swift` extensions (`Movie+TMDB.swift`, `CatalogError+TMDB.swift`). A model maps from its response in a failable initializer, and a response that can't be read is `.unavailable`. A mapping to a Shared model that several features read lives once, in SharedTMDB (`modules.md#shared-sharedui-and-sharedtmdb`).
- The feature's error maps from the client's error in an initializer, and `CancellationError` passes through untouched (`networking.md#errors-and-cancellation`).
- A client step that two of a feature's live services share, such as reading extra artwork, is an extension on the client in XTMDB, with internal members.
- A client step that several features share, such as discovering movies by genre for Discover and for Search's filter, is an extension on the client in SharedTMDB's `Services/` (`TMDBClient+DiscoverMovies.swift`), with public members. It takes Shared values, returns a Shared model, and throws the client's error for each feature to map to its own.

## Data stored on the device

Data the app keeps on the device, such as Search's recent searches, sits behind an XCore service protocol, with a mock, like data from the API, so views and view models never know where it's kept. Which store keeps it is the user's answer (`decisions.md#always-asked`), and the store's adapter target (`Search<Store>`) holds the store's types (`modules.md#feature-packages`).

- Stored models live in that target's `Storage/`, named for the domain model they map to (`StoredRecentSearch`), and map to the domain like responses do. What only the store needs, such as the date that orders the list, stays in the stored model.
- The live service is named for its store, returns domain values, and throws the feature's `unavailable` when the store fails.
- XUI never reads the store, not even through view APIs the store provides: the view model loads stored data like any resource, and loads it again after changing it through the service.
- `<AppName>App.init` opens the store once, beside the client, and passes it to each live service that keeps data.

## Mocks

XCore ships a public mock of every protocol, so previews and other modules' tests need no network:

```swift
public struct MockMovieDetailService: MovieDetailService {
    /// What the mock answers: sample data, or a failure to preview an error state.
    public enum Scenario: Sendable {
        case sample
        case failure(CatalogError)
    }

    private let scenario: Scenario

    public init(scenario: Scenario = .sample) {
        self.scenario = scenario
    }

    public func movie(id: MovieSummary.ID) async throws -> Movie {
        if case .failure(let error) = scenario { throw error }
        … sample data …
    }

    public func cast(movieID: MovieSummary.ID) async throws -> [CastMember] { … }
}

extension MovieDetailService where Self == MockMovieDetailService {
    public static var mock: Self { Self() }

    public static func mock(_ scenario: MockMovieDetailService.Scenario) -> Self {
        Self(scenario: scenario)
    }
}
```

- A scenario lets each preview show one state the screen really has; `.mock` stays the plain sample.
- A mock that keeps state, such as a watchlist that remembers toggles, is an actor, and `.mock` returns a fresh instance.
- Tests use private stubs in their own test target instead (`modules.md#testing`).

## Cross-feature services: consumer-owned ports

When feature A needs a capability that feature B owns, A declares a port in its own XCore, named for its own need. The app implements it with an adapter over B, so neither feature imports the other.

```swift
// CatalogCore: named for the Catalog feature's need, not after Watchlist.
public protocol WatchlistMembershipService: Sendable {
    func isInWatchlist(movieID: MovieSummary.ID) async throws -> Bool
    func addToWatchlist(_ movie: MovieSummary) async throws
    func removeFromWatchlist(movieID: MovieSummary.ID) async throws
}

// App/Adapters/WatchlistMembershipAdapter.swift
struct WatchlistMembershipAdapter: WatchlistMembershipService {
    let watchlist: any WatchlistService

    func addToWatchlist(_ movie: MovieSummary) async throws {
        let item = WatchlistItem(movie: movie, addedAt: .now)
        try await watchlist.add(item)
    }
    …
}
```

The consumer ships a mock of its port too, so its previews and tests don't need the provider. A port throws the consumer's error, and its adapter maps the owner's into it.

State several features read or change, such as the watchlist or a signed-in account, works the same way:
- One feature owns it, with its model and service, and every other feature declares the port it needs.
- The owner's service carries what those ports need beside what its own screens load and change (`WatchlistService.add(_:)`).
- The app builds each adapter over the owner's one service instance, so every feature sees the same state. The state never moves into the shared package or a singleton.
- When another feature's state, such as whether an account is signed in, decides which of a feature's live services answers, the app implements that feature's service as an adapter that picks one per call. Neither feature learns about the other.

## Lifetime services

Work no screen starts, such as sending the watchlist changes made offline once the device is back online, or acting on a push, is a lifetime service: a service the app runs for as long as it's open.

```swift
// WatchlistCore
/// Sends the watchlist changes made offline to the account once the device is back online.
public protocol WatchlistSyncService: Sendable {
    /// Runs for as long as the app does.
    func run() async
}

// MoviesApp.init, after the services it takes
Task {
    await watchlistSyncService.run()
}
```

- The feature whose data the work changes owns it. Its XCore declares the protocol and a mock whose `run()` returns at once, and an adapter target implements it over the source it works on (`TMDBWatchlistSyncService`).
- When it reads a second source, such as the changes kept on the device, it takes that source's service through its XCore protocol, which the app passes in, since adapter targets never import each other.
- `run()` neither returns nor throws while the app runs: it handles each failure itself, such as by trying again on the next change.
- The app builds it in `<AppName>App.init` with the other services and starts it there, once, since `init` runs once for the app's lifetime. No screen reads it, so it has no environment key.
- Screens see its effects only through their own services, when they load: it never reaches a view model, and nothing on screen observes it.
- A push, or another event the system delivers to the app, reaches it through the app, which calls the owner's service.
- It's never a module, layer or folder of its own (`Sync`, `Workflows`, `Jobs`, `Managers`): each piece of work belongs to the feature whose data it changes.

Adding one, copy this checklist into the response:

```
- [ ] Search online and ask what's always asked (references/decisions.md), then design with system-design: what starts the work, what it changes, how it recovers
- [ ] Owner: the feature whose data it changes (references/domain.md#lifetime-services)
- [ ] XCore, with swift-api-design-guidelines-skill: its protocol with run(), and a mock
- [ ] Adapter target, with swift-concurrency-pro: its live service over its source; another source's service through its XCore protocol
- [ ] App: built in <AppName>App.init beside the services it takes, and started there; a push or other system event handed to the owner's service
- [ ] Tests, with swift-testing-pro: its own rules, in the adapter target's test target
- [ ] SKILL.md's Verify
```
