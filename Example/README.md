# Waypoint example app

A SwiftUI app with two branches, a **SwiftUI branch** and a **UIKit branch**. Each branch launches five flows (login, tabs, detail push, sheet and deep link), each as a SwiftUI flow or a UIKit flow: twenty entry points, which are also the UI test scenarios.

## Generate and run

The Xcode project is generated with [Tuist](https://tuist.dev) from `Project.swift`; no `.xcodeproj` or `.xcworkspace` is committed.

```sh
tuist generate --path Example --no-open
open Example/WaypointExample.xcworkspace
```

`scripts/test-mac.sh` generates the project and runs the UI tests on the project simulator.

## Launch arguments

UI tests open any screen directly with `-branch`, `-flow` and `-kind`, for example `-branch uikit -flow sheet -kind swiftui`. `ExampleApp.launch(branch:flow:kind:)` in the UI tests sets them.

## Folders

| Folder | What it holds |
|---|---|
| `App/` | The `App`, the app coordinator that owns all navigation, the screens it can push, and launch arguments |
| `Catalog/` | Branches, flows, kinds, entries and accessibility identifiers. The UI tests compile these too |
| `DesignSystem/Tokens/` | Color, type, spacing and radius tokens, used by SwiftUI and UIKit screens alike |
| `DesignSystem/Components/` | The few components the app adds on top of system controls: the route trail, kind chips and buttons, cards and screen chrome |
| `Screens/Home/` | Home and its branch cards |
| `Screens/Branches/` | The SwiftUI branch and the UIKit branch |
| `Screens/Placeholder/` | The SwiftUI and UIKit placeholder each flow shows until it is built |

Each flow gets its own folder under `Screens/` when it is built, with its SwiftUI and UIKit screens side by side.

## Rules the app follows

- Screens report what the reader did through callbacks; only the app coordinator navigates.
- Accessibility identifiers follow one pattern: `root.<branch>`, `<branch>.<flow>.<kind>` and `placeholder.<flow>.<kind>`.
- The code follows the package's code style in `CONTRIBUTING.md`.
