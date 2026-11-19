# Waypoint example app

Orbit Shop, a small shop that behaves like a production app, so every navigation pattern shows up in a real journey:

1. **Splash**, then the main tabs, the same for guests and signed-in readers.
2. **Accounts**, asked for only when an action needs an account (Check out, Save, Orders, or Sign in on Account): a sheet over the tabs with Sign in (a wrong password shows an error; Reset password is a sheet that turns into Link sent) and Create an account (three pushed steps: your details, a password with the terms as a sheet, and check your email; going back keeps what was typed). Once the reader signs in, the sheet closes and the action carries on; Cancel drops it. A mock auth service stands in for a server: any email and password sign in, except the password `wrong`.
3. **Main tabs** (system tab bar): **Shop** (the "Nebula nights" collection banner, products picked as cards and the rest as rows, a pushed collection or product, filters and the wish list as sheets), **Search** (the system search field), **Cart** (a badge with the cart's count; checkout presented full screen on its own Waypoint stack: pick a saved address or push Add a new address, then Payment and Review, then Order placed, whose Continue shopping opens Shop) and **Account** (profile or Sign in, orders, saved addresses with Add a new address, settings, sign out, which keeps the reader in the app as a guest).
4. **Developer**, under Account > Settings: Clear all data, which asks to confirm, then empties the store and starts the app over as a fresh install; and the **Navigation Lab**: two branches, SwiftUI and UIKit, each launching five demo flows (login, tabs, detail push, sheet and deep link) as a SwiftUI flow or a UIKit flow. These twenty entry points are also UI test scenarios. Below them, **Views and view models** has one screen per story of that epic: Navigation style tries the demo product with outputs, an injected `FlowNavigator` or `@FlowNavigation`; Navigate after the flow is gone shows a view model's late push return `.ignored`; A wrapper with no router above it shows `@StackNavigation`'s `noRouterInScope` failure; and Preview a screen without the app shows `.waypointPreview(flow:)`. Each demo runs full screen on a Waypoint stack of its own.

The `App` asks for each window's view with `AppCoordinator.makeWindow(services:launch:)`, which makes a new app coordinator for every window. The services (the local store, the session and the mock auth service) are made once and shared by every window; the store keeps the session, cart and wish list between launches. The tab bar, the Shop, Search and Cart stacks and checkout run on Waypoint: one `TabRouter` holds every tab's stack router, each tab's coordinator draws its router with `WaypointStack`, and the cart's router presents checkout full screen as a flow of its own. The tab bar and the cover are still SwiftUI's `TabView` and `fullScreenCover`, bound to the routers, until Waypoint draws tabs and presentations itself. A product page links to a related product with `WaypointLink`, which pushes through the same router. Every stack router logs navigation issues at `.error` and above to a shared issue log, which shows the newest one in a banner over the stack. The same routers write to the unified log under the `dev.waypoint.example.waypoint` subsystem, from `.info` up with route values in debug builds: one journey box for each change the reader sees, titled such as `🧭 PUSH ▸ ProductDetailView`, with the coordinator, the tab, the previous screen and the whole app as a tree. Each coordinator names its router with `router.setCoordinator(self)`. Set `.debug` in `AppServices` to add a box with every field of each visit and the routers' own lines. Their `transaction` and `push` intervals go to Instruments as signposts (`AppLogHandler`). The other flows keep plain SwiftUI state until their part of Waypoint is built. Every product has an illustration drawn in SwiftUI from the design canvas's artwork (`ProductIllustration`), so the app needs no image assets. A tab's root shows the tab bar, and every screen pushed above it hides it: the Shop and Search stacks ask for it with `tabBarOnPushedScreens(.hidden)`, and the Account tab's plain stack hides it on its pushed screens itself. No screen decides it, so sheets and full-screen covers never touch it. Screens report what the reader did through callbacks; only coordinators navigate. Bars, tab bars, sheets and buttons are system controls, so they take Liquid Glass on iOS 26 and the classic look on earlier systems.

## Generate and run

The Xcode project is generated with [Tuist](https://tuist.dev) from `Project.swift`; no `.xcodeproj` or `.xcworkspace` is committed. Its version is pinned in `.mise.toml`; see [Setup](../CONTRIBUTING.md#setup).

```sh
tuist generate --path Example --no-open
open Example/WaypointExample.xcworkspace
```

`scripts/test-mac.sh` generates the project and runs the UI tests on the project simulator, then runs `SystemLinkTests` and `MissingDestinationTests` again in the release configuration.

## Launch arguments

UI tests start where they need to: `-clearData YES` starts from a fresh install (the UI tests always pass it), `-signedIn YES` starts signed in, `-lab YES` opens the Navigation Lab, `-branch uikit -flow sheet -kind swiftui` opens one Lab entry, `-splashSeconds 5` holds the splash long enough for a test to see it, `-shopPath 1,2,3` pushes those products onto the shop in one change, `-shopFollowUp pop` (or `popToRoot`, `link`) makes one more change 150 ms into that push, `-systemLinks YES` draws the product page's related link as a system `NavigationLink`, and `-missingDestination YES` makes that link push a reviews route that the registry lists but no products screen draws. `ExampleApp.launch(signedIn:lab:branch:flow:kind:splashSeconds:shopPath:shopFollowUp:systemLinks:missingDestination:)` in the UI tests sets them. `JourneyTests` has one test for each journey on the design canvas, `StackTests` checks the shop's Waypoint stack and its Waypoint link, `SystemLinkTests` checks that a system link is refused and reported, in the release configuration too, `MissingDestinationTests` checks the screen and report for a route with no destination in its stack, in both configurations, `LabTests` covers every Lab entry, and `ViewModelStyleUITests` covers the Views and view models stories.

## Folders

| Folder | What it holds |
|---|---|
| `App/` | The `App`, the app coordinator and its roots, and launch arguments |
| `Services/` | The local store, the session, the auth service protocol and its mock |
| `Store/` | The fixed sample products and orders, and the account type |
| `Flows/Splash/` | The splash screen |
| `Flows/Auth/` | The account gate, and the accounts sheet: sign in, the create account steps and the reset password sheet, with their coordinator |
| `Flows/Main/` | The main tabs and their coordinator |
| `Flows/Products/` | Shop and Search: the collection banner, product cards and rows, a collection, a product, the filter and wish list sheets |
| `Flows/Cart/` | The cart and the full-screen checkout |
| `Flows/Account/` | Account, orders, settings, and the Navigation Lab's place in the account stack |
| `Flows/Lab/` | The Navigation Lab: both branches, the placeholder each demo flow shows until it is built, and the Views and view models demos (`ViewModels/`) |
| `Catalog/` | The Lab's branches, flows, kinds and entries, accessibility identifiers and launch argument names. The UI tests compile these too |
| `DesignSystem/` | Color, type and spacing tokens, and the few components the app adds to system controls |

## Rules the app follows

- Each window has its own app coordinator; the `App` holds no navigation state, only the shared services.
- Screens report through callbacks; only coordinators navigate, with `make…Flow()` to build and `show…()` to navigate.
- Accessibility identifiers follow one pattern: `<flow>.<screen>` for journeys, and `root.<branch>`, `<branch>.<flow>.<kind>`, `placeholder.<flow>.<kind>` and `lab.story.<story>` in the Lab.
- The code follows the package's code style in [`CODE_STYLE.md`](../CODE_STYLE.md).
