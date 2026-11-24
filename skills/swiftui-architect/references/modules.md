# Modules

The app is built from local Swift packages: one per feature, plus the shared package, DesignSystem and Networking, which every feature stands on. The compiler enforces the boundaries, since a module can use only what its package declares.

## Contents
- Defining features
- Feature packages
- Inside a feature
- Folder layout
- Package.swift template
- Shared, SharedUI and SharedLive
- DesignSystem
- Networking and other infrastructure
- Localization, assets and fonts
- Testing
- Checking the boundaries
- Moving an app into packages

## Defining features

A feature is a capability the user would name: finding something to watch (Discover), looking up a movie and the people in it (Catalog), searching (Search), keeping a watchlist (Watchlist), signing in (Account). It owns that capability's models, services and every screen of it, however many there are. A capability with one screen, such as signing in, is still a feature.

- Name it for the capability, never for a screen, a tab that gathers several capabilities or a model other features show: `Catalog`, not `MovieDetail`, `Home` or `Movie`. A tab that shows one capability shares the feature's name (`Discover`, `Watchlist`).
- Service protocols and view models are per screen inside a feature's targets; a screen never gets a package.

Decide a boundary by change and meaning:
- **One feature** when one kind of change touches both parts. A movie's cast and a person's credits are the same credits seen from either side, so a change to credits touches both screens.
- **Separate features** when each part changes for its own reasons: Discover changes with what the app recommends, Search with how queries and filters work.
- **Separate types** when a noun means something else in each part. To Catalog a movie's genres are labels on its details (`genres: [String]`); to Discover a genre is a place with its own paged movies (`Genre`).

Then check what a split costs. Only three things cross between features:
- IDs, through destinations
- narrow questions, through ports (`domain.md#cross-feature-services-consumer-owned-ports`), as Catalog asks Watchlist whether a movie is kept
- the shared vocabulary, through [the shared package](#shared-sharedui-and-sharedlive)

A split that needs more, such as one side's own types or a port for most of what the other does, is one feature.

- A screen that shows several features' data belongs to the feature whose capability it serves, and asks the others through ports: a movie's details show whether the movie is kept.
- Merge two features when most changes touch both, or when their ports keep growing. Split one when its parts share no types, change for different reasons and could stand alone, such as a `Home` package holding everything the first tab shows.

Avoid:
- A package per screen (`MovieDetail`, `MovieCast`). It splits one model across packages, so features import each other or the shared package grows.
- A package per tab that gathers several capabilities (`Home`), or per model other features show (`Movie`, `Person`, `Genre`). Every screen shows several such models, so their packages would import each other, which features never do.
- A package per layer (`Models`, `Services`, `Views`) that every feature shares.
- Moving a model to the shared package to avoid a port ([the promotion rule](#shared-sharedui-and-sharedlive)).

## Feature packages

Each feature is one package with four targets:

| Target | Contains | Imports |
|---|---|---|
| `XCore` | Domain models, `XError`, a service protocol and mock per screen, ports | `Shared` |
| `XUI` | View models, views, `XDestination`, `Localizable.xcstrings`, display mappings | `XCore`, `Shared`, `SharedUI`, `DesignSystem` |
| `XLive` | Live services over the API or the device's store, mapping what they return and their errors to the domain | `XCore`, `Shared`, `SharedLive`, `Networking` |
| `XTests` | View model and mapping tests | `XCore`, `XUI`, `XLive`, `Shared`, `SharedUI`, and `Networking` for response fixtures |

- XCore has no SwiftUI and no infrastructure, so the domain stays testable and usable by any UI.
- XUI depends on XCore's protocols, never on XLive, so it builds, previews and tests on mocks alone.
- XLive is the only feature target that sees the API or the store.
- The app links all three library targets: it builds live services from XLive and shows views from XUI (`composition.md`).

## Inside a feature

Names inside a feature say what a thing is, so a screen, model or view keeps its name whichever screens or tabs show it.

| What | Named for | Example |
|---|---|---|
| A tab's root screen, with its view model, service, error and the models only it shows | Its tab | `DiscoverView`, `DiscoverViewModel`, `DiscoverService`, `DiscoverShelf` |
| Any other screen | What it shows | `GenreDetailView`, `MovieCastView` |
| A view, model or mapping several of the feature's screens use | What it is | `CastMemberCard`, `MovieSummaryGrid` |
| What the whole feature owns | The feature | `CatalogDestination`, `CatalogError`, the `catalog.` string keys |

- A feature that several tabs show owns each tab's root screen. If Discover split into Movies and TV tabs, it would own `MoviesView` and `TVShowsView`.
- A section that two of the feature's screens show is one view in `Components/`, filed by kind (`Cards/`, `Rails/`). The movie's details and its cast screen both show `CastMemberCard`.
- A view several screens show is named for the model and its form (`CastMemberCard`, `MovieSummaryGrid`), and keeps that name if it moves to SharedUI.
- A frame that several screens put around different content takes that content as `@ContentBuilder` closures.
- A name an imported module already declares takes a qualifier from the domain: `MovieCollection`, not `Collection`. Unqualified, it is ambiguous in every module that imports both, so one in Shared, SharedUI or DesignSystem is ambiguous in every feature.

## Folder layout

```
Packages/Catalog/
├── Package.swift
├── Sources/
│   ├── CatalogCore/
│   │   ├── Models/            Movie.swift, CastMember.swift, Person.swift, Credit.swift, Department.swift,
│   │   │                      CatalogError.swift
│   │   └── Services/
│   │       ├── MovieDetailService/          MovieDetailService.swift, MockMovieDetailService.swift
│   │       ├── MovieCastService/            MovieCastService.swift, MockMovieCastService.swift
│   │       ├── PersonDetailService/         PersonDetailService.swift, MockPersonDetailService.swift
│   │       └── WatchlistMembershipService/  WatchlistMembershipService.swift, MockWatchlistMembershipService.swift
│   ├── CatalogLive/
│   │   ├── Mapping/           Movie+TMDB.swift, CastMember+TMDB.swift, Person+TMDB.swift, Credit+TMDB.swift,
│   │   │                      CatalogError+TMDB.swift
│   │   └── Services/          TMDBMovieDetailService.swift, TMDBMovieCastService.swift, TMDBPersonDetailService.swift
│   └── CatalogUI/
│       ├── MovieDetail/       MovieDetailViewModel.swift, MovieDetailViewModel+WatchlistMembership.swift,
│       │                      MovieDetailView.swift, MovieDetailPhaseView.swift, MovieDetailContentView.swift, …
│       ├── MovieCast/         MovieCastViewModel.swift, MovieCastView.swift, MovieCastPhaseView.swift,
│       │                      MovieCastContentView.swift
│       ├── PersonDetail/      PersonDetailViewModel.swift, PersonDetailView.swift, PersonDetailPhaseView.swift, …
│       ├── Components/
│       │   └── Cards/         CastMemberCard.swift
│       ├── Navigation/        CatalogDestination.swift
│       └── Resources/         Localizable.xcstrings
└── Tests/CatalogTests/
    ├── Live/                  CatalogMappingTests.swift
    ├── ViewModels/            MovieDetailViewModelTests.swift, MovieCastViewModelTests.swift,
    │                          PersonDetailViewModelTests.swift
    └── Fixtures.swift
```

Where each file goes: `conventions.md#folders`.

## Package.swift template

```swift
// swift-tools-version: 6.4

import PackageDescription

let swiftSettings: [SwiftSetting] = [
    .enableUpcomingFeature("ExistentialAny"),
    .enableUpcomingFeature("MemberImportVisibility"),
    .enableUpcomingFeature("InternalImportsByDefault"),
    .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
    .enableUpcomingFeature("InferIsolatedConformances"),
    .strictMemorySafety(),
]

let package = Package(
    name: "Catalog",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v26)
    ],
    products: [
        .library(name: "CatalogCore", targets: ["CatalogCore"]),
        .library(name: "CatalogUI", targets: ["CatalogUI"]),
        .library(name: "CatalogLive", targets: ["CatalogLive"]),
    ],
    dependencies: [
        .package(path: "../Shared"),
        .package(path: "../DesignSystem"),
        .package(path: "../Networking"),
    ],
    targets: [
        .target(
            name: "CatalogCore",
            dependencies: [
                .product(name: "Shared", package: "Shared")
            ],
            swiftSettings: swiftSettings
        ),
        .target(
            name: "CatalogUI",
            dependencies: [
                "CatalogCore",
                .product(name: "Shared", package: "Shared"),
                .product(name: "SharedUI", package: "Shared"),
                .product(name: "DesignSystem", package: "DesignSystem"),
            ],
            resources: [
                .process("Resources")
            ],
            swiftSettings: swiftSettings
        ),
        .target(
            name: "CatalogLive",
            dependencies: [
                "CatalogCore",
                .product(name: "Shared", package: "Shared"),
                .product(name: "SharedLive", package: "Shared"),
                .product(name: "Networking", package: "Networking"),
            ],
            swiftSettings: swiftSettings
        ),
        .testTarget(
            name: "CatalogTests",
            dependencies: [
                "CatalogCore",
                "CatalogUI",
                "CatalogLive",
                .product(name: "Shared", package: "Shared"),
                .product(name: "SharedUI", package: "Shared"),
                .product(name: "Networking", package: "Networking"),
            ],
            swiftSettings: swiftSettings
        ),
    ],
    swiftLanguageModes: [.v6]
)
```

- Set `platforms` to the app's deployment target, and the tools version to the team's toolchain, 6.4 or later, whose SDK has the APIs the shapes use.
- Every target builds in Swift 6 mode with these settings, the defaults Swift is moving to, and a package added later starts from them.
- Imports are internal by default: a file imports a module `public` when its public declarations use the module's types, and plainly otherwise. It imports every module whose members it uses, since `MemberImportVisibility` hides the rest.
- No package sets `.defaultIsolation(MainActor.self)`: domain types, errors and destinations cross actors, so UI types are marked `@MainActor` instead.

## Shared, SharedUI and SharedLive

The shared package mirrors a feature's layers:

| Target | Contains | Imports |
|---|---|---|
| `Shared` | `Domain/`: the vocabulary several features share (`MovieSummary`, `Page<Item>`) | Foundation only |
| `SharedUI` | `Components/`: views several features show (`MovieSummaryCard`) and the shared screen states (`ContentUnavailableView.offline(retry:)`) with their copy. `Navigation/`: `SharedDestination` (`navigation.md#shareddestination-sharedui`) | `Shared`, `DesignSystem` |
| `SharedLive` | `Mapping/`: an API type's mapping to a Shared model that several features read (`MovieSummary+TMDB.swift`, `Page+TMDB.swift`), tested in `SharedLiveTests`. `Services/`: a step on the client that several features' live services share (`domain.md#live-services`) | `Shared`, `Networking` |

```swift
/// One page of a paginated list, as a service returns it.
public struct Page<Item: Sendable>: Sendable {
    public let items: [Item]
    /// The page to request next, or `nil` when this is the last one.
    public let nextPage: Int?

    public init(items: [Item], nextPage: Int?) {
        self.items = items
        self.nextPage = nextPage
    }
}
```

**The promotion rule.** A type moves into Shared or SharedUI, and a mapping or client step into SharedLive, only when a second feature needs the same concept and both copies must change together. It holds both ways: what only one feature uses belongs in that feature, however many of its screens use it. Two types that merely look alike are duplicated; they will diverge.

Never in the shared package:
- Errors, service protocols, ports, live services or stored models; each feature maps the client's errors to its own
- Navigation types other than `SharedDestination`
- Environment keys, app state or preferences
- The API's types outside SharedLive
- "Utils" grab-bags; a helper lives next to the concept it serves

Test fixtures are repeated in each feature that needs them, with no shared testing target.

## DesignSystem

One domain-free package, imported by every UI target, holding the visual language:
- **Tokens** for color, spacing and type, named as the design names them.
- **Styles** for native controls, so features keep using `Button` and `NavigationLink` and only pick a style.
- **Components** that take plain values and `@ContentBuilder` closures, such as a rail or a remote image.

It never knows a feature model, service, destination or screen, has no strings of its own, and decides no policy. A view that renders a domain type belongs in a feature, or in SharedUI when several features show it.

## Networking and other infrastructure

`Networking` holds the API's types and the app's client over them (`networking.md`). It and any other infrastructure package, such as analytics, are imported by the Live targets, XTests and the app, never by XCore or XUI.

They import no feature. What they need from one, such as who is signed in, the app passes in as a closure when it builds their clients.

## Localization, assets and fonts

Each module owns the strings, images and colors it shows. How they're declared and read is `swiftui-pro`'s subject (`related-skills.md`).

- **Strings.** Each XUI target has a String Catalog (`Resources/Localizable.xcstrings`) for everything its views show; the app has one for its own chrome. SharedUI's catalog holds only copy every feature must say the same way, such as the shared screen states. A string two features show is duplicated in each catalog.
- A key names its feature and screen (`catalog.movieCast.title`).
- Display mappings are XUI extensions on domain values (`Department.title`); models and view models hold no display strings.
- **Images and colors.** A feature's artwork lives in its XUI target, shared icons and colors in DesignSystem, the app icon in the app.
- **Custom fonts** ship in DesignSystem.

## Testing

Each feature package builds, previews and tests without the app. Test what a bug would break, not what every instance of a shape repeats; how to write the tests, their stubs and test data included, is `swift-testing-pro`'s subject (`related-skills.md`).

| Behavior | Tested in |
|---|---|
| A screen's own rules: what it loads, its failure rule, paging, stale results (`view-models.md#testing-view-models`) | `XTests/ViewModels` |
| Mapping: what a response becomes, and the next page | `XTests/Live` and `SharedLiveTests` |
| A live service's own rules over the store, such as newest first and no repeats | `XTests/Live` |
| Requests, decoding, error classification and cancellation | `NetworkingTests` |
| `Destination` mappings that aren't one-to-one, and adapters | app tests |
| Visual states: loading, empty, error | previews |

After every change to a feature, test its package's scheme on an iOS Simulator from the package's folder, and build the app after changing anything public:

```
xcodebuild test -scheme Catalog-Package -destination 'platform=iOS Simulator,name=<an installed iPhone>'
```

`swift build` and `swift test` build for the Mac, where an iOS-only package's views and view models don't compile.

## Checking the boundaries

The compiler enforces what each package declares, but not system frameworks, the app target or the roles types play. This skill's `scripts/check_boundaries.sh` checks the rest. Run it from the app's repository root, with no arguments; it prints each failure under the rule it breaks and exits non-zero on any. Under REVIEW it lists each package dependency besides the shared package, DesignSystem and Networking, which must be infrastructure, such as analytics, and each module a Live target imports that a Core, UI or Shared target imports too, which must be neither the API's nor the store's.

A review copies this checklist into the response:

```
- [ ] Run scripts/check_boundaries.sh from the repository root, and settle each REVIEW line
- [ ] Each feature passes the boundary tests (references/modules.md#defining-features) and owns all its screens; the shared package holds nothing only one feature uses
- [ ] Each screen: one view model, built by its XScreen, over its own service protocol and ports
- [ ] Hand-rolled schemes where a standard or a proven approach exists (references/decisions.md#the-established-approach-first)
- [ ] The code inside the shapes with its related skills: views with swiftui-pro, loads and live services with swift-concurrency-pro, tests with swift-testing-pro, stored data with swiftdata-pro if it's SwiftData
- [ ] Report each finding with its file, the rule it breaks and the fix; change code only when the user asks
```

## Moving an app into packages

An app built another way keeps its structure until the user asks to change it. A change there follows the app's own layout and conventions, and takes a shape from this skill only where the app has none of its own. A new app, or one already in packages, follows this skill throughout.

Restructuring moves the app in steps that each leave it building. Copy this checklist into the response:

```
- [ ] Map the app: its capabilities (a feature each, by the boundary tests in references/modules.md#defining-features), their screens, and what two features already share
- [ ] Networking, then DesignSystem, then the shared package with only what two features already share; build the app after each
- [ ] One feature at a time, the one using the fewest others first so it needs the fewest ports, as in SKILL.md's Add a feature: its reach into other features becomes destinations and ports, and the code still in the app target switches to its public API
- [ ] As screens leave the app target, their services move into <AppName>App.init and their navigation into Router, Destination, DestinationView and navigationDestinations()
- [ ] After each step, SKILL.md's Verify; fix and repeat until it passes
```

- A step that would leave the app unbuildable is split into smaller ones, never left half done.
- A networking singleton splits as it moves: its requests, decoding and error classification become the client and its error in Networking, and what it does with the answers moves into the live services of the features that call it, each as its feature moves. Until its last caller leaves the app target, it stays there as a thin layer over the client.
