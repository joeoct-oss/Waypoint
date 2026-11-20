# Contributing to Waypoint

Thank you for helping. This guide covers how changes are made: tests first, where they run, the code style, and how a pull request goes from branch to `main`.

## Setup

Tool versions (Tuist, SwiftLint and Periphery) are pinned in [`.mise.toml`](.mise.toml). On a Mac, run `brew install mise`, then `scripts/bootstrap.sh`. On Linux, `scripts/bootstrap.sh` alone installs the pinned SwiftLint into `.tools/bin`, because Tuist and Periphery only run on macOS. swift-format is the toolchain's `swift format`, so it needs no install.

## Start with an issue

Every change starts from an issue. Name the branch after it:

```text
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
2. `scripts/check-comment-width.sh`, which fails if a comment line runs past 100 columns ([Comments wrap at 100 columns](CODE_STYLE.md#comments-wrap-at-100-columns)).
3. `swift build`.
4. `scripts/check-compile-failures.sh`, which fails if a file in `Tests/CompileFailures` compiles. Each file holds code Waypoint promises to refuse at compile time, such as pushing another flow's route through a `FlowNavigator`, and names the error it expects in an `// expected-error:` line.
5. `swift test`. Extra arguments go to `swift test`, for example `scripts/test-linux.sh --filter LinuxBehaviourTests`.

The same `swift test` run works on a Mac. The tests in `Tests/WaypointCoreTests/LinuxBehaviourTests.swift` pin the Observation, main actor and `Sendable` behaviour the core relies on, so a platform difference shows up there first.

## Running tests on a Mac

The renderers and the UI tests need a Mac with Xcode 16 or later:

```sh
scripts/test-mac.sh          # quick: while working on a branch
scripts/test-mac.sh full     # before every merge
scripts/test-mac.sh release  # before a tag
```

| Tier | What it runs |
|---|---|
| `quick` (default) | The concurrency guard rail, the compile fixtures, the package tests on the host and on the simulator (each built once with warnings as errors), and the example app's UI tests when the branch changes `Example/` or a renderer. It skips the parts the branch can't affect: a docs-only branch runs only the guard rail. `--ui` adds the UI tests, `--all` runs every part, and `--only WaypointExampleUITests/StackTests/testPushAndBack` runs just that UI test. |
| `full` | Every check, whatever changed: `quick` with every part, the example app's UI tests, the unified log tests under the thread sanitizer, and the system link and missing destination UI tests again in the release configuration. A pull request labelled `runs:mac` passes it before merging. |
| `release` | `full`, plus a build for an iOS device with warnings as errors, and the package and example app tests again on the iOS 17 simulator. |

To keep the Mac usable, builds use at most `WAYPOINT_JOBS` jobs (default half the performance cores), Xcode never clones the simulator, only one run uses a simulator at a time, and the script shuts down each simulator it booted. It ends with the time each step took. Set `WAYPOINT_SIMULATOR` to use a simulator other than `waypoint-01`, `WAYPOINT_IOS17_SIMULATOR` for one other than `waypoint-02` (it must exist, on an iOS 17 runtime), and `WAYPOINT_BASE` to compare the branch with something other than `origin/main`.

## Documentation site

The DocC documentation is published as a static site on Cloudflare Pages at <https://waypoint-docs-9zj.pages.dev/documentation>. Build it on a Mac, so the SwiftUI and UIKit pages have their symbols, then upload it:

```sh
scripts/build-docs.sh
scripts/deploy-docs.sh
```

The site's look lives in `docs-theme`: `theme-settings.json` (DocC colors and fonts), `waypoint.css` (headings and the mark in the navigation bar), the landing page `index.html`, and the mark and favicon in `images`. `scripts/build-docs.sh` adds them after DocC builds the site.

The deploy reads a Cloudflare API token (Account, Cloudflare Pages, Edit) and the account ID from `CLOUDFLARE_API_TOKEN` and `CLOUDFLARE_ACCOUNT_ID`, as set in the project's cloud environment, which allows `api.cloudflare.com`. On a Mac without them it falls back to the Keychain items `waypoint-cloudflare-api-token` and `waypoint-cloudflare-account-id`. Never commit either value. Set `WAYPOINT_DOCS_PROJECT` to use a Pages project other than `waypoint-docs`.

## Code style

The code style lives in [CODE_STYLE.md](CODE_STYLE.md): braces and bodies, member order, wrapping, naming, conformance comments and `let` by default, each with an example and how it is checked. Once the lint setup lands (#70), `scripts/lint.sh` must pass before a pull request is reviewed.

Public symbols are documented in DocC. A change to the public API updates its article in the same pull request.

New source files start with this header:

```swift
//
//  FileName.swift
//  Waypoint
//
//  Created by <your name> <<your email>>.
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
