# Waypoint example app

Orbit Shop, a small shop that behaves like a production app, so every navigation pattern shows up in a real journey:

1. **Splash**, then the main tabs, the same for guests and signed-in readers.
2. **Accounts**, asked for only when an action needs an account (Check out, Save, Orders, or Sign in on Account): a sheet over the tabs with Sign in (a wrong password shows an error; Reset password is a sheet that turns into Link sent) and Create an account (three pushed steps: your details, a password with the terms as a sheet, and check your email; going back keeps what was typed). Once the reader signs in, the sheet closes and the action carries on; Cancel drops it. A mock auth service stands in for a server: any email and password sign in, except the password `wrong`.
3. **Main tabs** (system tab bar): **Shop** (products, a pushed product, filters and the wish list as sheets), **Search** (the system search field), **Cart** (a badge with the cart's count; checkout presented full screen, then Order placed, whose Continue shopping opens Shop) and **Account** (profile or Sign in, orders, settings, sign out, which keeps the reader in the app as a guest).
4. **Developer**, under Account > Settings: Clear all data, which asks to confirm, then empties the store and starts the app over as a fresh install; and the **Navigation Lab**: two branches, SwiftUI and UIKit, each launching five demo flows (login, tabs, detail push, sheet and deep link) as a SwiftUI flow or a UIKit flow. These twenty entry points are also UI test scenarios.

The `App` asks for each window's view with `AppCoordinator.makeWindow(services:launch:)`, which makes a new app coordinator for every window. The services (the local store, the session and the mock auth service) are made once and shared by every window; the store keeps the session, cart and wish list between launches. The Shop and Search stacks run on Waypoint's SwiftUI renderer: each products coordinator owns a `StackRouter`, and `WaypointStack` draws it. The other flows keep plain SwiftUI state until their part of Waypoint is built. Screens report what the reader did through callbacks; only coordinators navigate. Bars, tab bars, sheets and buttons are system controls, so they take Liquid Glass on iOS 26 and the classic look on earlier systems.

## Generate and run

The Xcode project is generated with [Tuist](https://tuist.dev) from `Project.swift`; no `.xcodeproj` or `.xcworkspace` is committed.

```sh
tuist generate --path Example --no-open
open Example/WaypointExample.xcworkspace
```

`scripts/test-mac.sh` generates the project and runs the UI tests on the project simulator.

## Launch arguments

UI tests start where they need to: `-clearData YES` starts from a fresh install (the UI tests always pass it), `-signedIn YES` starts signed in, `-lab YES` opens the Navigation Lab, `-branch uikit -flow sheet -kind swiftui` opens one Lab entry, `-splashSeconds 5` holds the splash long enough for a test to see it, `-shopPath 1,2,3` pushes those products onto the shop in one change, and `-shopFollowUp pop` (or `popToRoot`, `link`) makes one more change 150 ms into that push. `ExampleApp.launch(signedIn:lab:branch:flow:kind:splashSeconds:shopPath:shopFollowUp:)` in the UI tests sets them. `JourneyTests` has one test for each journey on the design canvas, `StackTests` checks the shop's Waypoint stack, and `LabTests` covers every Lab entry.

## Folders

| Folder | What it holds |
|---|---|
| `App/` | The `App`, the app coordinator and its roots, and launch arguments |
| `Services/` | The local store, the session, the auth service protocol and its mock |
| `Store/` | The fixed sample products and orders, and the account type |
| `Flows/Splash/` | The splash screen |
| `Flows/Auth/` | The account gate, and the accounts sheet: sign in, the create account steps and the reset password sheet, with their coordinator |
| `Flows/Main/` | The main tabs and their coordinator |
| `Flows/Products/` | Shop and Search: product lists, a product, the filter and wish list sheets |
| `Flows/Cart/` | The cart and the full-screen checkout |
| `Flows/Account/` | Account, orders, settings, and the Navigation Lab's place in the account stack |
| `Flows/Lab/` | The Navigation Lab: both branches and the placeholder each demo flow shows until it is built |
| `Catalog/` | The Lab's branches, flows, kinds and entries, accessibility identifiers and launch argument names. The UI tests compile these too |
| `DesignSystem/` | Color, type and spacing tokens, and the few components the app adds to system controls |

## Rules the app follows

- Each window has its own app coordinator; the `App` holds no navigation state, only the shared services.
- Screens report through callbacks; only coordinators navigate, with `make…Flow()` to build and `show…()` to navigate.
- Accessibility identifiers follow one pattern: `<flow>.<screen>` for journeys, and `root.<branch>`, `<branch>.<flow>.<kind>` and `placeholder.<flow>.<kind>` in the Lab.
- The code follows the package's code style in [`CODE_STYLE.md`](../CODE_STYLE.md).
