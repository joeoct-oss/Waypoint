# Changelog

All notable changes to Waypoint are listed here. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project uses [Semantic Versioning](https://semver.org/).

## Unreleased

### Added

- Swift package with three products: `WaypointCore` (UI-agnostic state engine), `Waypoint` (SwiftUI renderer) and `WaypointUIKit` (UIKit renderer). (#2)
- `scripts/test-linux.sh` runs the core build and tests on Linux, after `scripts/check-core-imports.sh` checks that `WaypointCore` imports only Foundation, Observation and Synchronization. `CONTRIBUTING.md` explains how to run them. (#35)
- API design articles in the `WaypointCore` DocC catalog: Routes, Navigation state, Stack navigation, Presentation (with app-chosen sheet sizes) and Tabs. Signatures only; the API is implemented in later issues. (#42)
- API design articles for coordinators and child flows, root switching, events and logging, guards, deep links, state restoration, concurrency, and testing your navigation. Signatures only. (#43)
- DocC catalogs for the `Waypoint` (SwiftUI) and `WaypointUIKit` products, with renderer API articles, navigating from views and view models, and five example flows in each renderer. Signatures only. (#44)
- Every type in the API articles lists its conformances with a reason for each, and a new "Why these conformances" article explains `Hashable`, `Codable`, `Sendable`, `Equatable` and `AnyObject`. (#8)
- The API articles now show restore options for skipping presentations, how an observer reads the whole tree after a change, and that the testing helpers work in both Swift Testing and XCTest. (#8)
- Switch cases in the API articles put their body on its own line. (#8)
- The app's navigation now lives in an app coordinator (`RootCoordinator`, `SwiftUIRootCoordinator`, `UIKitRootCoordinator`), drawn by `WaypointRoot(app)` or `WaypointRootViewController(app)`. The README and the example flows lead with it, and the `@SwitchRoot` property wrapper is removed: screens report, the app coordinator switches the root. (#8)
- UIKit: `UIKitRootCoordinator` gains `makeWindow(for:options:)` and `receive(_:)` forwards, so a scene delegate's lifecycle methods only hand the OS's input to the app coordinator. (#8)
- Root coordinators build each root with `makeFlow(for:)` in both renderers. Examples give every `case` one call to a named function: `make…Flow()` builds a flow, `show…()` navigates. (#8)
- `README.md` with the Waypoint banner, a first look at the API, the products, requirements and links to every DocC article; an MIT `LICENSE`; and a complete `CONTRIBUTING.md` covering tests, code style, pull requests and merging. (#6)
