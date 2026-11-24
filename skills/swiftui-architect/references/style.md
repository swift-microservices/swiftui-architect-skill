# Swift style

How the code inside the shapes reads: the bar for readability, building values, errors, concurrency, access control and imports, types and values, documentation and formatting. A view's body and its modifiers follow `swiftui-pro`, and test code `swift-testing-pro` (`related-skills.md`); every other line follows this file.

## Contents
- Reading like the requirement
- Build, then call
- Errors
- Concurrency
- Access control and imports
- Types and values
- Documentation comments
- Formatting

## Reading like the requirement

The bar is the sample code in Apple's WWDC sessions: small types named for their role, straight-line async code, early exits, nothing clever.

- A live service's method, a view model's action and an app adapter read top to bottom as what the screen needs: ask the source, map the answer, then return it or assign it.
- No helper methods in live services, mappings or app adapters. A step that deserves a name is a model's initializer or method (`Movie(response)`), a client step (`domain.md#live-services`) or a service of its own. A view model's private methods are its resources' loads (`view-models.md#several-resources`) and the matches a filter keeps (`view-models.md#filtering-loaded-values`), nothing else.
- No workarounds: no `Result` juggling, flags that steer control flow, `try?` that hides a failure, force unwraps or `as!`.
- `guard` for refusals and unwrapping, with the `else` doing one thing. `switch` over every case of an enum, with no `default`, so a new case fails the build wherever it isn't handled.
- Names say what a value is: `shelves`, `isLoadingShelves`, `nextShelvesPage`; never `result`, `data`, `flag` or a type's name.
- A number is named as a static on the type whose rule it is, never an inline literal in a view model, a live service or a view's task.
- Code a reader would otherwise check twice gets a one-line comment with the reason. A comment never narrates the next line.

## Build, then call

Outside a view's body, a value a call takes is built first, in a `let` named for what it is, and the call takes the name. A mapping to a page:

```swift
let items = response.results.compactMap(MovieSummary.init)
let nextPage = response.page < response.totalPages ? response.page + 1 : nil
self.init(items: items, nextPage: nextPage)
```

- Arguments are names, literals, properties, closures, key paths, static members built from those (`.mock(.failure(.offline))`, `.movieDetail(id: movie.id)`) and initializers over constants.
- Anything else is a `let` first: an initializer that takes a variable, a conversion, a method's result, a `try` or an `await`.
- In a view's body too, `try` and `await` never sit inside an argument.

## Errors

What a service throws is set in `domain.md#service-protocols`; these rules cover the code that maps it.

- A live service and an app adapter map errors with one `do` that holds the whole path, from the first call through its `return`, and one `catch` per case they map (`domain.md#live-services`). Each `catch` ends its path by throwing; nothing is declared before the `do` for a `catch` to fill, and no code follows the `do`.
- A view model's load is the one shape that sets state after its `do`: it clears `isLoading…` for success and failure alike, and its `catch is CancellationError` returns first (`view-models.md#the-shape`).
- A `do` never nests inside a `catch`.

## Concurrency

Every package builds with the template's settings (`modules.md#packageswift-template`). The code inside these rules, such as an actor's design, a task group, isolation and cancellation, follows `swift-concurrency-pro`.

- Everything that crosses an actor or a module is `Sendable`: models, errors, destinations, service protocols. Structs and enums by default; an actor only for mutable state several tasks share, such as a live service or a mock that keeps state; `Mutex` from `Synchronization` for a small piece of state touched synchronously.
- No `@unchecked Sendable`, `nonisolated(unsafe)` or `@preconcurrency` in owned code. When a dependency needs one, it appears once, in the target that wraps the dependency, with the reason on the line above and, under strict memory safety, its use marked `unsafe`.
- Work starts from structured tasks: a screen's loads from SwiftUI's `.task`, `.task(id:)` and `.refreshable` (`views.md#xview-xphaseview-and-xcontentview`), and a lifetime service from the app (`domain.md#lifetime-services`). An unstructured `Task` appears only where SwiftUI gives no async context, such as a button's action or `<AppName>App.init`, so never in XCore, Shared or an adapter target. Never `Task.detached` or `DispatchQueue`.

## Access control and imports

- What the app or another package uses is `public`; what another target of the same package uses, such as a mapping its test target reaches, is `package` (`modules.md#feature-packages`); the rest is internal or `private`.
- A `public` or `package` type that another module builds spells its init at that level.
- Access levels go on members, never on an extension.
- Imports are internal by default. A file imports a module `public` when its `public` declarations use the module's types, `package` when its `package` ones do, and plainly otherwise.
- A file imports every module whose members it uses, since `MemberImportVisibility` hides the rest.

## Types and values

- Models and destinations are values: structs of `let` properties, and enums for closed sets (`domain.md#domain-models`).
- Absence is an optional, never a sentinel such as `""`, `-1` or `.distantPast`: a mapping turns the API's empty value into `nil`.
- A calendar date, such as a movie's release date, is a value of year, month and day, never a `Date` at midnight. Instants are `Date`, durations `Duration`, and a `TimeInterval` appears only in a `Date`'s arithmetic.
- Protocols exist only where substitution is real: service protocols and ports. Models, mappings, destinations and view models are concrete. There is no clock or id-generator protocol: code that decides on time reads `Date.now` once and passes it to the model's method that holds the rule, which a test calls with any instant.
- Stored dependencies are existentials (`any MovieDetailService`). Parameters are opaque where they can be, and a type is generic only where the compiler must check a constraint on it, such as a view that takes another view (`WatchlistView<Presented: View>`).

## Documentation comments

- `///`, starting with a one-line summary; a following paragraph says why, or what a caller must know.
- Every service protocol says what its screen shows, and every port what its feature needs from the owner; every view model, what its screen is for.
- A name that says everything gets no comment.

## Formatting

- The Swift toolchain's `swift-format` formats the packages and the app with one `.swift-format` at the repository's root, and `swift format lint --strict --recursive` over every target's sources passes. An app that already formats with another tool keeps it.
- `.swift-format` sets four-space indentation and 120-column lines; a line break before each argument of a call or declaration that wraps, respecting existing line breaks; and trailing commas in multi-element collections.
- It sets no `rules`, so the default rules stay on: a `rules` map turns off every rule it doesn't name.
