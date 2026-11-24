# Networking

One package talks to the API. It holds the API's types and the app's client over them, and classifies every failure once. Only the API's adapter targets, their test targets and the app import it.

## Contents
- The package
- The client
- Errors and cancellation
- Testing

## The package

```
Packages/Networking/
├── Package.swift
├── Sources/Networking/
│   ├── TMDBClient.swift    the app's client over the API
│   ├── TMDBError.swift     transport failures, classified once
│   └── …                   the API's types
└── Tests/NetworkingTests/
```

- How the API's types and the client are built comes from the search (`decisions.md#the-established-approach-first`), and an app that already has a client moves it here. Either way, the rest of this file holds.
- The API's types are `public` because adapter targets in other packages map them. That makes them reachable, not shared: they never appear in an XCore model, a service protocol or anything above the adapter targets.

## The client

`TMDBClient` is a `Sendable` struct, the app's map of the API: one method per operation the app calls, returning the API's types for the adapter targets to map.

- Methods keep the API's operation names (`movie-details` → `movieDetails(id:)`), so the client reads like the API it wraps. Swift naming starts at the domain (`domain.md#naming-services-and-their-methods`).
- What every request needs, such as the user's language, is added once inside the client, never by a live service.

## Errors and cancellation

Every client method throws either `TMDBError` or `CancellationError`. Each adapter target maps `TMDBError` into its feature's error, and view models treat `CancellationError` as "nothing happened".

```swift
public enum TMDBError: Error, Equatable {
    /// No connection, or it dropped during the request.
    case offline
    /// The request didn't complete for another reason.
    case requestFailed
    /// The server answered with something that couldn't be read.
    case invalidResponse
    /// The server answered with an error status.
    case unexpectedStatus(Int)
}
```

- Failures are classified once, in the client, so live services never see the transport's own errors.
- A cancelled request arrives as `CancellationError`, however the transport reports it. Reported as a failure, it would show an error on a screen the user left mid-load.

## Testing

`NetworkingTests` covers the requests the client builds, the responses it reads and its classification, cancellation included. Features never test the network; their XTMDBTests map API types built in the test (`modules.md#testing`).
