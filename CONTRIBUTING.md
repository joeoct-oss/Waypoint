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

## Documentation site

The DocC documentation is published as a static site on Cloudflare Pages at <https://waypoint-docs-9zj.pages.dev/documentation>. Build it on a Mac, so the SwiftUI and UIKit pages have their symbols, then upload it:

```sh
scripts/build-docs.sh
scripts/deploy-docs.sh
```

The deploy reads a Cloudflare API token (Account, Cloudflare Pages, Edit) and the account ID from `CLOUDFLARE_API_TOKEN` and `CLOUDFLARE_ACCOUNT_ID`, as set in the project's cloud environment, which allows `api.cloudflare.com`. On a Mac without them it falls back to the Keychain items `waypoint-cloudflare-api-token` and `waypoint-cloudflare-account-id`. Never commit either value. Set `WAYPOINT_DOCS_PROJECT` to use a Pages project other than `waypoint-docs`.

## Code style

swift-format formats the code and SwiftLint enforces the rules. Once the lint setup lands (#70), `scripts/lint.sh` must pass before a pull request is reviewed. Until then, review checks these rules by hand:

- **Empty braces have one space inside:** `{ }`, never `{}`. This holds in code, tests and DocC snippets.
- **No one-line type bodies.** A type or extension with anything in its body puts each member on its own line, and enums list one case per line.
- **Every body goes on its own lines.** Functions, initializers, computed properties, accessors and the bodies of `if`, `guard`, `for`, `switch` and the like open their brace on the first line and close it on its own line. A closure argument whose body is one short expression may stay on one line, such as `Button("Close") { dismissFlow() }`.
- **A blank line between member groups.** Separate stored properties from initializers, initializers from functions, and every member with a body from its neighbours.
- **A type reads like a story.** Members come in this order: enum cases, type aliases and associated types, nested types, static properties, stored properties, computed properties, initializers and `deinit`, lifecycle methods, static functions, then functions and subscripts. Static members go first in their group. Keep related members next to each other.
- **A wrapped parameter list puts each parameter on its own line.** When a signature doesn't fit in 120 characters, `(` ends the first line, each parameter gets its own line, and `)` starts the last one:

  ```swift
  public init(
      handler: any LogHandler = DisabledLogHandler(),
      minimumLevel: LogLevel = .notice,
      categories: Set<LogCategory>? = nil,
      revealsPrivateValues: Bool = false
  )
  ```

- **A wrapped call puts each argument on its own line.** Nothing follows `(` on its line, each argument gets its own line, and `)` sits alone on the last line. In a coordinator, a closure argument calls one of its named functions:

  ```swift
  ProductListView(
      onSelect: { self.showProduct(id: $0) },
      onFilter: { self.showFilters() }
  )
  ```

- **`let` by default** ([decision 0014](https://github.com/JoeOCT91/Waypoint-planning/blob/main/decisions/0014-immutability.md)). Value types (routes, state, options, configurations, events) have only `let` fields. A change makes a new value through a named function that checks it, such as `options.withDetents([.medium, .large])` or a reducer. Objects that own state over time, such as routers, keep it in as few `private` or `private(set)` `var`s as they need, and only their own named functions change them, such as `router.setFallback(.popToRoot, for: .routeNotInPath)`. There are no public settable properties, no mutable statics or globals, no `lazy var` and no `mutating` functions. Every remaining `var`, including a local one, says why in a comment that starts "`var` because". Computed properties, protocol requirements and property wrappers such as `@State` are not stored `var`s and need no reason.

  ```swift
  /// The committed state and presented router, which renderers observe.
  ///
  /// `var` because it is the router's current value. Only `commitWorkingCopy()` replaces it.
  private var committed: Snapshot
  ```

- **A switch case's body goes on its own line, and is one call to a named function.** `break` and `return` are fine when there is nothing to do.
- **Names say what coordination code does.** A function that builds a flow is `make…Flow()`, and a function that navigates is `show…()`, in both renderers.
- **Document every member of a type, or none.** Public API documents every member.
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
