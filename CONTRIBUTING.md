# Contributing to Waypoint

Thank you for helping. This guide covers how changes are made: tests first, where they run, the code style, and how a pull request goes from branch to `main`.

## Start with an issue

Every change starts from an issue. Name the branch after it:

```
<type>/<issue-number>-<short-kebab-description>
```

The types are `feature`, `fix`, `docs`, `test`, `refactor` and `chore`, for example `feature/12-typed-routes` or `fix/31-sheet-dismiss-crash`.

## Test first

- **Unit tests come first.** Write the test, watch it fail, then write the code that makes it pass. Unit tests use Swift Testing.
- **UI tests cover what a person sees.** Anything visible, such as a push animation, a sheet or a tab switch, gets an XCUITest in the example app. If a change needs no UI test, say why in the pull request.
- **Navigation logic belongs in `WaypointCore`**, where it can be tested without a simulator.

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

## Running tests on a Mac

The renderers and the UI tests need a Mac with Xcode 16 or later:

```sh
scripts/test-mac.sh
```

It runs the package tests on the host, then every unit test target on the simulator (including the UIKit-only tests), then the example app's UI tests. Set `WAYPOINT_SIMULATOR` to use a simulator other than `waypoint-01`.

## Code style

swift-format formats the code and SwiftLint enforces the rules. Once the lint setup lands (#70), `scripts/lint.sh` must pass before a pull request is reviewed. Until then, review checks these rules by hand:

- **Empty braces have one space inside:** `{ }`, never `{}`. This holds in code, tests and DocC snippets.
- **No one-line type bodies.** A type or extension with anything in its body puts each member on its own line, and enums list one case per line.
- **Every protocol conformance says why.** A `Conformances:` comment above the type, or its doc comment for public API, gives each conformance and each generic constraint its reason:

  ```swift
  // Conformances:
  // - `Hashable`, required by `RootRouter`, which compares roots to know when to switch.
  // - `Codable`, required by `RootRouter`, which saves and restores the current root with the tree.
  // - `Sendable`, required by `RootRouter`, so events that name the root can leave the main actor.
  enum AppRoot: Hashable, Codable, Sendable {
      case login
      case main
  }
  ```

- **Public symbols are documented in DocC.** A change to the public API updates its article too.

New source files start with this header:

```swift
//
//  FileName.swift
//  Waypoint
//
//  Created by <your name> <<your git email>>.
//  Copyright © <year> <your name>. MIT License.
//
```

## Pull requests

- **One issue per pull request.** Put `Closes #<issue>` in the body and copy the issue's labels.
- **Title:** one plain English sentence in the imperative that says what the change does for the package, with no prefix and no trailing period. For example: "Refuse a push when the route has no destination".
- **Body:** fill in the template. Say what changed, why, and how it was tested, and flag any public API change.
- **Changelog:** add a line to `CHANGELOG.md` under **Unreleased** for anything a package user would notice.
- **Keep the branch current.** It must contain the latest `main` before it merges.

## Review and merge

- A pull request merges when its review is clean and every check is green.
- **Squash merge only.** The commit title is the pull request title, and GitHub adds the number.
- Pull requests merge one at a time, so each one is tested against the `main` it lands on.
- The branch is deleted after the merge.

## License

By contributing, you agree that your contributions are licensed under the [MIT license](LICENSE).
