# Code style

The rules every Swift file in Waypoint follows: sources, tests, DocC snippets and examples. This file is their one home. [CONTRIBUTING](CONTRIBUTING.md) explains how a change is made and links here.

swift-format formats the code and SwiftLint enforces these rules. Each rule says how it is checked: by a tool, by a script, or in review when no tool can judge it.

## How the tools check the rules

- `scripts/lint.sh` runs both tools and fails on any finding. Run it while you work; CI's fast checks run it again on every pull request, so it must pass before a pull request is reviewed. `scripts/format.sh` fixes what the tools can fix, such as indentation and wrapping, and `scripts/bootstrap.sh` installs the pinned SwiftLint.
- swift-format uses its default rules, with the changes in [`.swift-format`](.swift-format): 120-column lines, 4-space indentation, one argument per line when a call wraps, and no `OnlyOneTrailingClosureArgument`, because SwiftUI's and Waypoint's own calls take a labelled callback and a trailing content closure. It is the toolchain's `swift format`, at the major and minor version `.mise.toml` names.
- SwiftLint runs its default rules, the opt-in rules and custom rules this file names, every warning as an error, from [`.swiftlint.yml`](.swiftlint.yml), which gives each turned-off rule its reason. The version is pinned in `.mise.toml`.
- The findings already in the code when the tools were turned on are listed in [`.swiftlint-baseline.json`](.swiftlint-baseline.json), so they don't fail the check while they are fixed. The list only shrinks: new code never adds to it. A change that fixes a finding first makes `scripts/lint.sh` pass, then regenerates the list with `swiftlint lint --write-baseline .swiftlint-baseline.json`, and review checks that the diff only removes entries.

## Empty braces have one space inside: `{ }`, never `{}`

This applies to empty types, protocols, functions, initialisers and closures, in code, tests, DocC snippets and examples. For example `enum ShopFlow: NavigationFlow { }` and `init() { }`. Empty collection literals (`[]`, `[:]`) are not braces and are unchanged.

Enforced by the custom SwiftLint rule `empty_braces_spaced`. `swift format` always writes `{}`, so `scripts/format.sh` puts the space back after it, and `scripts/lint.sh` ignores swift-format's finding at the space inside `{ }`.

## No one-line type bodies

A type or extension (`enum`, `struct`, `class`, `actor`, `protocol`, `extension`) whose body has anything in it opens its brace on the declaration line and puts each member on its own line, with the closing brace on its own line. **Enums list one case per line.** For example:

```swift
// Conformances:
// - `NavigationRoot`, so `RootRouter` can compare roots to know when to switch, save and
//   restore the current root, and name it in events off the main actor.
enum AppRoot: NavigationRoot {
    case login
    case main
}

// Conformances:
// - `Route`, so it can be pushed, presented and saved.
struct ProductRoute: Route {
    let id: Int
}
```

Not `enum AppRoot: NavigationRoot { case login, main }` or `struct ProductRoute: Route { let id: Int }`. A type with an empty body stays on one line as `{ }`. The same applies in prose: describe the type in words instead of writing a one-line declaration in inline code.

Enforced by the custom SwiftLint rules `no_single_line_type_body` and `one_case_per_line`. swift-format keeps the expanded form, so the two tools agree.

## Every body goes on its own lines

This extends the type body rule above to every declaration and statement with a body: functions, initializers, deinitializers, subscripts, computed properties and accessors, and the bodies of `if`, `guard`, `for`, `while`, `switch`, `do`, `catch` and `defer`. The brace opens on the declaration or statement line, the body goes on the next lines, and the closing brace gets its own line. For example:

```swift
init(link: DeepLinkParameters) throws {
    id = try link.int("id")
}
```

Not `init(link: DeepLinkParameters) throws { id = try link.int("id") }`. Three exceptions:
- an empty body stays `{ }`;
- accessor lists in signature-only API listings stay on one line: `{ get }`, `{ get set }`, `{ get nonmutating set }`;
- a closure passed as an argument may stay on one line when its body is one short expression, such as `.tabItem { Label("Home", systemImage: "house") }`, `Button("Close") { dismissFlow() }` or `LoginView(onLoggedIn: { self.showMainFlow() })`. A closure with more than one statement goes on its own lines. Why: SwiftUI modifiers and callbacks read as one phrase, and expanding every one of them would triple the length of view code without making it clearer.

Enforced by the custom SwiftLint rules `no_single_line_function_body` and `no_single_line_statement_body`.

## A blank line between member groups

Inside a type, a blank line separates:
- the stored properties from the initializers;
- the initializers from the functions, and each kind of member from the next (properties, initializers, subscripts, functions, nested types);
- every member that has a body (a function, initializer, subscript, computed property or nested type) from the member before and after it;
- top-level types from each other.

Members without a body may sit together in their group, without blank lines between them: stored properties, enum cases, `associatedtype`s, and signature-only API listings such as a protocol's requirements. The first member after an opening brace has no blank line above it. A member's doc comment and attributes stay directly on top of it, and the blank line goes above them. For example:

```swift
let router = StackRouter()
let catalog: CatalogService

init(catalog: CatalogService) {
    self.catalog = catalog
}

func showProduct(_ id: Int) {
    router.push(ProductRoute(id: id))
}
```

Enforced by the custom SwiftLint rules `blank_line_before_member_with_body` and `blank_line_between_member_groups`.

## Document every member of a type, or none

Inside one type, protocol, extension or enum, either every member has a `///` doc comment or none does. A list where some cases or properties are documented and their neighbours are not reads as if the undocumented ones were forgotten. For example:

```swift
public enum Trigger: Sendable {
    /// A call whose outcome is `.failed`.
    case failed
    /// A call that failed and was saved by its fallback.
    case recovered
    /// A call on a navigator whose flow is gone.
    case ignored
}
```

Not two bare cases next to one documented one. Public API documents everything, because every public symbol needs a doc comment anyway. Examples and internal types may document nothing. Public API is enforced by SwiftLint's `missing_docs`, which already requires a doc comment on every public member. Internal and example types are checked in review, because a regex can't count the members of a type.

## A type reads like a story, in this order

Members come in this order, and related members sit next to each other within their group:
1. enum cases;
2. type aliases and associated types;
3. nested types;
4. static properties;
5. stored properties;
6. computed properties;
7. initializers and `deinit`;
8. lifecycle methods, such as `viewDidLoad` or a scene delegate's methods;
9. static functions;
10. functions and subscripts.

**Static members go first in their group** (static properties before stored ones, static functions before instance ones). The choice is the one that needs no special case: type-level facts and ready-made values, such as `LogCategory.navigation` or `LogConfiguration.default`, are read before the instance details, and it matches SwiftLint's own `type_contents_order` grouping. Stored properties keep their order, because a struct's memberwise initializer follows it. For example:

```swift
public struct LogConfiguration: Sendable {
    public static var `default`: LogConfiguration { get }
    public static var disabled: LogConfiguration { get }

    public let handler: any LogHandler
    public let minimumLevel: LogLevel
    public let categories: Set<LogCategory>?
    public let revealsPrivateValues: Bool

    public init(
        handler: (any LogHandler)? = nil,
        minimumLevel: LogLevel = .notice,
        categories: Set<LogCategory>? = nil,
        revealsPrivateValues: Bool = false
    )

    public func isEnabled(level: LogLevel, category: LogCategory) -> Bool
    public func measuresIntervals(in category: LogCategory) -> Bool
}
```

Enforced by SwiftLint's `type_contents_order`, with the order above. It can't tell stored from computed properties or judge which members are related, so review checks those.

## Comments wrap at 100 columns

Every comment line, `//` and `///`, ends by column 100, indentation and the slashes included. Code lines keep the 120-column limit. The same holds for comments inside the code blocks of DocC articles and the Markdown files, so the documentation site shows them without sideways scrolling (its reading column fits 100 columns of code). For example:

```swift
/// - `NavigationValue`, so it can be compared and hashed, saved and restored, and sent off the main
///   actor.
```

- Break between words; never split a word, a symbol name or an inline code span.
- A list item's continuation lines line up under its text, two spaces after the `/// `.
- A code example inside a doc comment follows the wrapping rules below, so it fits too.
- Lines that cannot break are allowed to run long: a URL, and sample program output in a ```` ```text ```` block.

Why: 100 columns reads comfortably in an editor beside a second file, in a side-by-side diff and on the documentation site.

Enforced by `scripts/check-comment-width.sh`, which `scripts/test-linux.sh` runs, and by the custom SwiftLint rule `comment_line_length` in Swift files. swift-format's `lineLength` covers code only, because it does not rewrap comments.

## A wrapped parameter list puts each parameter on its own line

When a function, initializer or subscript doesn't fit on one line (120 characters), `(` ends the first line, each parameter goes on its own line, and `)` starts the last line, followed by the rest of the signature. Never some parameters on one line and the rest on the next. Enforced by swift-format's `lineBreakBeforeEachArgument` and SwiftLint's `multiline_parameters`.

## A wrapped call puts each argument on its own line

Nothing follows `(` on its line, each argument goes on its own line, and `)` sits alone on the last line. No continuation lines lined up under the paren. A call that is too long but has one long argument is better split with a named `let` first. A closure argument in a coordinator calls one of its named functions instead of navigating inline. For example:

```swift
var root: some View {
    ProductListView(
        onSelect: { self.showProduct(id: $0) },
        onFilter: { self.showFilters() }
    )
}
```

Enforced by swift-format's `lineBreakBeforeEachArgument` and SwiftLint's `multiline_arguments` and `multiline_arguments_brackets`. Review checks the named calls.

## No collection literal inside a call's arguments

An array, dictionary or set literal, empty ones included, is never written inside a call or a comparison in `#expect`. Give it a name with `let` first, then pass the name. Prefer an API that needs no list at all, such as `TabRouter(selection: MainTab.home)` for a `CaseIterable` tab type. For example:

```swift
// Before
let tabs = TabRouter(tabs: [MainTab.home, .shop], selection: .home, popsToRootOnReselect: false)

// After
let guestTabs: [MainTab] = [.home, .shop]
let tabs = TabRouter(tabs: guestTabs, selection: .home, popsToRootOnReselect: false)
```

`Package.swift` is the one exception: SwiftPM's manifest format lists targets and dependencies inline, and tools and people expect that shape. Enforced by the `no_literal_in_argument` custom rule.

## A switch case's body goes on its own line

The `case` or `default` label ends its line, and the body is indented below it, even when it is one short call or `break`. For example:

```swift
switch root {
case .login:
    makeLoginFlow()
case .main:
    makeMainTabsFlow()
}
```

Not `case .login: makeLoginFlow()`. A comment may follow the label on the same line. The rule is enforced by the custom SwiftLint rule `case_body_on_own_line`.

## A switch case's body is one call to a named function

Split the work into small functions, so each `case` body is a single line that calls one. `break`, `return`, `continue` and `fallthrough` are allowed when there is nothing to do. Not a view or controller built inline, an assignment, or several statements: move them into a function and call it. Enforced by the custom SwiftLint rules `case_body_one_line` and `case_body_is_call`.

## Names say what coordination code does

In coordinators, a function that builds a flow is named `make…Flow()` (`makeLoginFlow()`, `makeShopFlow()`, `makeTabFlow(for:)`), and a function that navigates is named `show…()` (`showMainFlow()`, `showProduct(id:)`). Use the same names in SwiftUI and UIKit, so a flow reads the same in both renderers. The renderer protocols follow it too: root coordinators implement `makeFlow(for:)`. A linter can't judge a name, so review checks this rule.

## An example app coordinator file stays under 500 lines

A coordinator in the example app decides navigation; it doesn't build screens or carry services. When its file grows past 500 lines, a flow of its own becomes a child flow, and code moves only to where it belongs, such as a factory or a type of its own, never into an extension file to pass the count. The limit fits an example app, where a feature's coordinator shows its whole navigation in one place. `scripts/check-coordinator-size.sh` checks it in CI's fast checks.

## Every protocol conformance says why

Whenever a type conforms to a protocol or a generic parameter is constrained (`AppRoot: NavigationRoot`, `Tab: NavigationTab`), the comment above the type lists each conformance with its reason. Public API uses its doc comment, and examples use a plain comment:

```swift
// Conformances:
// - `NavigationRoot`, so `RootRouter` can compare roots to know when to switch, save and
//   restore the current root, and name it in events off the main actor.
enum AppRoot: NavigationRoot {
    case login
    case main
}
```

When a type needs a set of conformances that many types share, it lists the set's one name with one reason, and the set's own doc comment gives the reason for each part. The sets are `NavigationValue` (`Hashable & Codable & Sendable`), `NavigationRecord` (`Sendable & Equatable & NavigationDescribable`) and `NavigationStateValue` (`NavigationRecord & Codable`), type aliases for Waypoint's own value types, and the protocols `Route`, `NavigationTab` and `NavigationRoot` for the app's types. Don't name a new set for fewer than three types or three conformances.
This applies to source code, tests and DocC. Only the platform base types that a type must adopt to exist at all (`View`, `App`, `UIViewController` and its subclasses) are left out. The package's "Why these conformances" article explains the common ones (`Hashable`, `Codable`, `Sendable`, `Equatable`, `AnyObject`) once. A linter can't judge a reason, so review checks this rule, and the package PR template has a checklist line for it.

## The example app is main actor by default; the package says every isolation

The example app and its unit tests set Swift 6.2's default actor isolation to the main actor (`SWIFT_DEFAULT_ACTOR_ISOLATION` in `Example/Project.swift`), so their code writes no `@MainActor`. It marks only the code that runs elsewhere:

- `nonisolated` for work that needs no actor: plain values that a route holds or a log handler builds (`Product`, `Address`, `EventLogEntry`), the log handlers themselves, the design tokens (`ColorToken`, `Palette`, `Typography`, `Spacing`), because UIKit and SwiftUI call some of their closures off the main actor, and the `Catalog/` types the UI tests share, so both targets see them the same way.
- `@concurrent` for slow async work that should leave the main actor.
- A closure that UIKit or SwiftUI may call off the main actor, such as a dynamic `UIColor { traits in … }` provider (SwiftUI resolves colors on its render thread) or an attribute transformer, is made in `nonisolated` code. Made in main-actor code, it is inferred main actor, and the runtime traps when the system calls it elsewhere. The compiler can't see this, so review checks it, and the UI tests catch it.
- The one place `@MainActor` is still written: a task that nonisolated code sends back to the main actor, `Task { @MainActor in … }`, as the log handlers do.

The package writes every isolation explicitly (`@MainActor` on routers, `nonisolated` where it applies), because a library can't rely on its clients' defaults. The UI test target keeps Swift's own default, since XCUITest code isn't app code. Enforced by the custom SwiftLint rule `no_main_actor_in_example`, and by `scripts/check-example-isolation.sh` on every Linux and Mac run.

## Each test picks its own test double

This covers every test: the package's core and renderer tests, the example app's unit tests, and the tests every plan lists. A test uses the double its case needs: a fake for working behaviour (an in-memory catalog), a stub for set answers (an auth service that always refuses), or a mock to check that a call happened (the account gate was asked to sign in). A real object is fine where it gives the test full control, such as a real `StackRouter` on Linux or a real `LocalStore` on a domain of its own. There is no fixed rule for which; the test's case decides. Review checks the choice.

## Every test names the promise it pins

Every Swift Testing `@Test` has a display name that states, as a plain sentence, the promise the test pins: what a user of the code can count on, as the test's checks show it. The function name stays a short identifier, which `swift test --filter`, `--only` and the docs use to point at the test. For example:

```swift
@Test("Going back visits the screen below, with the time spent on the one above")
func goingBackVisitsTheScreenBelowWithTheTimeOnTheOneAbove() throws {
```

- The name says what is true, not what the test does: "A pop on an empty path fails with an issue naming the flow and call site", not "Test popping an empty path".
- It is a sentence in sentence case with no full stop. Code names keep their case (`dismissFlow`, `AnyRoute`).
- It promises nothing the checks don't show. A test whose name and checks drift apart is fixed in the same change.
- Arguments follow the name: `@Test("Sample refuses what it can't write, where the problem is", arguments: refused)`.
- XCUITest UI tests are XCTest, which has no display names, so their method names stay the only name.

Review checks that each name matches what its test asserts.

## An example app service gets a protocol only at a boundary or for a test

In the example app, a service gets a protocol when it reaches outside the app (auth, a server, a catalog that will be fetched), or when a test needs to control it, such as checking that the account gate was asked to sign in. The protocol arrives in the change whose test first needs it. Values and state holders that only read and write the local store stay concrete, and a test can use the real ones on a store of its own (`LocalStore(domain:)`). The test then picks its double as [Each test picks its own test double](#each-test-picks-its-own-test-double) says. A feature's dependency struct lists the services it uses, as a protocol's existential (`any AuthService`) or a concrete type. Services are protocols, not structs of closures, so the calls that belong together stay grouped by a type. Today `AuthService` and `ProductCatalog` are protocols. A linter can't judge when a test needs a protocol, so review checks this rule.

## `let` by default

Immutability catches logic errors before they happen at run time:
- Value types (routes, state, options, configurations, events) have only `let` fields. Not `private(set)`: a full `let`. A change makes a new value through a named function that checks it: `with…` for one field (`options.withDetents([.medium, .large])`), an `-ing` verb for an operation (`registry.registering(ProductRoute.self)`), or a reducer. No `mutating` functions.
- The initializer guards the value's rules, and decoding goes through it, so an invalid value can't be made.
- Objects that own state over time (routers, the tree, a transaction) keep as few stored `var`s as they need, `private` or `private(set)`, changed only by named functions in their own file that check the change.
- No public settable properties: a setting changes through a guarded function such as `router.setFallback(.popToRoot, for: .routeNotInPath)`, which reports `invalidSetting` and keeps the old value when the new one breaks a rule.
- No `inout` parameters for our own types, no `lazy var`, no stored `static var` or global `var`.
- Every remaining `var`, stored or local, has a comment above it that starts "`var` because" and names what changes it. Computed properties, protocol requirements and property wrappers (`@State`) are not stored `var`s and need no reason.
- Tests too: collect calls with a `Spy` from [Understudy](https://github.com/joeoct-oss/Understudy) (`Spy<Value, Void>()`, read back with `calls`) and act once with `Once` instead of captured `var`s.
- Enforced by the custom SwiftLint rules `stored_var_needs_reason`, `no_public_stored_var`, `no_lazy_var`, `no_mutating_func` and `no_static_stored_var`. Review checks `inout` parameters for our own types and that decoding goes through the guarded initializer.

For example:

```swift
/// The committed state and presented router, which renderers observe.
///
/// `var` because it is the router's current value. Only `commitWorkingCopy()` replaces it.
private var committed: Snapshot
```

## A file imports `Waypoint`, or `WaypointCore` alone when it draws nothing

`Waypoint` re-exports `WaypointCore`, so app code writes one import. A file that draws, or that uses anything from `Waypoint`, writes `import Waypoint` and never `import WaypointCore` too. A file that only decides where to go, such as a route type, a plain model or a navigation rule, may import `WaypointCore` alone, so it stays free of UI frameworks and can move to a module of its own that tests on Linux. The same holds for DocC snippets and README examples.

- The package's own sources and tests are the exception: each target names the modules it uses, and `scripts/check-core-imports.sh` keeps the core free of UI frameworks.
- Checked by `scripts/check-single-import.sh`, in `scripts/test-linux.sh` and every tier of `scripts/test-mac.sh`: it fails when an example app file or a Swift code block in the README files, the DocC catalogs or `docs/` imports both modules, or when an example app file imports `WaypointCore` next to SwiftUI or UIKit.

For example:

```swift
// ProductRoute.swift: draws nothing.
import WaypointCore

// ProductsCoordinator.swift: draws screens.
import SwiftUI
import Waypoint
```
