# Modules

The app is built from local Swift packages: one per feature and, below the features, the shared package, DesignSystem once the app has a visual language of its own, and Networking when it calls an API. The compiler enforces the boundaries, since a module can use only what its package declares.

## Contents
- Defining features
- Feature packages
- What Core may link
- Inside a feature
- Folder layout
- Package.swift template
- The shared package
- DesignSystem
- Networking and other infrastructure
- Placing a type
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
- the shared vocabulary, through [the shared package](#the-shared-package)

A split that needs more, such as one side's own types or a port for most of what the other does, is one feature.

- A screen that shows several features' data belongs to the feature whose capability it serves, and asks the others through ports: a movie's details show whether the movie is kept.
- Merge two features when most changes touch both, or when their ports keep growing. Split one when its parts share no types, change for different reasons and could stand alone, such as a `Home` package holding everything the first tab shows.

Avoid:
- A package per screen (`MovieDetail`, `MovieCast`). It splits one model across packages, so features import each other or the shared package grows.
- A package per tab that gathers several capabilities (`Home`), or per model other features show (`Movie`, `Person`, `Genre`). Every screen shows several such models, so their packages would import each other, which features never do.
- A package per layer (`Models`, `Services`, `Views`) that every feature shares.
- Moving a model to the shared package to avoid a port ([the promotion rule](#the-shared-package)).

## Feature packages

Each feature is one package: its domain and UI, an adapter target for each source its services read, and a test target for each target with tests ([testing](#testing)).

| Target | Contains | Imports |
|---|---|---|
| `XCore` | Domain models, `XError`, a service protocol and mock per screen, ports | `Shared`, and what [Core may link](#what-core-may-link) |
| `XUI` | View models, views, `XDestination`, `Localizable.xcstrings`, display mappings | `XCore`, `Shared`, `SharedUI`, `DesignSystem`, the UI frameworks |
| `X<Source>`, an adapter target | The live services over one source, mapping what it returns and its errors to the domain. The source is an API (`CatalogTMDB`), the store the user picked (`Search<Store>`) or a provider's SDK | `XCore`, `Shared` and its source: `Networking` and `Shared<API>` for an API |

A feature declares only the adapter targets its services read: Catalog is `CatalogCore`, `CatalogUI` and `CatalogTMDB`, tested in `CatalogUITests` and `CatalogTMDBTests`; Search adds `Search<Store>` for its recent searches.

- XUI depends on XCore's protocols, never on an adapter target, so it builds, previews and tests on mocks alone.
- A source's types never leave its adapter targets: an API's stay in `X<API>` and `Shared<API>`, the store's in `X<Store>`. Every service has one source (`domain.md#service-protocols`), so each live service sits in one adapter target.
- Adapter targets never import each other. An API's import the shared package's for that API, `Shared<API>`, which stands below every feature.
- Mappings and stored models are `package`, so the package's test targets reach them and the app sees only the `public` live services. A stored model is `public` only when the app needs it to open the store, and `Shared<API>`'s mappings are `public`, since other packages' adapter targets use them.
- The app links XCore, XUI and the adapter targets: it builds live services from the adapter targets and shows views from XUI (`composition.md`).

## What Core may link

XCore holds the feature's domain and business rules, and Shared the vocabulary several features share. Every other target builds on them, so they never link a UI framework or infrastructure, and the domain stays testable and usable by any UI. Besides Foundation, and Shared for XCore, they link a library only when it:
- does no I/O and has nothing to run
- has no store, transport, device or UI types in its API
- builds for every platform the app declares
- is stable enough for its types to appear in models and service protocols

Before Core imports a library, decide it in this order:
1. A UI framework, such as SwiftUI, UIKit, AppKit or WatchKit, belongs to XUI, SharedUI or DesignSystem.
2. Infrastructure is a source: a store's framework, a provider's SDK, Networking and any framework that reaches the device's capabilities. Core declares a service protocol, and an adapter target implements it over the library and keeps its types. That holds where the platform's own guidance reads a store's models from views (`domain.md#data-stored-on-the-device`).
3. A framework whose macros or protocols the domain's own types would adopt, such as Observation, is a commitment the user makes, as to the standard library. It's recorded with its reason (`decisions.md#recording-a-decision`), and Core then links it like Foundation. A UI framework or infrastructure is never a commitment.
4. Any other library that meets every criterion is linked like Foundation, a package only once the user agrees (`decisions.md#the-established-approach-first`).

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
│   ├── CatalogTMDB/
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
└── Tests/
    ├── CatalogTMDBTests/      CatalogMappingTests.swift, Fixtures.swift
    └── CatalogUITests/        MovieDetailViewModelTests.swift, MovieCastViewModelTests.swift,
                               PersonDetailViewModelTests.swift, Fixtures.swift
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
    .enableUpcomingFeature("ImmutableWeakCaptures"),
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
        .library(name: "CatalogTMDB", targets: ["CatalogTMDB"]),
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
            name: "CatalogTMDB",
            dependencies: [
                "CatalogCore",
                .product(name: "Shared", package: "Shared"),
                .product(name: "SharedTMDB", package: "Shared"),
                .product(name: "Networking", package: "Networking"),
            ],
            swiftSettings: swiftSettings
        ),
        .testTarget(
            name: "CatalogUITests",
            dependencies: [
                "CatalogUI",
                "CatalogCore",
                .product(name: "Shared", package: "Shared"),
            ],
            swiftSettings: swiftSettings
        ),
        .testTarget(
            name: "CatalogTMDBTests",
            dependencies: [
                "CatalogTMDB",
                "CatalogCore",
                .product(name: "Shared", package: "Shared"),
                .product(name: "Networking", package: "Networking"),
            ],
            swiftSettings: swiftSettings
        ),
    ],
    swiftLanguageModes: [.v6]
)
```

- `platforms` lists each platform the app runs on at its minimum version, the user's answer (`decisions.md#always-asked`); the movie browser's is iOS 26. The tools version is 6.4 or later, from Xcode 27 or later, whose SDK has the APIs the shapes use.
- Every target builds in Swift 6 mode with these settings, the defaults Swift is moving to, and a package added later starts from them.
- Access levels and imports follow `style.md#access-control-and-imports`.
- No package sets `.defaultIsolation(MainActor.self)`: domain types, errors, destinations and display mappings cross actors, and a type moved between XCore and XUI keeps its isolation, so UI types are marked `@MainActor` instead. The app target, which only composes the UI, keeps Xcode's main-actor default.

## The shared package

The shared package mirrors a feature's layers:

| Target | Contains | Imports |
|---|---|---|
| `Shared` | `Domain/`: the vocabulary several features share (`MovieSummary`, `Page<Item>`) | Foundation, and what [Core may link](#what-core-may-link) |
| `SharedUI` | `Components/`: views several features show (`MovieSummaryCard`) and the shared screen states (`ContentUnavailableView.offline(retry:)`) with their copy. `Navigation/`: `SharedDestination` (`navigation.md#shareddestination-sharedui`) | `Shared`, `DesignSystem`, the UI frameworks |
| `Shared<API>`, an API's adapter target (`SharedTMDB`) | `Mapping/`: an API type's mapping to a Shared model that several features read (`MovieSummary+TMDB.swift`, `Page+TMDB.swift`), tested in `Shared<API>Tests`. `Services/`: a step on the client that several features' live services share (`domain.md#live-services`) | `Shared`, `Networking` |

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

**The promotion rule.** A type moves into Shared or SharedUI, and a mapping or client step into `Shared<API>`, only when a second feature needs the same concept and both copies must change together. It holds both ways: what only one feature uses belongs in that feature, however many of its screens use it. Two types that merely look alike are duplicated; they will diverge.

Never in the shared package:
- Errors, service protocols, ports, live services or stored models; each feature maps the client's errors to its own
- Navigation types other than `SharedDestination`
- Environment keys, app state or preferences
- An API's types outside its `Shared<API>`
- "Utils" grab-bags; a helper lives next to the concept it serves

## DesignSystem

One domain-free package holding the app's own visual language, imported by every UI target. It joins once the app has a token, style or component of its own; until then, the UI targets use the platform's styles. It holds:
- **Tokens** for color, spacing and type, named as the design names them.
- **Styles** for native controls, so features keep using `Button` and `NavigationLink` and only pick a style.
- **Components** that take plain values and `@ContentBuilder` closures, such as a rail or a remote image.

It never knows a feature model, service, destination or screen, has no strings of its own, and decides no policy. A view that renders a domain type belongs in a feature, or in SharedUI when several features show it.

## Networking and other infrastructure

`Networking` holds each API's types and the app's client over them (`networking.md`). It and any other infrastructure package, such as analytics, are imported by adapter targets, their test targets and the app, never by XCore or XUI.

They import no feature. What they need from one, such as who is signed in, the app passes in as a closure when it builds their clients.

## Placing a type

1. Used by one feature, from any of its screens → that feature: XCore for models and contracts, XUI for view models and anything visual or localized, the source's adapter target for mapping.
2. Needed by a second feature, both changing together → Shared for a model, SharedUI for a view, `Shared<API>` for a mapping to a Shared model or a client step both call.
3. Only looks alike → duplicate it.
4. Visual and domain-free → DesignSystem; talks to an API → Networking; wires features together → the app.

## Localization, assets and fonts

Each module owns the strings, images and colors it shows. How they're declared and read is `swiftui-pro`'s subject (`related-skills.md`).

- **Strings.** Each XUI target has a String Catalog (`Resources/Localizable.xcstrings`) for everything its views show; the app has one for its own chrome. SharedUI's catalog holds only copy every feature must say the same way, such as the shared screen states. A string two features show is duplicated in each catalog.
- A key names its feature and screen (`catalog.movieCast.title`).
- Display mappings are XUI extensions on domain values (`Department.title`); models and view models hold no display strings.
- **Images and colors.** A feature's artwork lives in its XUI target, shared icons and colors in DesignSystem, the app icon in the app.
- **Custom fonts** ship in DesignSystem.

## Testing

Each feature package builds, previews and tests without the app. Each tested target has its own test target, named for it, so view model tests never build against the API and mapping tests never build views. Test what a bug would break, not what every instance of a shape repeats; how to write the tests, their stubs and test data included, is `swift-testing-pro`'s subject (`related-skills.md`).

| Behavior | Tested in |
|---|---|
| A screen's own rules: what it loads, its failure rule, paging, stale results (`view-models.md#testing-view-models`) | `XUITests` |
| Mapping: what a response becomes, and the next page | `X<API>Tests`, and `Shared<API>Tests` for the shared mappings |
| A live service's own rules over the store, such as newest first and no repeats | `X<Store>Tests` |
| Requests, decoding, error classification and cancellation | `NetworkingTests` |
| `Destination` mappings that aren't one-to-one, and the app's port adapters | app tests |
| Visual states: loading, empty, error | previews |

- A test target imports the target it tests and the modules whose types its tests name, as the template's two do, never an adapter target it doesn't test.
- Fixtures are repeated in each test target that needs them, with no shared testing target.

After every change to a feature, test its package's scheme from the package's folder, and build the app's scheme from the app's folder after changing anything public, with this skill's `scripts/xcode_ci.sh`:

```
xcode_ci.sh test Catalog-Package
xcode_ci.sh build MoviesApp
```

- A package's scheme is `<Package>-Package` when it has several products, and its product's name when it has one.
- The script runs `xcodebuild` once for each platform the package lists in `platforms`, or the app's scheme supports: on the Mac for macOS, and on an installed simulator for each other platform. It fails on a warning in the repository's own code, and lists a dependency's warning under REVIEW, as a departure to record (`decisions.md#warnings-from-dependencies`).
- `swift build` and `swift test` build only for the Mac, where a package for other platforms doesn't compile.

## Checking the boundaries

The compiler enforces what each package declares, but not system frameworks, the app target or the roles types play. This skill's `scripts/check_boundaries.sh` checks the rest, and `scripts/check_style.sh` the style rules a script can see (`style.md`). Run both from the app's repository root, with no arguments; each prints a failure under the rule it breaks and exits non-zero on any.

`check_boundaries.sh` lists under REVIEW:
- each package dependency besides the shared package, DesignSystem and Networking, which must be infrastructure, such as analytics
- each module XCore or Shared imports besides Foundation and Shared, which must be one [Core may link](#what-core-may-link)
- each module that an adapter target and a Core, UI or Shared target both import, which must be no adapter target's source: the compiler keeps out a package it isn't given, but not a system framework such as a store's

`check_style.sh` lists under REVIEW each use of unchecked concurrency, which must wrap a dependency as `style.md#concurrency` allows.

A review copies this checklist into the response:

```
- [ ] Run scripts/check_boundaries.sh and scripts/check_style.sh from the repository root and swift format lint (references/style.md#formatting), and settle each REVIEW line
- [ ] Each feature passes the boundary tests (references/modules.md#defining-features) and owns all its screens; the shared package holds nothing only one feature uses
- [ ] Each screen: one view model, built by its XScreen, over its own service protocol and ports; work no screen starts is its owner's lifetime service (references/domain.md#lifetime-services)
- [ ] The code reads as references/style.md sets out: one do per path, no helpers, build then call, unchecked concurrency only where a dependency needs it
- [ ] Hand-rolled schemes where a standard or a proven approach exists (references/decisions.md#the-established-approach-first)
- [ ] The code inside the shapes with its related skills: names and each module's API with swift-api-design-guidelines-skill, views with swiftui-pro, loads and live services with swift-concurrency-pro, tests with swift-testing-pro, stored data with swiftdata-pro if it's SwiftData
- [ ] Security, performance and correctness with code-review (references/related-skills.md)
- [ ] Findings ranked blocking (the build, a boundary, a credential in source), major (shapes), minor (naming, layout, style), each with a file and line or an empty grep, the rule it breaks and the fix; change code only when the user asks
- [ ] scripts/xcode_ci.sh test for each package and build for the app; report each result, or why it couldn't run
```

## Moving an app into packages

An app built another way keeps its structure until the user asks to change it. A change there follows the app's own layout and conventions, and takes a shape from this skill only where the app has none of its own. A new app, or one already in packages, follows this skill throughout.

Restructuring moves the app in steps that each leave it building. Copy this checklist into the response:

```
- [ ] Map the app: its platforms and their minimum versions, from its project (references/decisions.md#always-asked); its capabilities (a feature each, by the boundary tests in references/modules.md#defining-features), their screens, and what two features already share
- [ ] Networking if the app calls an API, DesignSystem if it has a visual language of its own, then the shared package with only what two features already share; build the app after each
- [ ] One feature at a time, the one using the fewest others first so it needs the fewest ports, as in SKILL.md's Add a feature: its reach into other features becomes destinations and ports, and the code still in the app target switches to its public API
- [ ] As screens leave the app target, their services move into <AppName>App.init and their navigation into Router, Destination, DestinationView and navigationDestinations()
- [ ] After each step, SKILL.md's Verify; fix and repeat until it passes
```

- A step that would leave the app unbuildable is split into smaller ones, never left half done.
- A networking singleton splits as it moves: its requests, decoding and error classification become the client and its error in Networking, and what it does with the answers moves into the live services of the features that call it, each as its feature moves. Until its last caller leaves the app target, it stays there as a thin layer over the client.
