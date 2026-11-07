# View models

A view model loads what one screen shows and exposes it as state. Services do the work (mapping and aggregation) and return view-ready domain values; the view model assigns them and tracks loading, errors and paging. How to write the loads inside these shapes (tasks, isolation, task groups) is a Swift Concurrency skill's subject ([related skills](../SKILL.md#related-skills)).

## Contents
- The shape
- One resource: data, activity and error
- Several resources
- Pagination
- A thing and its paged list
- Keyed resources
- Filtering loaded values
- Nested models and modes
- Testing view models

## The shape

```swift
/// Everyone credited in a movie.
@MainActor
@Observable
public final class MovieCastViewModel {
    private let movieID: MovieSummary.ID
    private let service: any MovieCastService

    // Cast
    private(set) var cast: [CastMember] = []
    private(set) var isLoadingCast: Bool = true
    private(set) var castError: CatalogError?

    public init(movieID: MovieSummary.ID, service: any MovieCastService) {
        self.movieID = movieID
        self.service = service
    }

    func load() async {
        isLoadingCast = true

        do {
            cast = try await service.cast(movieID: movieID)
            castError = nil
        } catch is CancellationError {
            return
        } catch {
            castError = error as? CatalogError ?? .unavailable
        }

        isLoadingCast = false
    }
}
```

- `@MainActor @Observable public final class`, one per screen, pushed, presented or a tab's root. A part of a screen gets a [nested model](#nested-models-and-modes) instead.
- `public init` takes IDs and services and only assigns. The app builds a view model on every `body` pass and the view keeps the first, so `init` starts no tasks, subscriptions or I/O.
- State is `private(set)`, except three kinds of plain `var` that views bind or set ([presentations](navigation.md#sheets-covers-and-alerts)):
  - input, such as a search field's `text`
  - what the screen presents (`isFilterPresented`), or the value a presentation is about (`itemToRemove`)
  - a draft that a sheet edits before it's applied (`filterDraft`)
- Actions are internal imperative verbs the views call: `load()`, `refresh()`, `loadNextShelvesPage()`, `select(_:)`.
- It stores what the service returns as it is: no data processing, navigation, views, display strings or other features. The one exception is a search through loaded values, which keeps the ones that match ([filtering](#filtering-loaded-values)).
- `load()` is safe to call again, for a retry or the view reappearing, with no `loadIfNeeded()` variant or "already loaded" flag. A screen with a paged list is the exception ([coming back to a paged list](#coming-back-to-a-paged-list)).

## One resource: data, activity and error

A screen can have data while it refreshes, data and a failed refresh, or an error while it retries. One `idle / loading / loaded / failed` enum can't hold two of these at once, so each resource gets three plain properties, with no shared state type:

| Property | Holds |
|---|---|
| The data, named for what it is (`cast`, `movie`) | An empty collection, or `nil` for a single value, until the first successful load. A failed refresh keeps it |
| `isLoading…` (`isLoadingCast`) | Whether its load is running. It starts `true` when the screen loads it on appearing, so the first frame shows progress rather than the empty state |
| `…Error` (`castError`) | The error its views switch over, usually the feature's `XError` ([domain](domain.md#errors)) |

- A load sets `isLoading…` when it starts and clears it when it succeeds or fails. On success it assigns the data and clears the error. On failure it keeps the data and records the error, so the error stays on screen through a retry until a load succeeds.
- An error that isn't the property's type records the type's fallback case (`.unavailable`).
- Cancellation is never a failure: a cancelled load returns without changing anything, `isLoading…` included. `XView` runs `load()` from `.task`, which cancels it when the view disappears and runs it again, as a silent refresh, when the view reappears ([views](views.md#xview-xphaseview-and-xcontentview)); that load, or a new key's, ends the loading. A cancelled load can finish after its replacement starts, so a `defer` that clears `isLoading…` would hide the progress of the load still running. The networking client delivers a cancelled request as `CancellationError` ([networking](networking.md#errors-and-cancellation)).
- A load never guards against a call already in flight. Overlapping loads fetch the same data, so the last to finish wins, and a guard would block a load that `.task` restarted, such as a paging footer's after it scrolls out and back in.
- A resource keeps only the state its views read. One the screen leaves out when it fails, such as Discover's featured movies, keeps just its data: its load assigns on success and does nothing on failure.

## Several resources

When a screen loads more than one resource, each gets its own properties and load method. The phase view follows the resource the content can't do without; the others show when they arrive and are left out when they fail. Discover shows featured movies over a paged list of shelves, and follows the shelves:

```swift
public protocol DiscoverService: Sendable {
    /// - Throws: `DiscoverError`. Cancellation propagates as `CancellationError`.
    func featured() async throws -> [MovieSummary]

    /// - Throws: `DiscoverError`. Cancellation propagates as `CancellationError`.
    func shelves(page: Int) async throws -> Page<DiscoverShelf>
}

/// Featured movies over shelves of movies, paged in as the last shelf comes into view.
@MainActor
@Observable
public final class DiscoverViewModel {
    private let service: any DiscoverService

    // Featured
    private(set) var featured: [MovieSummary] = []

    // Shelves
    private(set) var shelves: [DiscoverShelf] = []
    private(set) var isLoadingShelves: Bool = true
    private(set) var shelvesError: DiscoverError?
    private(set) var nextShelvesPage: Int?
    private(set) var isLoadingNextShelvesPage: Bool = false
    private(set) var nextShelvesPageError: DiscoverError?

    public init(service: any DiscoverService) { … }

    /// Loads unless there are shelves, so coming back to Discover keeps the pages it has.
    func load() async {
        guard shelves.isEmpty else {
            return
        }

        await refresh()
    }

    /// Loads the featured movies again, and the shelves from the first page, side by side.
    func refresh() async { … }

    func loadNextShelvesPage() async { … }

    private func loadFeatured() async { … }

    private func loadShelves() async { … }
}
```

- Independent loads run side by side. A resource that depends on another, such as a list picked from the loaded movie, loads after it.
- When a rule spans several resources, such as a screen that shows nothing until two of them load, add computed `isLoading` and `error` for the phase view. Never store them: two loads would write one value.

## Pagination

A paged resource adds three properties to its data, `isLoading…` and `…Error`:

| Property | Holds |
|---|---|
| `next…Page` (`nextShelvesPage`) | The page to ask for next, from the service's `Page<Item>`; `nil` after the last one |
| `isLoadingNext…Page` | Whether the next page is loading |
| `next…PageError` | Why the next page failed, typed like `…Error`. Only the paging footer reads it, to offer a retry |

- Loading the first page replaces the list, sets `next…Page` and clears `next…PageError`.
- `loadNext…Page()` does nothing while `next…Page` is `nil`. Otherwise it asks for that page and appends it only if `next…Page` still names the page it asked for. If it doesn't, a refresh started the list over or another call already appended the page, and the result is dropped.

### Coming back to a paged list

Coming back to a screen runs its `.task` again. Loading the first page again would replace every page the user scrolled through, and the shorter list would bring the footer on screen and load page two at once. So a screen with a paged list guards `load()` on what its phase view follows, usually that list, and moves its loads into `refresh()`, as [Discover does](#several-resources):

- `.refreshable` calls `refresh()`, which starts the list over and loads the screen's other resources again.
- A retry calls `load()`: the error shows only while what the phase view follows is missing, so the guard lets it through.
- A resource beside the list, such as the featured movies, loads again only on a refresh.

## A thing and its paged list

A screen that shows one thing and a paged list belonging to it, such as a genre and its movies, loads them as two resources from the screen's own service:

```swift
/// A genre and its movies, a page at a time.
public protocol GenreDetailService: Sendable {
    func genre(id: Genre.ID) async throws -> Genre
    func movies(genreID: Genre.ID, page: Int) async throws -> Page<MovieSummary>
}

@MainActor
@Observable
public final class GenreDetailViewModel {
    // Genre
    private(set) var genre: Genre?

    // Movies, paged as Discover's shelves are
    private(set) var movies: [MovieSummary] = []
    // isLoadingMovies, moviesError, nextMoviesPage, isLoadingNextMoviesPage, nextMoviesPageError

    // load() guards on movies; refresh() loads the genre and the first page side by side.
}
```

- The thing leaves the list out, so nothing holds two copies of it. Never page a value that contains the list, or pair a page with the thing in a wrapper type or tuple.
- Load the list after the thing only when the thing decides whether there is a list; otherwise load both side by side.
- What the phase view follows depends on what the thing shows:
  - When the thing only titles the screen, as a genre does, the phase view follows the list, and the title goes on `XView` so it stays up in every state.
  - When the thing shows content of its own above the list, the phase view follows the thing, and `load()` guards on it. The list is a section of the content with its own progress, error and paging footer, like a [keyed section](#keyed-resources), and its retry loads the list's first page again.

## Keyed resources

Some resources depend on a key the user changes on the screen: the words in a search, a selected department, a filter. The key is view model state, and the resource starts over whenever it changes:

```swift
/// Shows the person's credits in `department`. They start over, and load from `loadCredits()`.
func select(_ department: Department) {
    guard department != selectedDepartment else {
        return
    }

    selectedDepartment = department
    credits = []
    creditsError = nil
    // The view loads them next, so until then they show as loading rather than as none.
    isLoadingCredits = true
}

/// Loads the credits for the department selected when it starts.
func loadCredits() async { … }
```

- Changing the key is synchronous: it empties the data, clears its error and paging, and sets `isLoading…` when a load follows. The old key's data never shows under the new one.
- A control that picks the key calls `select(_:)` rather than setting the key, so the reset always runs.
- `XView` loads from `.task(id: viewModel.selectedDepartment)`, the first load included; `load()` loads the rest of the screen.
- A load remembers the key it started with. SwiftUI cancels the old key's load, but a response can arrive before the cancellation does, so a load whose key is no longer selected returns as a cancelled one does, dropping its result and its error.
- A keyed resource beside the thing a screen shows, such as the credits under a person's details, is a section of the content, with the control that picks its key, its own progress and its own error. The phase view follows the person, so a new key never blanks the screen.
- A keyed paged list, such as search results, guards its load on the list like a [screen's](#coming-back-to-a-paged-list). A new key empties the list, so the new key's load gets through.
- Typed text is input, not a key: a plain `var` the field binds. `XView` applies it to the key after a pause in typing, and at once on submit or when the field is cleared. The pause is `.task(id: viewModel.text)` sleeping briefly: the next keystroke cancels it, so the text applies only if the sleep ends uncancelled, never after a `try?` that swallows the cancellation.

## Filtering loaded values

Searching what a screen already shows, such as titles in the watchlist, narrows the values it has loaded, and nothing loads. The view model keeps the field's text and the values that match it, and works the matches out again whenever either changes:

```swift
/// The movies kept to watch later, with a search through their titles.
@MainActor
@Observable
public final class WatchlistViewModel {
    // Items
    private(set) var items: [WatchlistItem] = [] {
        didSet { updateMatchingItems() }
    }
    // isLoadingItems, itemsError

    /// The words in the search field.
    var text = "" {
        didSet { updateMatchingItems() }
    }
    /// The items whose movie's title contains the words; all of them while there are none.
    private(set) var matchingItems: [WatchlistItem] = []

    private func updateMatchingItems() { … }
}
```

- Never work the matches out in a view's `body` or in the collection given to `ForEach`: the view model holds them, so the views only read them and tests can check them.
- The matches follow each keystroke, with no pause and no `.task(id:)`, because nothing loads.
- What the phase view shows while nothing matches: [views](views.md#xview-xphaseview-and-xcontentview).

## Nested models and modes

A part of a screen whose state changes on its own, such as a watchlist button or a search within the screen, gets a nested `@Observable` model. The model is declared inside the screen's view model, which makes it in `init` from its own services and holds it as a `let`.

```swift
@MainActor
@Observable
public final class MovieDetailViewModel {
    // The movie and its cast, as in any view model.

    /// Whether the movie is in the watchlist; only the watchlist button reads it.
    let watchlistMembership: WatchlistMembership

    public init(
        movieID: MovieSummary.ID,
        service: any MovieDetailService,
        watchlistMembershipService: any WatchlistMembershipService
    ) {
        self.movieID = movieID
        self.service = service
        self.watchlistMembership = WatchlistMembership(
            movieID: movieID,
            service: watchlistMembershipService
        )
    }
}

extension MovieDetailViewModel {
    /// Whether the movie on screen is in the watchlist. Loads when its button appears.
    @MainActor
    @Observable
    final class WatchlistMembership {
        /// Whether the movie is in the watchlist; `nil` until it loads.
        private(set) var isInWatchlist: Bool?
        /// Whether a toggle is in progress, so the button can't send another.
        private(set) var isUpdating: Bool = false

        init(movieID: MovieSummary.ID, service: any WatchlistMembershipService) { … }

        func load() async { … }
        func toggle(_ movie: MovieSummary) async { … }
    }
}
```

- It uses its view model's services, the screen's own or a port, and never gets a service of its own for being nested.
- Nest a part that only some views read and that has its own input, loading or errors. What the content shows stays on the view model, including a key and what it loads (a selected department and its credits), and so does a single flag or value such as `isFilterPresented`.

### Naming nested models

Name it for the one thing a user would recognize on the screen, as a plain noun that reads in "the screen has a ___":

| What it holds | Noun | Examples |
|---|---|---|
| Input that starts and ends a stretch of work, and what it loads | `…Session` | `SearchSession` |
| A fact about the item on screen that the user can change | the fact | `WatchlistMembership` |

Never `…ViewModel` (screens own that), `…Manager`, `…Controller`, `…Handler`, `…Coordinator` or `…Helper`, `…State` or `…Store`.

### Modes

A mode replaces a screen's content with its own while it's active, driven by its own input: typically a server search scoped to one screen, such as a genre's movies. Search across the app is its own screen instead, and searching what a screen already shows [filters the loaded values](#filtering-loaded-values).

A mode is a nested model made with the screen's service. Its text is input bound to the search field, its key is that text once applied, and its results are a keyed, paged resource:

```swift
extension GenreDetailViewModel {
    /// A search in the genre: what the genre's screen shows while there are words to search for.
    @MainActor
    @Observable
    final class SearchSession {
        /// The words in the search field.
        var text = ""
        /// The words the results are for, once applied. Empty while not searching.
        private(set) var query = ""

        // Results
        private(set) var results: [MovieSummary] = []
        private(set) var isLoadingResults: Bool = false
        private(set) var resultsError: GenreDetailError?
        // nextResultsPage, isLoadingNextResultsPage, nextResultsPageError

        var isActive: Bool {
            !query.isEmpty
        }

        func apply() { … }
        func load() async { … }
        func refresh() async { … }
        func loadNextResultsPage() async { … }
    }
}
```

`GenreDetailService` gains `movies(genreID:matching:page:)` for it, and the screen's phase view picks the mode in its first branch ([views](views.md#modes)). Its `load()` does nothing while `query` is empty, since `.task(id: query)` also runs when the screen appears and when the field is cleared.

## Testing view models

Swift Testing, `@MainActor` suites, `@testable import XUI`, and a private actor stub of the service in each test file. Tests that interleave two loads use a stub that holds a request until the test releases it. How to write the tests themselves is a Swift Testing skill's subject ([related skills](../SKILL.md#related-skills)).

Test the rules a bug would break on this screen, not the shape every view model shares:
- What a load asks the service for: the ID, key or page.
- The screen's own failure rule, such as Discover still showing its shelves when the featured movies fail.
- Paging: a next page appends, and loading again keeps the pages.
- Stale results: a page that arrives after a refresh, or a key's results after a new key, is dropped, and a restarted footer still loads its page.
- A key or a mode's rules: a new key starts the data over and shows it as loading until its own load ends, even when the old key's load ends after it starts.
- A filter: what a text matches, and the matches after the values change.

Skip what the shape guarantees everywhere: starting values, the fallback error, a retry clearing an error, and cancellation alone, which the stale-result tests already cover. Test a nested model on its own, made the way its view model makes it.
