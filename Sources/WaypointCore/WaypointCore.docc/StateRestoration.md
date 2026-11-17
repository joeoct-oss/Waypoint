# State restoration

Save the whole navigation tree, and bring it back after the app relaunches.

## Overview

A `NavigationSnapshot` is a versioned, `Codable` copy of the whole navigation tree. The root router makes one and can be rebuilt from one. Where you store it is up to you.

```swift
// Saving, for example when the scene moves to the background.
let data = try root.snapshotData()

// Restoring at launch.
root.restore(from: data)
```

> Note: State restoration is not available yet. Routes are `Codable` from the start, so it can be added without changing them.

### Snapshot API

```swift
/// A versioned copy of the navigation tree.
///
/// Conformances:
/// - `Sendable`, so it can leave the main actor for logging, analytics and saving.
/// - `Codable`, so it can be saved, restored and logged.
/// - `Equatable`, so tests and the router can compare values.
public struct NavigationSnapshot: Sendable, Codable, Equatable {
    public static let currentVersion: Int
    public let version: Int
    public let tree: NavigationTree
}

extension RootRouter {
    public func snapshot() -> NavigationSnapshot
    public func snapshotData() throws -> Data

    /// Rebuilds the tree in one transaction with `origin: .restoration`.
    @discardableResult
    public func restore(from data: Data) -> RestoreOutcome
}

/// What a restore did.
///
/// Conformances:
/// - `Sendable`, so it can leave the main actor for logging, analytics and saving.
/// - `Equatable`, so tests and the router can compare values.
public enum RestoreOutcome: Sendable, Equatable {
    case restored
    /// Part of the tree could not be restored. The issues say what was dropped.
    case partial([NavigationIssue])
    /// Nothing was restored. The current state is unchanged.
    case failed(String)
}
```

### Restore never crashes

- A route that no longer decodes, because it was renamed or removed, cuts its stack at the last route that does. Set `routeKey` before renaming a route type to keep old snapshots working.
- A flow that no longer exists is dropped.
- A snapshot from an unknown version is refused, and the outcome is `.failed`.

Each loss is reported as a `NavigationIssue`, so you can see what was dropped.
