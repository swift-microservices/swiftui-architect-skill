# Composition

The app target is the composition root. It is the only module that imports every feature, so it builds every service, wires features together, owns navigation state and builds every screen.

## Contents
- App target layout
- `<AppName>App.swift`
- Environment keys
- ContentView
- XScreen: tab and pushed

## App target layout

```
MoviesApp/
├── MoviesApp.swift                 @main: client, store, services, Scene
├── App/ContentView.swift           the window's Router and its TabView
├── Adapters/                       consumer-owned ports implemented over other features
├── Extensions/Environment/         one @Entry key per service protocol
├── Navigation/                     Router, TabDestination, Destination, DestinationView, navigationDestinations()
└── Screens/                        one XScreen per screen
```

## `<AppName>App.swift`

Build the client, the store (`domain.md#data-stored-on-the-device`) and every service and adapter in `init()`, keep them as `let` properties typed as the feature protocols, and inject them on the `Scene`, so every window and screen sees the same instances. No DI container and no singletons.

```swift
@main
struct MoviesApp: App {
    private let discoverService: any DiscoverService
    private let movieDetailService: any MovieDetailService
    private let watchlistService: any WatchlistService
    private let watchlistMembershipService: any WatchlistMembershipService

    init() {
        do {
            let client = try TMDBClient(…)
            let watchlistService = TMDBWatchlistService(client: client)

            discoverService = TMDBDiscoverService(client: client)
            movieDetailService = TMDBMovieDetailService(client: client)
            self.watchlistService = watchlistService
            watchlistMembershipService = WatchlistMembershipAdapter(watchlist: watchlistService)
        } catch {
            fatalError("Couldn't start the app: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .environment(\.discoverService, discoverService)
        .environment(\.movieDetailService, movieDetailService)
        .environment(\.watchlistService, watchlistService)
        .environment(\.watchlistMembershipService, watchlistMembershipService)
    }
}
```

- Live or mock is the app's decision, through configuration or launch arguments for UI tests. Features never decide.
- One service instance per protocol for the app's lifetime; views never create services.
- A lifetime service is built here too, and started at the end of `init()` (`domain.md#lifetime-services`).
- App-wide policies, such as caching and tint, are applied here, not in features or DesignSystem.
- Values that differ by build, such as the API's base URL and key, reach the client through its init from the app. A key is never written in source or committed.

## Environment keys

One key per service protocol, each in `Extensions/Environment/EnvironmentValues+XService.swift`. The default is the protocol's mock, so previews work without setup:

```swift
import CatalogCore
import SwiftUI

extension EnvironmentValues {
    @Entry var movieDetailService: any MovieDetailService = .mock
}
```

- Only app screens read these keys. Feature views never read services: `XView` receives its view model from the screen.
- `.mock` on an actor mock returns a fresh instance on each read, so a preview that needs a mock's state to persist injects one stored instance.

## ContentView

```swift
struct ContentView: View {
    /// This window's navigation state: each window keeps its own tab and stacks.
    @State private var router = Router()

    var body: some View {
        TabView(selection: $router.selectedTab) {
            Tab(value: .discover) {
                DiscoverScreen()
            } label: {
                Label(.appTabDiscover, systemImage: …)
            }
            Tab(value: .watchlist) {
                WatchlistScreen()
            } label: {
                Label(.appTabWatchlist, systemImage: …)
            }
            Tab(value: .search, role: .search) {
                SearchScreen()
            } label: {
                Label(.appTabSearch, systemImage: …)
            }
        }
        .environment(router)
    }
}
```

Each tab's title and icon are written here, in its `Tab`'s label.

The top-level places come from the app's design, and the movie browser's are three tabs. An app without tabs has one root screen, whose XScreen owns the window's one stack, and a `Router` holding that one path, with no `TabDestination`.

## XScreen: tab and pushed

An `XScreen` is a small app view that composes one screen: it reads services from the environment, builds the feature's view model, and passes it to the feature's public view. It's named after that view (`MovieDetailView` → `MovieDetailScreen`), and builds the view model inline, passing every service its nested models (`view-models.md#nested-models-and-modes`) use too.

A **tab XScreen** shows a tab's root screen. It owns the tab's `NavigationStack`, bound to the Router, and applies `navigationDestinations()` at its root (`navigation.md#registering-destinations`). A feature that several tabs show supplies a root screen for each tab, and each gets its own tab XScreen.

```swift
/// The Discover tab: its navigation stack, Discover at the root, and the screens it can push.
struct DiscoverScreen: View {
    @Environment(\.discoverService) private var discoverService
    @Environment(Router.self) private var router

    var body: some View {
        @Bindable var router = router
        NavigationStack(path: $router[.discover]) {
            DiscoverView(viewModel: DiscoverViewModel(service: discoverService))
                .navigationDestinations()
        }
    }
}
```

An `XView` that presents a screen takes it from its XScreen, as a closure that builds it with `DestinationView` (`navigation.md#presenting-a-screen`).

A **pushed XScreen** takes only IDs, never models, so the stack stays small, `Codable` and restorable. It owns no stack.

```swift
/// A movie, pushed onto whichever stack opened it.
struct MovieDetailScreen: View {
    @Environment(\.movieDetailService) private var movieDetailService
    @Environment(\.watchlistMembershipService) private var watchlistMembershipService
    let movieID: MovieSummary.ID

    var body: some View {
        MovieDetailView(
            viewModel: MovieDetailViewModel(
                movieID: movieID,
                service: movieDetailService,
                watchlistMembershipService: watchlistMembershipService
            )
        )
    }
}
```

Every XScreen has a preview, on the keys' default mocks; a tab XScreen's also injects `Router()`.
