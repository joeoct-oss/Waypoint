# Waypoint example app

Orbit Shop, a small shop that behaves like a production app, so every navigation pattern shows up in a real journey:

1. **Splash**, then the app coordinator picks the root: Welcome, or the main tabs when already signed in.
2. **Accounts**: Welcome offers Create account (three pushed steps), Sign in (with Reset password as a sheet) and Continue as guest. Every way out is one root switch into the tabs.
3. **Main tabs** (system tab bar): **Shop** (products, a pushed product, filters and the wish list as sheets), **Search** (the system search field), **Cart** (checkout presented full screen) and **Account** (orders, settings, sign out, which switches the root back). Guests see only Shop and Search, with Sign in in the shop's bar.
4. **Navigation Lab**, under Account > Settings: two branches, SwiftUI and UIKit, each launching five demo flows (login, tabs, detail push, sheet and deep link) as a SwiftUI flow or a UIKit flow. These twenty entry points are also UI test scenarios.

Each window makes its own app coordinator. Screens report what the reader did through callbacks; only coordinators navigate. Bars, tab bars, sheets and buttons are system controls, so they take Liquid Glass on iOS 26 and the classic look on earlier systems.

## Generate and run

The Xcode project is generated with [Tuist](https://tuist.dev) from `Project.swift`; no `.xcodeproj` or `.xcworkspace` is committed.

```sh
tuist generate --path Example --no-open
open Example/WaypointExample.xcworkspace
```

`scripts/test-mac.sh` generates the project and runs the UI tests on the project simulator.

## Launch arguments

UI tests start where they need to: `-signedIn YES` skips sign in, `-guest YES` starts as a guest, `-lab YES` opens the Navigation Lab, and `-branch uikit -flow sheet -kind swiftui` opens one Lab entry. `ExampleApp.launch(signedIn:guest:lab:branch:flow:kind:)` in the UI tests sets them.

## Folders

| Folder | What it holds |
|---|---|
| `App/` | The `App`, the app coordinator and its roots, and launch arguments |
| `Store/` | The fixed sample products and orders |
| `Flows/Splash/` | The splash screen |
| `Flows/Auth/` | Welcome, sign in, the create account steps and the reset password sheet, with their coordinator |
| `Flows/Main/` | The main tabs and their coordinator |
| `Flows/Products/` | Shop and Search: product lists, a product, the filter and wish list sheets |
| `Flows/Cart/` | The cart and the full-screen checkout |
| `Flows/Account/` | Account, orders, settings, and the Navigation Lab's place in the account stack |
| `Flows/Lab/` | The Navigation Lab: both branches and the placeholder each demo flow shows until it is built |
| `Catalog/` | The Lab's branches, flows, kinds and entries, accessibility identifiers and launch argument names. The UI tests compile these too |
| `DesignSystem/` | Color, type and spacing tokens, and the few components the app adds to system controls |

## Rules the app follows

- Each window has its own app coordinator; the `App` holds no navigation state.
- Screens report through callbacks; only coordinators navigate, with `make…Flow()` to build and `show…()` to navigate.
- Accessibility identifiers follow one pattern: `<flow>.<screen>` for journeys, and `root.<branch>`, `<branch>.<flow>.<kind>` and `placeholder.<flow>.<kind>` in the Lab.
- The code follows the package's code style in `CONTRIBUTING.md`.
