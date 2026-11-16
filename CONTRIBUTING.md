# Contributing to Waypoint

## Running tests on Linux

`WaypointCore` is pure Swift (Foundation, Observation and Synchronization only), so it builds and runs its unit tests on Linux. The `Waypoint` (SwiftUI) and `WaypointUIKit` targets compile empty there, so renderer code and UI tests still need a Mac.

You need a Swift 6 toolchain (6.0 or newer). From the repository root:

```sh
scripts/test-linux.sh
```

The script runs, in order:

1. `scripts/check-core-imports.sh`, which fails if any file in `Sources/WaypointCore` imports a module other than Foundation, Observation, Synchronization or WaypointCore itself.
2. `swift build`.
3. `swift test`. Extra arguments go to `swift test`, for example `scripts/test-linux.sh --filter LinuxBehaviourTests`.

The same `swift test` run works on a Mac. The tests in `Tests/WaypointCoreTests/LinuxBehaviourTests.swift` pin the Observation, main actor and `Sendable` behaviour the core relies on, so a platform difference shows up there first.
