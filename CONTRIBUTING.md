# Contributing to Waypoint

Thank you for helping. This guide covers how changes are made: tests first, where they run, the code style, and how a pull request goes from branch to `main`.

## Setup

Tool versions (Tuist, SwiftLint and Periphery) are pinned in [`.mise.toml`](.mise.toml). On a Mac, run `brew install mise`, then `scripts/bootstrap.sh`. On Linux, `scripts/bootstrap.sh` alone installs the pinned SwiftLint into `.tools/bin`, because Tuist and Periphery only run on macOS, and `scripts/lint.sh` runs it when it is missing. swift-format is the toolchain's `swift format`, so it needs no install.

## Start with an issue

Every change starts from an issue. Report a bug or ask for a change in this repo's Issues tab; maintainers plan the work privately and link it back to your issue. Name the branch after the issue:

```text
<type>/<issue-number>-<short-kebab-description>
```

The type is one lowercase word that names the kind of work. The list is open: `feature`, `fix`, `docs`, `test`, `refactor`, `chore`, `ci` and `spike` are common ones, and any other plain word that fits is fine. For example `feature/12-typed-routes` or `fix/31-sheet-dismiss-crash`. After the number comes a short plain-English phrase, two to five words, that a person understands at a glance. Leave out decision, plan and issue numbers and code ids: `docs/251-explain-coordinators-and-renderers`, not `docs/251-align-docs-with-plan-17-and-18`.

## Test first

- **Unit tests come first.** Write the test, watch it fail, then write the code that makes it pass. Unit tests use Swift Testing.
- **UI tests cover what a person sees.** Anything visible, such as a push animation, a sheet or a tab switch, gets an XCUITest in the example app. If a change needs no UI test, say why in the pull request.
- **Navigation logic belongs in `WaypointCore`**, where it can be tested without a simulator.
- **Which tests run where** is in [TESTING.md](TESTING.md).

## Running tests

[TESTING.md](TESTING.md) is the one home for running the tests: which layers run on Linux, on a Mac and on GitHub's macOS runners ([Where each test runs](TESTING.md#1-where-each-test-runs)), which run is needed while working, before a merge and before a tag, the simulators, the exact steps, and what to do when a run fails. In short, `scripts/test-linux.sh` runs the core on Linux, and `scripts/test-mac.sh [quick|full|release|coverage]` runs the renderers and the example app's unit and UI tests on a Mac; a pull request's CI runs the Apple builds and tests on GitHub's macOS runners. Once Tuist has generated the example app, the repository root holds Tuist's project for the package (`Waypoint.xcodeproj` and `Derived/`, ignored by git), and a plain `xcodebuild -scheme Waypoint-Package` finds no scheme there: run the package's scheme through `scripts/package-xcodebuild.sh <xcodebuild arguments>`, which moves that project aside and puts it back. The test and docs scripts do.

## Documentation site

The DocC documentation is published as a static site on Cloudflare Pages at <https://waypoint-docs-9zj.pages.dev/documentation>. Build it on a Mac, so the SwiftUI and UIKit pages have their symbols, then upload it:

```sh
scripts/build-docs.sh
scripts/deploy-docs.sh
```

The site's look lives in `docs-theme`: `theme-settings.json` (DocC colors and fonts), `waypoint.css` (headings and the mark in the navigation bar), the landing page `index.html`, and the mark and favicon in `images`. `scripts/build-docs.sh` adds them after DocC builds the site.

The deploy reads a Cloudflare API token (Account, Cloudflare Pages, Edit) and the account ID from `CLOUDFLARE_API_TOKEN` and `CLOUDFLARE_ACCOUNT_ID`, as set in the project's cloud environment, which allows `api.cloudflare.com`. On a Mac without them it falls back to the Keychain items `waypoint-cloudflare-api-token` and `waypoint-cloudflare-account-id`. Never commit either value. Set `WAYPOINT_DOCS_PROJECT` to use a Pages project other than `waypoint-docs`.

## Code style

The code style lives in [CODE_STYLE.md](CODE_STYLE.md): braces and bodies, member order, wrapping, naming, conformance comments and `let` by default, each with an example and how it is checked. Run `scripts/lint.sh` (swift-format and SwiftLint) before you push, and `scripts/format.sh` to fix what the tools can fix; CI's fast checks run the lint again, so it must pass before a pull request is reviewed.

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

- **One issue per pull request.** Put one `Closes #<issue>` line in the body, or the full `owner/repo#<issue>` reference when the issue lives in another repo, and copy the issue's labels. A pull request that is one step of a larger issue uses `Part of` lines instead.
- **Title:** one plain English sentence in the imperative that says what the change does for the package, with no prefix and no trailing period. For example: "Refuse a push when the route has no destination".
- **Body:** fill in every section of the [template](.github/pull_request_template.md). Flag any public API change. The required **Pull request rules** check ([`scripts/check-pr-rules.py`](scripts/check-pr-rules.py)) holds the merge until the body and branch meet the rules it lists, and reruns when the body is edited. CodeRabbit's pre-merge checks explain a failure in words and warn on the judgment calls; they are in [`.coderabbit.yaml`](.coderabbit.yaml).
- **Changelog:** add a line to `CHANGELOG.md` under **Unreleased** for anything a package user would notice. When an entry is required, and when it can be skipped, is the "Docs and CHANGELOG" section of the [pull request template](.github/pull_request_template.md).
- **Keep the branch current.** It must contain the latest `main` when its [merge batch](TESTING.md#merge-batches) is built.

## Review and merge

- A pull request merges when its review is clean and every check is green.
- **CodeRabbit** reviews every pull request that is ready for review, against [CODE_STYLE.md](CODE_STYLE.md) and [TESTING.md](TESTING.md), with only blockers and should-fix items as inline comments. Fix or answer each one and resolve its thread. Once none is left open it approves the pull request, and `main` needs that approval to merge; a pull request whose review was rate limited waits for a review. Its settings, and why each is set, are in [`.coderabbit.yaml`](.coderabbit.yaml).
- **Gitar** also reviews every pull request that is ready for review, on a trial, with the same rules as CodeRabbit ([`.gitar/review/review.md`](.gitar/review/review.md)). It gives advice only: it doesn't approve, block a merge, write commits or edit the description. Fix or answer each finding as you would CodeRabbit's.
- **SonarQube Cloud** analyzes a pull request when the checks workflow runs [`scripts/sonar-scan.sh`](scripts/sonar-scan.sh), before the tests, and the tests start only once its quality gate passed (bugs, security, code quality and duplication on new code). Its settings are in [`sonar-project.properties`](sonar-project.properties).
- **Codecov** reports `WaypointCore`'s coverage, once the checks workflow uploads it, as two statuses, the whole project and the changed lines, with no comment on the pull request. Its settings are in [`codecov.yml`](codecov.yml).
- **Squash merge by default.** The commit title is the pull request title, and GitHub adds the number. When the branch's commits explain why the change was made, use a merge commit instead, so `main` keeps that history; give it the same title, the pull request title followed by `(#<number>)`. Never a rebase merge (it is turned off).
- Pull requests merge one at a time, in **merge batches**: up to four ready pull requests are stacked on the latest `main` and one Mac `full` run covers them all, then they merge in the batch's order. Nothing merges without a green `full` run on a commit that contains the latest `main`. The steps are in [TESTING.md: Merge batches](TESTING.md#merge-batches).
- The branch is deleted after the merge.

## License

By contributing, you agree that your contributions are licensed under the [MIT license](LICENSE).
