---
name: swiftui-architect
description: Architects and checks modular SwiftUI apps. Use when adding a feature or screen, modularizing an app, designing services, view models or navigation, or placing types, even if no architecture is named.
license: MIT
metadata:
  author: Zaid Rahhawi
  tags: swift, swiftui, ios, architecture, modularization
---

# SwiftUI Architect

## Purpose

Decides where code lives in a modular SwiftUI app, who owns it, the shape of the pieces that hold it together and how the code reads: modules, domain models, services, view models, views, app composition, navigation, naming and style.

Its shapes override other skills' patterns; what fills them comes from the related skills, a search and the user ([decisions.md](references/decisions.md)).

`X` stands for a feature (`Catalog`) or a screen (`MovieCast` → `MovieCastViewModel`, `MovieCastView`, `MovieCastScreen`), a tab's root screen named for its tab ([inside a feature](references/modules.md#inside-a-feature)). A *screen* is one navigable page; its feature exports the view.

An app built another way keeps its structure and conventions until the user asks to change them, taking a shape from this skill only where it has none.

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
│   XCore       domain models, errors, a service protocol and mock per screen
│   XUI         view models, views, XDestination, strings
│   X<Source>   an adapter target per source, an API (CatalogTMDB), a store or an SDK: live services
└── Below the features
    Shared        Shared: domain vocabulary several features use
                  SharedUI: views several features show, SharedDestination
                  Shared<API>: mappings and client steps several features share
    DesignSystem  the app's own tokens, styles and components, if any
    Networking    each API's types and client, if any
```

## Dependency direction

Each module imports only what its arrow names; nothing points back up.

```
App         → XCore, XUI, adapter targets, Shared, SharedUI, DesignSystem, Networking
XUI         → XCore, Shared, SharedUI, DesignSystem, UI frameworks
X<Source>   → XCore, Shared, its source (Networking and Shared<API> for an API)
XCore       → Shared, what Core may link
X…Tests     → the target they test, and what their tests name
SharedUI    → Shared, DesignSystem, UI frameworks
Shared<API> → Shared, Networking
Shared      → what Core may link
DesignSystem, Networking → Apple frameworks and their own dependencies
```

Hard rules:
- A feature never imports another. Features meet only in the app: links through its destination mapping, data through ports it implements.
- XCore and Shared link no UI framework or infrastructure; any other library passes [what Core may link](references/modules.md#what-core-may-link).
- A source's types never leave its adapter targets, which map them to domain models and its errors to the feature's.
- DesignSystem knows no feature's models, services or destinations.

## Who owns what

| Concern | Owner |
|---|---|
| State several features share (the watchlist, a signed-in account) | One feature owns it; the others reach it through ports |
| The client and services, injected through environment keys; each screen and its view model | App: `<AppName>App.init`; an `XScreen` per screen |
| Navigation state; which screen each destination shows | App: a `Router` per window, `Destination`, `DestinationView` |
| What a screen presents, the value a presentation is about, a sheet's draft | Its view model, as plain `var`s its views bind |
| Work no screen starts, such as sync | The feature whose data it changes: a [lifetime service](references/domain.md#lifetime-services) the app starts |

## Principles

1. **Features are capabilities**, never a screen, a tab or a model other features show; each owns every screen of its capability, tab roots included, and what they share ([defining features](references/modules.md#defining-features)).
2. **Every module builds, previews and tests on its own**, XUI on XCore's mocks.
3. **Native SwiftUI navigation by default**: no navigation library or wrapper views around stacks unless the user asks.
4. **One screen per kind of content.** Things that load, page and search alike share a screen; things that differ get their own, never one screen that switches on its input.

## The shapes in brief

- **Models speak the app's language.** Domain models are `Equatable`, `Sendable` values shaped for what a screen shows, unable to hold an illogical value (`Movie`; `MovieSummary` in a list). A feature's error enum is cased by what its screens show (`offline`, `notFound`, `unavailable`); an empty answer is never an error.
- **Services do the work.** One `Sendable` protocol per screen in XCore returns view-ready domain values (`Page<Item>` when paged) and throws the feature's error; an adapter target implements it over one source. No repository, use case or manager sits between a service and its view model.
- **View models hold state.** `@MainActor @Observable public final class XViewModel` per screen, taking IDs and services and assigning what they return. Each resource has its data, `isLoading…` and `…Error`; a paged one adds `next…Page`, `isLoadingNext…Page` and `next…PageError`. A part only some views read, with its own input or loading, is a nested `@Observable` model, never a `…ViewModel`.
- **Views stay plain**: no routers, navigation closures or service lookups. `XView` owns the view model as its only `@State`, puts it in the environment and starts the loads. `XPhaseView` picks what the loads' state shows, and `XContentView` lays out the values it's given.
- **Navigation.** Views push their feature's `XDestination` cases, or `SharedDestination` for places several features open, with `NavigationLink(value:)`; the app supplies only the screens they present.

## Code style

Code reads like the requirement it implements, with Apple's WWDC sample code as the bar ([style.md](references/style.md)):
- Build, then call: outside a view's body, a value a call takes is a named `let`, and `try` or `await` never sits in an argument.
- One `do` holds a live service's path through its `return`, each `catch` ends its own, and nothing is declared before the `do` for a `catch` to fill.
- No helper methods in live services or mappings; no `Result` juggling, steering flags, `try?` or force unwraps.
- A `Task {}` starts only in a view's action or `<AppName>App.init`; unchecked concurrency only where a dependency needs it.

## Troubleshooting

- Only stack roots apply `navigationDestinations()`, and every one does: a link whose type no stack registers does nothing, and a feature screen's registration repeats when it appears twice in a stack.
- `XScreen` builds a view model on every `body` pass and `XView` keeps the first, so its `init` only assigns.
- A service left off the `Scene` falls back to its key's mock, and its screen shows sample data: `<AppName>App` injects every key.

## Prerequisites

- Xcode 27 or later (Swift 6.4) and simulators for the app's platforms ([testing](references/modules.md#testing)).
- Web access for the search ([decisions.md](references/decisions.md)).
- The [related skills](#related-skills) `system-design`, `architecture`, `code-review`, `swift-api-design-guidelines-skill`, `swiftui-pro`, `swift-concurrency-pro`, `swift-testing-pro` and `swiftdata-pro`.

## Available Scripts

| Script | Purpose | Arguments |
|---|---|---|
| `scripts/xcode_ci.sh` | Builds or tests for each platform declared, failing on an owned warning | `<build\|test> <scheme> [arguments…]` from the package's or app's folder |
| `scripts/check_boundaries.sh` | Boundaries the compiler can't check | None; from the repository root |
| `scripts/check_style.sh` | The style rules a script can see | None; from the repository root |

## Limitations

- Not covered: visual design, accessibility, and targets beyond the app, such as widgets and extensions; ask the user ([decisions.md](references/decisions.md#always-asked)).

## References

| Reference | Read when |
|---|---|
| [modules.md](references/modules.md) | Feature boundaries, targets, what Core may link and the package template; placing a type, the shared package, DesignSystem; strings; testing, reviews; moving an app into packages |
| [domain.md](references/domain.md) | Models, errors, services, mocks, ports and their names; shared state; stored data; work no screen starts |
| [networking.md](references/networking.md) | Adding an endpoint; the API client and its errors |
| [view-models.md](references/view-models.md) | Loading, several resources, paging, keys, filtering, nested models, modes, tests |
| [views.md](references/views.md) | The `XView` family, error and empty states, paging footers, modes, passing data, previews |
| [composition.md](references/composition.md) | The app target: `<AppName>App`, environment keys, `ContentView`, `XScreen` |
| [navigation.md](references/navigation.md) | Destinations, linking features, deep links, push or present, sheets, alerts |
| [style.md](references/style.md) | Writing or reviewing any Swift outside a view's body |
| [conventions.md](references/conventions.md) | Naming a type, file or folder |
| [decisions.md](references/decisions.md) | Before designing; recording a pick; a dependency's warning |
| [related-skills.md](references/related-skills.md) | Installing the related skills; where this skill wins |

## Related skills

[related-skills.md](references/related-skills.md): each task's skill, installing them, and where this skill wins.

## Instructions

Copy the task's checklist into the response, **Verify**'s lines for its `Verify` item, and tick items when done. A line naming a related skill invokes it with the Skill tool there ([installing them](references/related-skills.md#installing-them)).

**Add a feature**

```
- [ ] Check the capability is new (references/modules.md#defining-features); a screen showing what a feature owns joins it (Add a screen)
- [ ] Search online and ask what's always asked (references/decisions.md); design with system-design, open choices with architecture
- [ ] Packages/X, named for the capability: XCore, XUI, an adapter target per source, a test target per tested target (references/modules.md#feature-packages)
- [ ] XCore, with swift-api-design-guidelines-skill: models, XError, and per screen a service protocol and mock (`.mock`)
- [ ] Networking: a client method per endpoint it calls
- [ ] Adapter targets, with swift-concurrency-pro: a live service per protocol, mapping its source's values to the domain and errors to XError; stored data with swiftdata-pro if it's SwiftData
- [ ] XUI, with swiftui-pro and swift-concurrency-pro: XViewModel, XView, XPhaseView, XContentView, XDestination, Localizable.xcstrings; push places another feature already links to as `SharedDestination`
- [ ] Test targets, with swift-testing-pro: the screens' own rules and the mappings (references/modules.md#testing)
- [ ] App: add the package to the app's project or its manifest, linking XCore, XUI and the adapter targets
- [ ] App: per service protocol, an environment key, the service built in <AppName>App.init and injected on the Scene
- [ ] App: an XScreen per screen but a tab's root screen, presented ones included; Destination and DestinationView cases; Destination.init(_: XDestination) and its line in navigationDestinations()
- [ ] App, for a tab's root screen: a TabDestination case, its Tab in ContentView, and a tab XScreen owning the stack, with navigationDestinations() at its root
- [ ] Verify
```

**Add a screen**

```
- [ ] Search online and ask what's always asked (references/decisions.md), then design with system-design
- [ ] XCore, with swift-api-design-guidelines-skill: the screen's models, service protocol and mock; Networking and the adapter target, with swift-concurrency-pro: its client methods and live service
- [ ] XUI, with swiftui-pro and swift-concurrency-pro: the screen's folder with its view model and views; an XDestination case, pushed with NavigationLink(value:)
- [ ] XUI: a section another screen of the feature already shows moves to Components/, named for what it is
- [ ] Tests, with swift-testing-pro: the screen's own rules, such as paging, and its mappings
- [ ] App: environment key, service built and injected; XScreen; Destination case, mapping and DestinationView case
- [ ] Verify
```

**Modularize an existing app**: the checklist in [moving an app into packages](references/modules.md#moving-an-app-into-packages).

**Add search**: across the app → a Search feature; through what a screen shows → [a filter](references/view-models.md#filtering-loaded-values); on the server, in one screen → a `SearchSession` [mode](references/view-models.md#modes).

**Verify**

```
- [ ] scripts/xcode_ci.sh test for each changed package, and build for the app (references/modules.md#testing)
- [ ] scripts/check_boundaries.sh and scripts/check_style.sh, and swift format lint (references/style.md#formatting)
- [ ] Each skill the checklist names was invoked with the Skill tool, or reported as skipped
- [ ] Each pick is recorded with its reason and sources (references/decisions.md#recording-a-decision)
- [ ] Fix and repeat until all pass; a concurrency diagnostic goes through swift-concurrency-pro, never silenced; a dependency's warning is a departure (references/decisions.md#warnings-from-dependencies)
```

**Link one feature to another**: the checklist in [linking two features](references/navigation.md#linking-two-features).

**Review an app**: the checklist in [checking the boundaries](references/modules.md#checking-the-boundaries).

**Add work no screen starts**: the checklist in [lifetime services](references/domain.md#lifetime-services).

**Decide where a type belongs**: the steps in [placing a type](references/modules.md#placing-a-type).
