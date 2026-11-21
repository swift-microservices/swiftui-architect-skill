---
name: swiftui-architect
description: Architects modular SwiftUI apps. Use when adding a feature or screen, modularizing an iOS app, designing services, view models or navigation, or placing a type, even if no architecture is named.
license: MIT
metadata:
  author: Zaid Rahhawi
  tags: swift, swiftui, ios, architecture, modularization
---

# SwiftUI Architect

## Purpose

Decides where code lives in a modular SwiftUI app, who owns it, and the shape of the pieces that hold it together: modules, domain models, services, view models, views, app composition, navigation and naming.

A shape this skill states, such as a view model's state or `XView`'s `.task`, overrides other skills' patterns; the code inside it follows the [related skills](#related-skills).

`X` stands for a feature (`Catalog`) or a screen (`MovieCast` → `MovieCastViewModel`, `MovieCastView`, `MovieCastScreen`); a tab's root screen is named for its tab (`DiscoverView`), anything else for what it is ([inside a feature](references/modules.md#inside-a-feature)). A *screen* is one navigable page; its feature exports the view.

An app built another way keeps its structure and conventions until the user asks to change them, taking a shape from this skill only where it has none.

## Prerequisites

- Xcode with Swift 6.4 or later, whose SDK has the APIs the shapes use ([the template](references/modules.md#packageswift-template)).
- An iOS Simulator runtime for `xcodebuild`; `swift build` and `swift test` build for the Mac ([testing](references/modules.md#testing)).
- Apple's swift-openapi-generator, when the API has an OpenAPI document ([networking.md](references/networking.md)).
- The [related skills](#related-skills) `swiftui-pro`, `swift-concurrency-pro`, `swift-testing-pro` and `swiftdata-pro`; ask the user once to install a missing one (`npx skills@1.9.0 add <source> --skill <name>`) and carry on.

## Examples

The examples are one movie browser on the TMDB API:

| Feature | Screens |
|---|---|
| Discover | The Discover tab: featured movies over paged shelves. A genre's movies, with a search in them |
| Catalog | A movie's details, with a watchlist button, and cast. A person's details and credits by department |
| Search | The Search tab, with a filter sheet |
| Watchlist | The Watchlist tab, with a search through it and a confirmation before removing a movie |
| Account | Signing in, over the Watchlist tab |

## The shape

```
App target            composition root: services, screens, routing
├── Feature packages  one per capability (Discover, Catalog, Search, …)
│   XCore     domain models, errors, a service protocol and mock per screen
│   XUI       view models, views, XDestination, strings
│   XLive     live services: API responses → domain models
│   XTests    view model and mapping tests
└── Below the features
    Shared        Shared: domain vocabulary several features use (Foundation only)
                  SharedUI: views several features show, SharedDestination
                  SharedLive: API mappings and client steps several features share
    DesignSystem  domain-free tokens, styles and components
    Networking    the API's types and client, generated when the API has an OpenAPI document
```

## Dependency direction

Each module imports only what its arrow points at; nothing points back up.

```
App        → XCore, XUI, XLive, Shared, SharedUI, DesignSystem, Networking
XUI        → XCore, Shared, SharedUI, DesignSystem
XLive      → XCore, Shared, SharedLive, Networking
XCore      → Shared
XTests     → XCore, XUI, XLive, Shared, SharedUI, Networking
SharedUI   → Shared, DesignSystem
SharedLive → Shared, Networking
Shared, DesignSystem, Networking → Apple frameworks and their own dependencies
```

Hard rules:
- A feature never imports another. Features meet only in the app: links through its destination mapping, data through ports it implements.
- XCore never imports SwiftUI or Networking.
- Generated API types and stored models (`@Model`) never leave the Live targets (XLive, SharedLive), which map them to domain models and their errors to the feature's errors.
- DesignSystem knows no domain: no feature models, services or destinations.

## Who owns what

| Concern | Owner |
|---|---|
| State several features share (the watchlist, a signed-in account) | One feature owns it; the others reach it through ports |
| The client and services, injected through environment keys; each screen and its view model | App: `<AppName>App.init`; an `XScreen` per screen |
| Navigation state; which screen each destination shows | App: a `Router` per window, `Destination`, `DestinationView` |
| What a screen presents, the value a presentation is about, a sheet's draft | Its view model, as plain `var`s its views bind |

## Principles

1. **Features are capabilities**, never a screen, a tab or a model other features show; each owns every screen of its capability, every tab's root screen included, and what they share ([defining features](references/modules.md#defining-features)).
2. **Duplicate before sharing** until a second feature needs the same concept and both copies must change together.
3. **Every module builds, previews and tests on its own**, XUI on XCore's mocks.
4. **Native SwiftUI and Apple's frameworks only**: no navigation libraries, DI containers or wrapper views around stacks.
5. **One screen per kind of content.** Things that load, page and search alike share a screen; things that differ get their own, never one screen that switches on its input.

## The shapes in brief

- **Models speak the app's language.** Domain models are `Equatable`, `Sendable` values shaped for what a screen shows, unable to hold an illogical value (`Movie`; `MovieSummary` in a list). A feature's error enum is cased by what its screens show (`offline`, `notFound`, `unavailable`); an empty answer is never an error.
- **Services do the work.** One protocol per screen in XCore returns view-ready domain values (`Page<Item>` when paged) and throws the feature's error; XLive implements it. No repository, use case or manager sits between a service and its view model.
- **View models hold state.** `@MainActor @Observable public final class XViewModel` per screen, taking IDs and services and assigning what they return. Each resource has its data, `isLoading…` and `…Error`; a paged one adds `next…Page`, `isLoadingNext…Page` and `next…PageError`. A part only some views read, with its own input or loading, is a nested `@Observable` model, never a `…ViewModel`.
- **Views stay plain**: no routers, navigation closures or service lookups. `XView` owns the view model as its only `@State`, puts it in the environment and starts the loads. `XPhaseView` picks what the loads' state shows, and `XContentView` lays out the values it's given.
- **Navigation.** Views push their feature's `XDestination` cases with `NavigationLink(value:)`, or `SharedDestination` for places several features open, and take from the app only the screens they present, which are cases too.
- **Concurrency.** Swift 6 mode: services are `Sendable`, a struct live service's methods `@concurrent`, stateful services and mocks actors.

## Common Issues

- Register destinations only at stack roots, every type through `navigationDestinations()`: a feature screen's registration runs again when the screen appears twice in a stack, and SwiftUI reports a duplicate.
- `XScreen` builds a view model on every `body` pass and `XView` keeps the first, so its `init` only assigns.
- A string literal in a package looks in the app's bundle; use the catalog's generated symbols.
- Never set `.defaultIsolation(MainActor.self)` in a package: generated OpenAPI code doesn't build under it, and domain types must stay nonisolated.
- A type named like an SDK type (`Collection`, `Section`) is ambiguous where both are imported; qualify it (`MovieCollection`).

## References

| Reference | Read when |
|---|---|
| [modules.md](references/modules.md) | Feature boundaries; packages and `Package.swift`; what a feature's screens share; the shared package, DesignSystem; strings, assets, fonts; building, testing, reviews; moving an app into packages |
| [domain.md](references/domain.md) | Models, errors, services, mocks, ports and their names; shared state; stored data |
| [networking.md](references/networking.md) | Adding an endpoint; the API client and its errors |
| [view-models.md](references/view-models.md) | Loading, several resources, paging, keys, filtering, nested models, modes, tests |
| [views.md](references/views.md) | The `XView` family, error and empty states, paging footers, modes, passing data, previews |
| [composition.md](references/composition.md) | The app target: `<AppName>App`, environment keys, `ContentView`, `XScreen` |
| [navigation.md](references/navigation.md) | Destinations, linking features, deep links, push or present, sheets, alerts |
| [conventions.md](references/conventions.md) | Naming a type, file or folder |

## Available Scripts

| Script | Purpose | Arguments |
|---|---|---|
| `scripts/check_boundaries.sh` | Boundaries the compiler can't check | None; from the app's repository root |

## Instructions

Copy the task's checklist into the response and check items off as they're done.

**Add a feature**

```
- [ ] Check the capability is new (references/modules.md#defining-features); a screen showing what a feature owns joins it (Add a screen)
- [ ] Packages/X, named for the capability: XCore, XUI, XLive, XTests (template in references/modules.md)
- [ ] XCore: models, XError, and per screen a service protocol and mock (`.mock`)
- [ ] Networking: a client method per endpoint, first in openapi.yaml or the generator's filter if generated
- [ ] XLive: a live service per protocol, mapping responses to the domain and the client's error to XError
- [ ] XUI: XViewModel, XView, XPhaseView, XContentView, XDestination, Localizable.xcstrings; push places another feature already links to as `SharedDestination`
- [ ] XTests: the screen's own rules, with actor stubs, and mappings (references/view-models.md#testing-view-models)
- [ ] App: add the package to the Xcode project, linking XCore, XUI, XLive
- [ ] App: per service protocol, an environment key, the service built in <AppName>App.init and injected on the Scene
- [ ] App: an XScreen per screen but a tab's root screen, presented ones included; Destination and DestinationView cases; Destination.init(_: XDestination) and its line in navigationDestinations()
- [ ] App, for a tab's root screen: a TabDestination case, its Tab in ContentView, and a tab XScreen owning the stack, with navigationDestinations() at its root
- [ ] Build the feature's scheme and the app, and run its tests; fix and repeat until both pass
```

**Add a screen**

```
- [ ] XCore: the screen's models, service protocol and mock; Networking and XLive: its client methods and live service
- [ ] XUI: the screen's folder with its view model and views; an XDestination case, pushed with NavigationLink(value:)
- [ ] XUI: a section another screen of the feature already shows moves to Components/, named for what it is
- [ ] XTests: the screen's own rules, such as paging, and mappings
- [ ] App: environment key, service built and injected; XScreen; Destination case, mapping and DestinationView case
- [ ] Build the feature's scheme and the app, and run its tests; fix and repeat until both pass
```

**Modularize an existing app**: copy the checklist in [moving an app into packages](references/modules.md#moving-an-app-into-packages).

**Add search**: across the app → a Search tab, usually its own feature. Through what a screen shows → XViewModel [filters the loaded values](references/view-models.md#filtering-loaded-values). On the server, in one screen → a `SearchSession` [mode](references/view-models.md#modes) nested in XViewModel.

**Link one feature to another** (Watchlist opens sign-in)

```
- [ ] Place: a `SharedDestination` case if one exists; else move another feature's XDestination case there with its mapping; else a new case in the source's XDestination (`.signIn`)
- [ ] Source: push it with NavigationLink(value:), or present it from XView if the design shows it over the screen (references/navigation.md#presenting-a-screen)
- [ ] Data another feature owns (Catalog asks Watchlist if a movie is kept): a port in the source's XCore, with a mock
- [ ] App, for a port: an adapter over the owner's service (which gains what the port needs), built in <AppName>App.init, injected by environment key, passed by the source's XScreen
- [ ] App, for a new case: its mapping in Destination.init(_: SourceDestination); the source's XDestination in navigationDestinations() if new
- [ ] App, for a presented place: the source's XScreen passes DestinationView to its XView
- [ ] Build every changed package and the app, and run their tests; fix and repeat until they pass
```

**Review an app's architecture**: `scripts/check_boundaries.sh`, then the checklist in [checking the boundaries](references/modules.md#checking-the-boundaries).

**Decide where a type belongs**

1. Used by one feature, from any of its screens → that feature: XCore for models and contracts, XUI for anything visual or localized, XLive for mapping.
2. Needed by a second feature, both changing together → Shared for a model, SharedUI for a view, SharedLive for a mapping to a Shared model or a client step both call.
3. Only looks alike → duplicate it.
4. Visual and domain-free → DesignSystem; talks to the API → Networking; wires features together → the app.

## Limitations

- Not covered: visual design, accessibility, and targets beyond the app, such as widgets and extensions; ask the user rather than invent a shape.

## Related skills

Load each when its task comes up:
- View bodies, modifiers, layout, data flow, navigation and presentation APIs, localization, previews, performance: `swiftui-pro` ([source](https://github.com/twostraws/SwiftUI-Agent-Skill))
- Load bodies, stale-result guards, task groups, cancellation, actors, `Sendable` and strict-concurrency diagnostics: `swift-concurrency-pro` ([source](https://github.com/twostraws/Swift-Concurrency-Agent-Skill))
- Test code: Swift Testing suites, `#expect`, traits, parameterized and async tests: `swift-testing-pro` ([source](https://github.com/twostraws/Swift-Testing-Agent-Skill))
- SwiftData models, predicates and fetches in a live service: `swiftdata-pro` ([source](https://github.com/twostraws/SwiftData-Agent-Skill))
