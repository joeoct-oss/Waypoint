# Testing runbook

Which tests run, when, and where, and exactly how to run them. This file is the one home for running Waypoint's tests. How to write tests (tests first, Swift Testing for unit tests, XCUITest for what a person sees) lives in [CONTRIBUTING: Test first](CONTRIBUTING.md#test-first), and the code style of tests in [CODE_STYLE.md](CODE_STYLE.md).

Follow the steps in order and word for word. Each step says what to run, what a pass looks like, and what to do when it isn't one. Where this file says **must** or **never**, there is no exception. When something happens that this file doesn't cover, stop and report it (see [Report the result](#7-report-the-result)) instead of guessing.

## Contents

1. [Where each test runs](#1-where-each-test-runs)
2. [Which run is needed](#2-which-run-is-needed)
3. [The simulators](#3-the-simulators)
4. [Run the Linux suite](#4-run-the-linux-suite)
5. [Run a Mac tier](#5-run-a-mac-tier)
6. [When a run fails](#6-when-a-run-fails)
7. [Report the result](#7-report-the-result)
8. [Never do this](#8-never-do-this)
9. [What a clean test suite means](#9-what-a-clean-test-suite-means)

## 1. Where each test runs

There are three places a test can run:

- **Linux**: a Linux machine with a Swift 6.2 or later toolchain, such as a cloud container. `WaypointCore` is pure Swift, so the core builds and tests here. The renderer targets compile empty on Linux, so nothing here touches SwiftUI or UIKit.
- **The Mac**: a Mac with Xcode 26 or later (the example app needs Swift 6.2), and the tools from `scripts/bootstrap.sh` ([setup](CONTRIBUTING.md#setup)). It runs the Mac tiers (`scripts/test-mac.sh`), and with them everything the runners below don't: the iOS 17.5 simulator, the iPad, Xcode betas, docs deploys and tags.
- **GitHub's macOS runners**: a pull request's CI builds the package and the example app there in its **Apple build** job (`.github/workflows/checks.yml`), and its Apple platform checks (`.github/workflows/apple.yml`) test the package, the example app and its UI tests with Xcode on the iPhone simulator ([On pull requests (CI)](#on-pull-requests-ci)).

| Layer | Where it lives | Linux | Mac (and the Apple stage on GitHub's macOS runners) |
|---|---|---|---|
| Core imports check | `scripts/check-core-imports.sh` | ✅ | |
| Comment width check | `scripts/check-comment-width.sh` | ✅ | |
| Example app coordinator size limit (under 500 lines, [CODE_STYLE.md](CODE_STYLE.md#an-example-app-coordinator-file-stays-under-500-lines)) | `scripts/check-coordinator-size.sh`, in CI's fast checks | ✅ | |
| Concurrency guard rail | `scripts/check-concurrency.sh` | ✅ | ✅ every tier |
| Example app isolation check (no `@MainActor` in the app or its unit tests) | `scripts/check-example-isolation.sh` | ✅ | ✅ every tier |
| One import check (no app file or docs snippet imports both `Waypoint` and `WaypointCore`) | `scripts/check-single-import.sh` | ✅ | ✅ every tier |
| Mac test script's run lock | `scripts/check-test-mac-lock.sh` | ✅ | |
| The package's xcodebuild wrapper (moves Tuist's package project aside and back) | `scripts/check-package-xcodebuild.sh` | ✅ | |
| Tuist's test hashes see every part of the package | `scripts/check-selective-testing-hashes.sh` | | ✅ `full` and `release`, and the Apple build (`checks.yml`) |
| Merge batches and the slowest-test list | `scripts/check-merge-batch.sh` | ✅ | |
| Flaky-test verdict and the quarantine's rules ([Flaky tests and quarantine](#flaky-tests-and-quarantine)) | `scripts/check-flaky-tests.sh` | ✅ | |
| UI test shards: every UI test class lands in exactly one shard | `scripts/ui-test-shards.py`, with a self-check | ✅ | |
| Public text: no private planning issue, decision or name in any tracked file | `scripts/check-public-text.sh`, with a self-check | ✅ | |
| Compile fixtures (must fail, must build) | `Tests/CompileFailures`, `Tests/CompileSuccesses`, checked by `scripts/check-compile-failures.sh` | ✅ | ✅ |
| Core unit tests | `Tests/WaypointCoreTests` | ✅ plain and thread sanitizer | ✅ macOS host and simulator |
| Renderer unit tests | `Tests/WaypointTests`, `Tests/WaypointUIKitTests` (the parts not behind `canImport(SwiftUI)` or `canImport(UIKit)` also run on Linux) | partly | ✅ macOS host and simulator |
| Unified log tests | `Tests/WaypointOSLogTests` | | ✅ thread sanitizer in `full` and `release`, and the Apple stage |
| Example app unit tests (Swift Testing: view models, the services container and the store) | `Example/ModuleTests/<module>` (one target per module, without the app) and `Example/WaypointExampleTests` (inside the app) | | ✅ simulator, with the UI tests |
| Example app UI tests (XCUITest) | `Example/WaypointExampleUITests`, run through `tuist test` on 3 simulator copies at once | | ✅ simulator |
| iOS device build | `Waypoint-Package` for `generic/platform=iOS` | | ✅ every pull request's Apple build (`checks.yml`), and `release` |

The core's own tests pin the Observation, main actor and `Sendable` behaviour it relies on, so a difference between Linux and Apple platforms fails a test that names the behaviour: `observationFiresOncePerCall` and `observationFiresOncePerTransaction` for Observation, and the `Concurrency` suites (`BackgroundNavigationTests`, `CrossActorValueTests`) for actors and `Sendable` values (the separate checks of Swift itself were removed). The slowest package tests, the `Navigation wrappers` and `Coordinator screens` suites at up to 4 s each on the Mac, draw a real `UIWindow` and wait for SwiftUI, which is what they test; the same lookups without a window run in `NavigatorLookupTests` in milliseconds.

Two scripts run every layer. A pull request's CI runs the same layers in its own jobs ([On pull requests (CI)](#on-pull-requests-ci)): the fast checks run `scripts/test-linux.sh --checks-only`, the Linux jobs run its `swift` commands with `--force-resolved-versions`, so CI builds exactly what `Package.resolved` pins, and the Apple stage (`.github/workflows/apple.yml`) runs the Mac layers with `swift` and `xcodebuild` on GitHub's macOS runners, as a CI gate, not a merge run. Nothing else counts as a test run:

- `scripts/test-linux.sh` runs, in order: the core imports check, the comment width check, the concurrency guard rail, the example app's isolation check, the one import check, the Mac test script's run lock check (`scripts/check-test-mac-lock.sh`, which uses stand-in tools), the package's xcodebuild wrapper check (`scripts/check-package-xcodebuild.sh`, with a stand-in xcodebuild), the merge batch check (`scripts/check-merge-batch.sh`), the flaky-test verdict and quarantine check (`scripts/check-flaky-tests.sh`), the UI test shard checks (`scripts/ui-test-shards.py --self-check` and `scripts/ui-test-shards.py 3 --list`), the public text check (`scripts/check-public-text.sh`, which reads private names from `PRIVATE_NAMES`), one `swift build --build-tests` with warnings as errors, then the compile fixtures and `swift test` reusing that build, and `swift test` under the thread sanitizer. Extra arguments go to both `swift test` runs. The checks before the build are the script checks: they need no Swift, only bash, git, perl, python3 and procps. `--checks-only` runs just them and `--swift-only` just the rest. CI runs `--checks-only` in its fast checks and the same `swift` commands, with `--force-resolved-versions`, in its Linux jobs ([On pull requests (CI)](#on-pull-requests-ci)); a run by hand uses neither flag.
- `scripts/test-mac.sh [quick|full|release|stress|coverage]` runs the Mac layers in tiers. What each tier runs is in the script's header comment and in the table below. The example app's unit and UI tests run through `tuist test`, which generates the project first, on `WAYPOINT_UI_WORKERS` temporary copies of the simulator at once (default 3, 2 before; measured on 2026-11-24 for the 65 example tests: 2 copies 859 s, 3 copies 767 s, 4 copies 717 s, all green, with about 20 GB of swap at 4). Xcode makes the copies ("Clone N of <simulator>") one after another in a device set of its own, `~/Library/Developer/XCTestDevices`, new for every run, and leaves one behind each time, shut down and as big as the simulator it copies (measured on 2026-11-25: 43 left over, about 20 GB each, none reused). A run notes which copies were there when it started, and at the end deletes, by UDID, only the copies made since that are shut down; Xcode shuts its copies down when a step ends (`WAYPOINT_TEST_DEVICES` names another set). A copy that was there before, a copy still booted at the end (someone else's test run, such as one in Xcode), and the pool simulators are never touched, and a run that can't list the copies at its start removes none. Each copy takes longer the more data the project simulator holds: on 2026-11-25 `waypoint-01` held 21 GB, 16 GB of it the wallpaper store, and the three copies took 33, 57 and 72 s, so the third worker's first test started 4 minutes after the build. A run with copies warns when the project simulator holds 5 GB or more; erase it with `xcrun simctl erase waypoint-01` while no run uses it. A failed UI test keeps screenshots, not a screen recording (`preferredScreenCaptureFormat: .screenshots` in `Example/Project.swift`): on 2026-11-25 recordings made a failing run's result bundle about 200 MB instead of about 10 MB, and `tuist test` spent 6.5 minutes uploading it, or ran out of retries. The release reports step runs its two classes on the project simulator itself, with no copies, since two classes gain nothing from parallel workers. The package's tests never use copies. The project is linked to the Tuist server project `joeoct91/waypoint` (`Example/Tuist.swift`), so `tuist test` uses Tuist's selective testing, which skips a test target that already passed with the same hash, in `quick` and `full` runs. The hash covers the package's sources: the example app takes the package through Tuist's package integration (`Example/Tuist/Package.swift`, with `.external` dependencies in `Example/Project.swift`), so the package's modules are targets in Tuist's graph. Selective testing is off in a `release` run, with `--only`, `--ui` or `--all`, and when the branch changes a file the hashes don't cover: anything outside `Sources/`, `Tests/` and `Example/`, the example app's manifests (`Example/Project.swift`, `Example/Tuist.swift`, `Example/Tuist/`), or when there are no changes to judge; Markdown and DocC files never count. Tuist records a pass only for a whole test target, never for a run narrowed to a class or a test, so `--only` and the release reports step never make a later run skip anything; the release reports step itself always runs its tests, since the Debug step just passed their target and nothing shows that Tuist's hash tells the two configurations apart. `scripts/check-selective-testing-hashes.sh` (part of `full` and `release`) proves the hashes in a copy of the working tree: an edit in each package module and in each part of the example app must change the hashes of the app and of every unit test target that uses that part, and leave the other targets' hashes alone, so an edit in one feature never reruns another feature's tests; a docs edit must change none. `tuist hash selective-testing` takes no destination, so it lists no hash for the UI tests; Tuist hashes them only in a run with a destination, which `--device` gives it. Measured on 2026-11-24, before the change: an edit in `Sources/WaypointCore` or `Sources/Waypoint` left every hash as it was, since the app took the package with `.package(product:)`, which Tuist hashes by product name. After it: an edit in any of the four modules changed the app's and its unit tests' hashes, and the whole UI test target ran in 975 s, was skipped in 18 s with nothing changed, and ran again in 935 s after a `WaypointCore` edit. Two settings make the package build as SwiftPM builds it: `SWIFT_PACKAGE_NAME` gives its modules one package name, so `package` symbols reach across them, and its own warnings come back on as errors, since Tuist silences a package's warnings. The package's own xcodebuild steps can't pass `SWIFT_TREAT_WARNINGS_AS_ERRORS=YES`: on the command line it reaches every target, and Xcode builds a remote package such as Understudy with `-suppress-warnings`, which the compiler refuses beside it. They fail instead on any `warning:` the build prints for a file in the package's `Sources/` or `Tests/`, and a dependency's warnings never count (#358). Tuist writes the package's project, `Waypoint.xcodeproj` and `Derived/`, into the package root (ignored by git); while it is there, xcodebuild finds no `Waypoint-Package` scheme, so the package steps (and `scripts/build-docs.sh`) run xcodebuild through `scripts/package-xcodebuild.sh`, which moves both into `.build/tuist-package-project` and puts them back after. It and the example app's `tuist test` pass xcodebuild `-skipMacroValidation`, since Understudy's macros must otherwise be trusted in Xcode by hand before xcodebuild builds them. The example app builds into its own derived data folder, `.build/example-derived-data` (`-derivedDataPath`, passed to xcodebuild after `--` as Tuist asks): on 2026-11-24 the first build after the package moved into Tuist's graph failed in Xcode's shared derived data with `package` symbols "inaccessible", from module state older builds had left, and the same build in a fresh folder was clean. Tuist's binary cache may give the example app's test step the package's four modules as prebuilt binaries in `quick` and `full` runs: the script sets `TUIST_WAYPOINT_BINARY_CACHE=1`, which turns the default cache profile in `Example/Tuist.swift` from `none` to `only-external` (so `tuist generate` for work in Xcode keeps the package's sources; `tuist test` ignores that profile and takes as a binary every target outside the tests it runs, the example app's eleven modules included, so a run builds from source only the modules a branch changed and those above them), and passes `--destination simulator`, since runs warm only simulator slices and `tuist test` otherwise asks for every destination and finds no binary. A module's cache key hashes its sources, its build settings (warnings as errors and `SWIFT_PACKAGE_NAME` included), the configuration, Xcode's compiler and its dependencies' keys, and a binary is only stored by a `tuist cache` build of exactly those inputs that succeeded, so a run never gets a stale module: any edit gives a new key and a source build, and `scripts/check-selective-testing-hashes.sh` proves that an edit in each module, the package's or the example app's, changes its key and the keys of the modules that depend on it and no other, and a docs edit changes none. `release`, `coverage`, offline runs, runs for a pull request (`WAYPOINT_PULL_REQUEST`, all with `--no-binary-cache`) and the release reports step (Release isn't warmed) always build from source; the package's own steps never use the cache. A green `full` or `coverage` run ends with `tuist cache --path Example --destination simulator` (about 67 s), which uploads the binaries for its tree; a failed warm only warns. Measured on 2026-11-24 (Tuist 4.218.5, unit tests on `waypoint-01`, main 63afaa8): the four modules are the only cacheable targets (the app and test bundles never are), their keys are the same on every hash, and a fresh derived data folder took 546 s from source and 109 s with the binaries (a warm folder 60 s and 47 s); after an edit in `Sources/Waypoint` only, `Waypoint` built from source against the cached `WaypointCore`, `package` symbols included, in 155 s, and the tests passed. Tuist caches a package without coverage counters: Xcode's own coverage report leaves cached modules out, and Tuist's upload still lists their files (239 either way) but nothing shows their lines count as covered, so the runs whose coverage someone reads, `coverage` on `main` and a pull request's run with its run report, build the package from source. Every run's results also go to the project's Tuist dashboard (Test Insights: run times and flaky tests), the package's test steps included (their result bundles go through `tuist inspect test`; a failed send only warns. Since then a commit's coverage on the dashboard covers the package's run and the example app's together, 95.3 % on 2026-11-25 against 84.x % for the example app alone before, so the jump is a change in what is measured, not in the tests), every build of the example app, in Xcode or a script, sends its timings there (Build Insights, a scheme post-action), and a test run in Xcode sends its results there too (a test post-action; it skips under `tuist test`, which sends them itself, so no run is counted twice). Tuist's own quarantine is never applied (`--skip-quarantine`): it lives on the Tuist server, where nobody reviews it. Waypoint's quarantine is `Example/quarantine.json`, and a failed example test runs once more ([Flaky tests and quarantine](#flaky-tests-and-quarantine)). Every run that uses Tuist collects code coverage and uploads it with its results (`Example/Tuist.swift`); it is on for every tier, not only `full`, because Tuist puts the setting in the selective testing hashes, and runs with it off couldn't reuse what runs with it on passed. The release reports step is the one exception: it tests two classes again in Release after the Debug step measured them, and always runs every test it names, so it runs with `TUIST_COVERAGE_ENABLED=0` (measured on 2026-11-24: coverage made `full` 1486 s instead of 1219 s, +22 %, the release reports step 199 s instead of 143 s). It also builds into its own derived data folder, `.build/release-reports-derived-data`: Tuist reads a run's coverage from one products folder of the derived data, the one holding most of the run's test bundles and the newest on a tie, whatever the configuration, so with Release products beside the Debug ones it read the uninstrumented Release builds and uploaded no covered file (found on 2026-11-24, Tuist 4.218.1 to 4.219.0-rc.2). An example run removes Release products an older run left in `.build/example-derived-data`. The dashboard's Code Coverage page charts a branch only from complete commits, and the commit a merge gate tested never lands on `main`, whether its pull requests merge by squash or by merge commit, since GitHub makes new commits either way: once a day, the first Mac run is `scripts/test-mac.sh coverage` on `main`, which runs every example test on `main`'s own commit and then `tuist coverage complete`. It runs only on `origin/main`'s commit, checked out as `main` or detached there, and refuses any other commit and a clone with changes; Tuist is told the branch is `main` either way. UI tests measure the app through Xcode's run-wide coverage only; Tuist records no per-target coverage of the app they drive. Every run also tells Tuist the branch it tests, through `GITHUB_HEAD_REF`, which Tuist reads on any machine: the branch the clone is on, or, on a merge batch's detached commit, the batch's branches joined with `+` (without it, those runs showed as "Unknown"). A run for one pull request also names it: with `WAYPOINT_PULL_REQUEST=<n>`, the script hands Tuist `GITHUB_REF=refs/pull/<n>/head`, which Tuist reads on any machine, and Tuist's GitHub app (on `joeoct-oss`, with the Tuist project linked to the repo) posts its run report on that pull request and updates it as later runs arrive: each `tuist test` command with its status, cache hit rate, tests, skipped and ran, and the commit, which Tuist takes from the checkout. Without the number Tuist posts nothing, since no Mac run comes from a GitHub workflow that would set the ref (found on 2026-11-24: no pull request had a report). The script clears any `GITHUB_REF` left in the shell, and names no pull request for a `coverage` run (it tests `main`), a run with `WAYPOINT_TUIST_OFFLINE=1` (it uploads nothing), or a merge batch of several branches (one report can't name them all); a value that isn't a number stops the run, and so does a pull request whose branch, which the script reads with `gh pr view` (read-only, the Mac's own `gh` sign-in), isn't the branch under test, so a wrong number never posts a report on another pull request; when `gh` can't answer, the run goes on without a report. `--plan` prints the pull request with the branch. Once every example test step of such a run passed, the run ends with `tuist coverage complete`, so the report's Coverage section shows the pull request's coverage instead of "still being collected"; a run of one test (`--only`) and a run for no pull request never complete their commit. The project's Run report comments setting on the Tuist dashboard (Project Settings, Integrations) turns the reports off without touching the uploads. Checked against Tuist's selective testing guide for generated projects on 2026-11-24: runs go through `tuist test` and Tuist keeps the hashes of passed targets, as the guide asks; a change to a manifest or a script turns selective testing off here, a stricter rule than the guide's; the guide's separate build and test jobs (`--build-only`, `--without-building`) don't apply, since one Mac job builds and tests; `--destination simulator` is passed whenever the binary cache is on; its coverage-based selection, which skips single tests inside a target that runs, is early access and not used (an idea, not a gap, since every UI test sits in one target). When a target runs that should have been skipped, the test run's Selective Testing tab on the dashboard shows each input's subhash, and its Copy as JSON compares two runs. Both post-actions run the Tuist that `.mise.toml` pins, through `mise exec`. The generated project also uses Xcode's compilation cache, backed by Tuist's remote cache (`enableCaching` in `Example/Tuist.swift`), so a build reuses what an earlier build of the same sources compiled. Its local stores settle at 10 GB (`storeSizeLimit`; Tuist checks them when the proxy starts and every 10 minutes while no build runs): without a limit they were never pruned, and on 2026-11-25 they held 1.2 GB in Xcode's derived data and 1.3 GB in `.build/example-derived-data`. The Mac signs in once with `mise exec -- tuist auth login` and installs the cache's local proxy once with `mise exec -- tuist setup cache --path Example` (a login item, `tuist.cas-proxy`). After `Example/Tuist.swift`'s `xcodeCache` settings change, it runs the same setup again so the proxy reads them. After `.mise.toml`'s Tuist version changes, it runs `mise exec -- tuist teardown cache --path Example` and then the same setup again, so the proxy runs the pinned Tuist: setup alone never moves the proxy to an older Tuist than the one it runs (on 2026-11-24 it kept Homebrew's 4.218.2 over the pinned 4.218.1). The project runs the latest stable Tuist unless the new version is breaking: the daily `coverage` run prints `scripts/check-tuist-version.sh`, which compares the pin with Tuist's latest stable release (never a canary or a release candidate); a newer minor or patch version gets a pull request that bumps the pin, with the usual Mac gate, and a new major version goes to Yousef first; `WAYPOINT_TUIST_OFFLINE=1` turns every server feature off except the compilation cache, which goes through the proxy whenever it runs. Every tier ends its log with the 10 slowest tests of each simulator test step, the package's included (`scripts/slowest-tests.py`, from each step's result bundle in `.build/results`).
- `scripts/merge-batch.sh` builds a [merge batch](#merge-batches) in the Mac clone and checks it before each merge.

| Tier | Runs | Simulators | Time on the Mac | Stop it after |
|---|---|---|---|---|
| `quick` (default) | The guard rail, the compile fixtures, the host and simulator package tests (each built once with warnings as errors), and the example app's unit and UI tests when the branch changes `Example/` or a renderer. It skips parts the branch can't affect: a branch with only docs changes runs the guard rail alone. `--ui` adds the example app's tests, `--all` runs every part, `--only <Target/Class[/test]>` runs the guard rail and that one UI test. Any tier with `--plan` prints what it would run, and whether selective testing is on, without running anything. | `WAYPOINT_SIMULATOR` | about 12 min with the UI tests (2026-11-20, before `tuist test`) | 30 min |
| `full` | Every part, whatever changed: the guard rail, the compile fixtures, host and simulator package tests, the check that Tuist's test hashes see the package, the unified log tests under the thread sanitizer, the example app's unit tests and all UI tests (a target that already passed with the same hash is skipped, see above), then the system link and missing destination UI tests again in the Release configuration. | `WAYPOINT_SIMULATOR` | about 14 min through `tuist test` on 3 simulator copies (832 s with 41 UI tests on 2026-11-25, example step 623 s; 1069 to 1172 s with 57 UI tests on 2 copies on 2026-11-24; about 26 min before 2026-11-23) | 35 min |
| `stress` | At night, on `main`, while a test is quarantined ([Flaky tests and quarantine](#flaky-tests-and-quarantine)): every step of `full` on 4 UI workers (`WAYPOINT_UI_WORKERS` still wins), with no retry, no selective testing and no binary cache, then each quarantined test 5 times in a row on the project simulator, stopping at its first failure. A failed example step doesn't stop it: the step is written down, the repeats still run, and the run fails at its end (`Checking the stress run's example steps`), with every failed test in the `Flaky tests:` list as `Failed:`. The log's `Flaky tests:` list ends with `Stress passed:` or `Stress failed:` for each quarantined test. It never gates a merge, posts no Tuist run report (it refuses `WAYPOINT_PULL_REQUEST`) and warms no cache. | `WAYPOINT_SIMULATOR` | about 25 min plus 1 to 7 min per quarantined test (not measured yet) | 75 min |
| `coverage` | On `main` only, once a day as the first Mac run: the guard rail, then every example app unit and UI test (no selective testing), then `tuist coverage complete`, which marks `main`'s commit complete on the Tuist dashboard. None of the package's steps. It also prints whether a newer stable Tuist is out. | `WAYPOINT_SIMULATOR` | about 16 min (not measured yet) | 30 min |
| `release` | `full`, then the iOS device build, then the package tests and the example app's unit and UI tests again on the iOS 17 simulator. | `WAYPOINT_SIMULATOR` and `WAYPOINT_IOS17_SIMULATOR` | about 23 min (2026-11-20, before `tuist test`; not measured since) | 50 min |

`scripts/test-linux.sh` takes about 3 minutes in a cloud container from a clean checkout (2026-11-21); stop it after 15 minutes.

## 2. Which run is needed

Find the row for the moment you are at. Run every command in its row, Linux first. A row with "none" needs no run in that place.

| Moment | Linux | Mac |
|---|---|---|
| While working, after a change to anything but docs | `scripts/test-linux.sh` | `scripts/test-mac.sh quick` when the change touches `Sources/Waypoint`, `Sources/WaypointUIKit`, `Sources/WaypointOSLog`, `Example/` or a `Tests/` folder other than `WaypointCoreTests`; otherwise none |
| While working on one UI test | none | `scripts/test-mac.sh quick --only WaypointExampleUITests/<Class>/<test>` |
| **Before a pull request merges**, docs only | the pull request's CI checks | none |
| **Before a pull request merges**, anything else | the pull request's CI checks | `scripts/test-mac.sh full` on its [merge batch](#merge-batches) |
| Before a tag | `scripts/test-linux.sh` | `scripts/test-mac.sh release` |
| Every night, while `Example/quarantine.json` on `main` lists a test | none | `scripts/test-mac.sh stress` on `origin/main` (preflight step 4 with `main` as the branch). When the Mac is asleep, offline or still busy in the morning, the run moves to the next night, with no alert. When the list is empty, the night is skipped |
| Once a day, as the first Mac run of the day | none | `scripts/test-mac.sh coverage` on `origin/main` (preflight step 4 with `main` as the branch), so the Tuist dashboard charts `main`'s coverage |
| The issue's tests name iOS 17 | as above | as above, plus `WAYPOINT_SIMULATOR=waypoint-02 scripts/test-mac.sh quick --all` |
| The issue's tests name iPad | as above | as above, plus `WAYPOINT_SIMULATOR=waypoint-03 scripts/test-mac.sh quick --all` |

A pull request is **docs only** when every file it changes matches `*.md`, `*.docc/**` or `docs-theme/**`. A pull request that changes only `Example/quarantine.json` counts as docs only too: it needs no Mac run, since its Linux check proves the file keeps the quarantine's rules, and a Mac run would fail on the very test it quarantines ([Flaky tests and quarantine](#flaky-tests-and-quarantine)). Read the changed files from the pull request itself, not from its labels. A pull request labelled `runs:mac` always needs `full`, even when it is docs only.

**Nothing merges without a green `full` run** (green as the script decides it, a flaky UI test that passed on its retry included, [Flaky tests and quarantine](#flaky-tests-and-quarantine)) on a commit that contains the latest `main`, unless the pull request is docs only. That commit is the pull request's [merge batch](#merge-batches): a green batch run counts for every pull request in it, as long as `--before-merge` passes right before each one merges. A `quick` run, of any kind, is for working on a branch and never counts for a merge.

### Merge batches

One `full` run covers up to four ready pull requests at once. A pull request is ready when its review is clean, it contains the latest `main`, and its Linux gate passed. A single ready pull request is a batch of one: since it already contains the latest `main`, its batch is its own head, not a merge commit, so the run tests a commit GitHub has and the commit links in Tuist's run report open. A docs only pull request needs no batch: its Linux gate is enough.

1. **Build the batch** on the Mac, in your queue turn, as preflight step 4 of [Run a Mac tier](#5-run-a-mac-tier) but with this instead of the checkout:

   ```sh
   scripts/merge-batch.sh <branch-1> <branch-2> ...
   ```

   A pull request that changes `scripts/merge-batch.sh` builds its batch with its own copy, saved inside the clone (the script works on the clone it sits in) in the ignored `.build/`:

   ```sh
   mkdir -p .build/merge-batch-<n>/scripts
   git show origin/<branch>:scripts/merge-batch.sh >.build/merge-batch-<n>/scripts/merge-batch.sh
   bash .build/merge-batch-<n>/scripts/merge-batch.sh <branch>
   ```

   Pass: it prints `batch <sha> tree <tree> main <main sha> branches <branch>@<sha> ...`. Write the whole line down: the report needs it. When it prints `error: <branch> doesn't merge cleanly`, leave that branch out (it must take `main` first) and build the batch again. When it prints `error: a Mac test run ... holds the run lock`, another run is going: wait for your turn.
2. **Run `full`** on the batch, exactly as [Run a Mac tier](#5-run-a-mac-tier) says. The report goes in every batch pull request's **Tests** section, with the batch line.
3. **Red batch:** nothing in it merges. Find the pull request the failure belongs to from [When a run fails](#6-when-a-run-fails); it is fixed, or left out, and the new batch runs `full` again.
4. **Green batch:** the pull requests merge one at a time, in the batch's order (squash, or a merge commit when the branch's history explains why; see [CONTRIBUTING.md](CONTRIBUTING.md)). Right before each merge:

   ```sh
   scripts/merge-batch.sh --before-merge <branch> <its tested sha> <expected main>
   ```

   For each pull request after the first, its **Linux checks** ran against the old `main`, so first run `scripts/test-linux.sh` on the branch merged locally with the new `main`, without pushing that merge (see [On pull requests (CI)](#on-pull-requests-ci)).

   The expected `main` is the batch's `main sha` for the first pull request, and the commit the pull request before it merged as for each later one. Pass: it prints `ok:`. When it prints `error:`, the branch or `main` moved since the run: stop. Nothing more from this batch merges. When some of the batch already merged, `main` holds a part of the batch no run tested: run `full` on `main` at once, as step 5 says for a tree mismatch, with the same revert rule. What's left goes in a new batch.
5. **After the last merge**, `scripts/merge-batch.sh --after-merge <the batch's tree>` must print `ok:`. When it prints `error:`, `main` holds code no `full` run tested: stop merging anything, run `full` on `main` at once (preflight step 4 with `origin/main` in place of the branch), and report it. When that run is red, the batch's pull requests are reverted, newest first, before anything else merges.

A result belongs to one commit. For a merge, that commit is the batch: the gate holds only while each pull request's head is the one the batch tested and `main` is the batch's `main` or the commits of the batch's earlier pull requests, which `--before-merge` checks. When the branch gets a new commit after the run (including a merge of `main`), run the gate again. The one exception: when every file changed since the tested commit is docs only, or `Example/quarantine.json`, the CI checks alone are enough.

## 3. The simulators

The Mac has a fixed pool of three simulators. Use them by name only.

| Name | Device | iOS | Used by |
|---|---|---|---|
| `waypoint-01` | iPhone | 27.2 | Every tier (the default `WAYPOINT_SIMULATOR`) |
| `waypoint-02` | iPhone | 17.5 | `release` (the default `WAYPOINT_IOS17_SIMULATOR`), and iOS 17 checks |
| `waypoint-03` | iPad | 27.2 | iPad checks only |

- **Mac runs are queued, one at a time.** Runs go in the order they ask. The first run takes the simulators it needs (`release` uses `waypoint-01` and `waypoint-02`). Every later run waits until that run has finished its teardown. Then it checks out its own commit, and the script builds and installs that version on the simulator. There is only one clone on the Mac, so a second run at the same time would change the first run's checkout under it, even on another simulator. Ask whoever keeps the queue for your turn before preflight, and say when your teardown is done. The script backs the queue up with a **run lock**: its first step takes `/tmp/waypoint-test-mac.lock`, a link to its process id that every clone and checkout on the Mac shares, and a second run stops at once with `error: another Mac test run holds the run lock` and runs nothing. The script clears a lock whose run has ended (a crash, a stop, a reboot) by itself, and never removes the lock of a run that is still going. A run that still holds it past its tier's **Stop it after** time is hung: stop it as [Run a Mac tier](#run-1) says, which also releases the lock. The script also locks each simulator it uses (`${TMPDIR:-/tmp}/waypoint-test-<name>.lock`) from the moment it reaches the simulator. Neither lock protects the clone before the script starts, so the queue still comes first.
- **Never create a simulator.** `scripts/test-mac.sh` creates `WAYPOINT_SIMULATOR` when it is missing, so preflight step 3 checks it exists first and the script never gets the chance. The temporary copies Xcode makes for parallel testing are the one exception: Xcode makes and removes them itself, and they never join the pool.
- **Never delete, erase or rename a simulator**, and never shut down one you don't hold. Shut down only your own, by name: `xcrun simctl shutdown waypoint-01`. Never `xcrun simctl shutdown all`.

## 4. Run the Linux suite

### Preflight

1. Check the toolchain:

   ```sh
   swift --version
   ```

   Pass: it prints `Swift version 6.` followed by a minor version of 2 or more. The run lock check also needs `ps`, `pgrep`, `pkill` and `/usr/bin/python3`: `command -v ps pgrep pkill /usr/bin/python3` prints four lines. When one is missing, install it (on Debian or Ubuntu: `procps` and `python3`). When `swift` is missing, install a Swift 6.2 or later toolchain (<https://www.swift.org/install/linux/>, or the machine's own setup script), then check again. Any other answer: stop and report it.

2. Get the exact commit to test, in a clean clone:

   ```sh
   git fetch origin main <branch>
   git checkout --detach origin/<branch>
   git status --porcelain
   git rev-parse HEAD
   git merge-base --is-ancestor origin/main HEAD && echo "contains main"
   ```

   Pass: `git status --porcelain` prints nothing, and the last command prints `contains main`. Write down the commit from `git rev-parse HEAD`. For a merge gate, when it doesn't print `contains main`, stop: the branch must take `main` first.

### Run

```sh
mkdir -p .build
scripts/test-linux.sh > .build/test-linux.log 2>&1; echo "exit=$?"
```

Run it as one command that is allowed to take 15 minutes; don't let a shorter tool timeout end it.

### Pass or fail

- **Pass:** it prints `exit=0`, and the log's last line is `==> Linux checks passed`.
- **Fail:** anything else. The failing step is the last `==> ` line in the log. Go to [When a run fails](#6-when-a-run-fails).

### Teardown

Nothing to tear down. Leave `.build` in place: the next run reuses it.

### On pull requests (CI)

GitHub Actions runs the checks on every pull request to `main` that is ready for review, and on every push to `main`, on GitHub's free standard runners (`.github/workflows/checks.yml`). Draft pull requests are skipped until they are marked ready, and a newer push cancels the older run. The **Pull request rules** check (`.github/workflows/pr-rules.yml`) is separate: it also runs on drafts and again whenever the body is edited. The checks run in stages, and each stage starts only when the one before it passed, so a failure stops the run before the slower stages:

1. **Fast checks** (about a minute): actionlint and zizmor on the workflows, the script checks (`scripts/test-linux.sh --checks-only`, with the repo secret `PRIVATE_NAMES`, which the public text check reads), the example app's coordinator size limit (`scripts/check-coordinator-size.sh`), lint (`scripts/lint.sh`: swift-format in the pinned Swift image, SwiftLint on the runner), dependency review when a package manifest or its pins changed, and whether the pull request is docs only (see [Which run is needed](#2-which-run-is-needed)).
2. **SonarQube Cloud quality gate** (`scripts/sonar-scan.sh`), once the fast checks passed, beside stage 3 and the Apple build; it passes without analyzing while that script isn't on the branch. CodeRabbit reviews beside it as an app.
3. **Linux checks** (`.github/workflows/ci.yml`), once the fast checks passed, three jobs side by side in the pinned `swift` containers: **Build and tests (Swift 6.4)** builds once with warnings as errors, checks the compile fixtures and runs the tests on that build, then, in steps that never fail it, runs the tests again with coverage on and keeps the lines of `Sources/WaypointCore` they ran as the `coverage` artifact (`scripts/core-coverage.sh`); **Thread sanitizer (Swift 6.4)** runs the tests under the thread sanitizer; **Tests on Swift 6.2** runs every test, warnings as errors, with the minimum Swift that `Package.swift` declares. **Linux build and tests** is their one gate.
4. **Coverage to Codecov** uploads that artifact once SonarQube passed. It only reports, and never fails a run.
5. **Apple build** (in `checks.yml`), on pull requests only, once the fast checks passed, beside SonarQube and the Linux checks, on one of GitHub's standard macOS runners with Xcode 27.2: it builds the package's tests on the macOS host and the package for an iOS device with warnings as errors (in Waypoint's own code for the device, `scripts/own-warnings-as-errors.sh`), builds the docs, builds Orbit Shop and every test bundle once with Tuist (`scripts/install-tuist.sh`, `scripts/build-example-tests.sh`), checks that Tuist's test hashes see every part, and keeps the test products for 30 days. A change that doesn't build on Apple's toolchain fails here, before any test time is spent. It isn't a required check: when it fails, the Apple tests never start, so the Apple gate reports nothing and the pull request can't merge.
6. **Apple platform checks** (`.github/workflows/apple.yml`), on pull requests only, once SonarQube, the Linux gate and the Apple build passed and the head commit is approved, by CodeRabbit or a person with access to the repo, whichever comes last (`scripts/apple-tests-ready.sh`), on GitHub's standard macOS runners with the newest iPhone simulator they have (`scripts/find-ci-simulator.sh`). When the approval comes after those checks, `.github/workflows/apple-tests.yml` starts them; when no approval comes (a rate-limited review, an outage, a Dependabot pull request), adding the label `run-apple-checks` starts them instead, and adding it again starts another run. A second approval of a head whose Apple tests are running or passed starts nothing. A push cancels the Apple tests still going for the pull request, and the new head needs its own approval. The tests run on the Apple build's products, which **Built products** waits for and finds; when they can't be fetched any more, the run builds them again. The jobs are ordered so that no more macOS jobs run at once than [`apple.yml`](.github/workflows/apple.yml) allows: **Package tests** tests the package on the macOS host and under the thread sanitizer, checks the compile fixtures, and tests on the iPhone simulator with warnings as errors in Waypoint's own code; **UI tests, shard 1 to 3** run the UI test classes, split by `scripts/ui-test-shards.py`, which refuses a test outside the body of an `XCTestCase` class, so none is left out; **Example app unit tests**, after the package tests, runs every unit test bundle; and **Release reports**, after the unit tests, runs the system link and missing destination UI tests in Release. In the example app's jobs a failed test runs once more, and `scripts/judge-test-results.sh` reads the result bundle with the [flaky test rules](#flaky-tests-and-quarantine): a UI test that passes on its retry is flaky, not red, a unit test that passes only on its retry still fails the job, and a test with a valid quarantine entry can't fail the run. The package job's tests don't retry. A failed job keeps its result bundle as an artifact for 7 days. The gate **Apple platform checks / Apple builds and tests** passes only when every job passed, or when the pull request is docs only and every job was skipped on purpose; while the head commit waits for its approval it reports nothing, and the ruleset's approval requirement keeps the pull request from merging. iOS 17.5, the iPad, Xcode betas, docs deploys and tags stay on the Mac.

A docs only pull request (`scripts/docs-only.sh`) runs stages 1 and 2 and skips the builds and tests; the Linux and Apple gates still report a pass, so it can merge. Pull requests from forks get no secrets, so the SonarQube and Codecov steps skip there. The required checks in "Protect main" are **Branch name**, **Fast checks**, **SonarQube Cloud quality gate**, **Linux checks / Linux build and tests**, **Pull request rules** (`.github/workflows/pr-rules.yml`) and **CodeRabbit**. The ruleset also requires one approval, which CodeRabbit gives once its review is clean and a new push dismisses, and every review thread resolved. A pull request's run tests its merge with `main` as `main` was when the run started; when `main` has moved since (an earlier pull request merged), update the branch so the checks run again, except for a later pull request of a tested [merge batch](#merge-batches): pushing would give it a new head the batch didn't test, so it follows the batch's steps instead (`scripts/test-linux.sh` on the branch merged locally with the new `main`, without pushing that merge). Apart from that case, CI runs the Linux and Apple gates for a pull request: run `scripts/test-linux.sh` by hand while you work, before a push, not for a pull request. The SwiftPM build folders are cached by `Package.swift` and `Package.resolved` alone, on pull requests only, so nothing a cache holds reaches `main`. Every action is pinned to a full commit SHA and every image to a digest; Dependabot bumps the actions and the images are bumped by hand.

## 5. Run a Mac tier

Every step runs on the Mac, from the root of the Waypoint package clone, which this section calls `<clone>`. Write down the answer of every check: the report needs them.

### Preflight

1. **Have your turn.** The queue has given this run its turn, and the run before it has finished its teardown ([The simulators](#3-the-simulators)). Without your turn, stop and wait for it.

2. **Check the tools.**

   ```sh
   xcodebuild -version
   mise exec -- tuist version || tuist version
   ```

   Pass: Xcode 26 or later, and a Tuist version. When Tuist is missing, run `scripts/bootstrap.sh` once and check again; if it still fails, stop and report it.

3. **Check nothing else is running, and each simulator exists and is free.** First, no other Mac run may be going:

   ```sh
   pgrep -fl "scripts/test-mac.sh"
   ```

   It must print nothing. When it prints a line, another run is going: stop, don't touch the clone, and tell whoever keeps the queue. Then check the run lock:

   ```sh
   ls -l /tmp/waypoint-test-mac.lock /tmp/waypoint-test-mac.lock.info 2>/dev/null && cat /tmp/waypoint-test-mac.lock.info
   ```

   When it prints nothing, carry on. When it prints the lock, check its holder with `ps -p "$(readlink /tmp/waypoint-test-mac.lock)" -o command= | grep -q test-mac.sh && echo running`. When that prints `running`, another run holds the Mac: stop, don't touch the clone, and tell whoever keeps the queue. When it prints nothing, the lock is stale and the script clears it itself; carry on. Never remove the lock by hand. Then, for every simulator the tier uses:

   ```sh
   xcrun simctl list devices available | grep -E "^ +waypoint-01 \("
   ls -d "${TMPDIR:-/tmp}/waypoint-test-waypoint-01.lock" 2>/dev/null
   ```

   - The first command must print exactly one line. It ends with `(Shutdown)` or `(Booted)`. When it prints nothing, the simulator is missing: stop and report it. Never create it.
   - The second command must print nothing. When it prints the lock, check its holder with `kill -0 "$(cat "${TMPDIR:-/tmp}/waypoint-test-waypoint-01.lock/pid")" && echo running`. When that prints `running`, another run holds the simulator: stop, don't touch the clone, and tell whoever keeps the queue. When it prints nothing, the lock is stale and the script clears it itself; carry on.
   - When the simulator is `(Booted)` and there is no lock, an earlier run left it on. Shut it down by name (`xcrun simctl shutdown waypoint-01`), so this run boots it and shuts it down at the end.

4. **Check out the exact commit.**

   ```sh
   cd <clone>
   git status --porcelain
   git fetch origin main <branch>
   git checkout --detach origin/<branch>
   git rev-parse HEAD
   git merge-base --is-ancestor origin/main HEAD && echo "contains main"
   ```

   Pass: `git status --porcelain` prints nothing before the checkout, and the last command prints `contains main` (for a merge gate; while working, write down that it doesn't). Write down the commit from `git rev-parse HEAD`. When `git status --porcelain` prints anything, the clone has changes that aren't yours: stop and report them. Never stash, reset or delete them.

### Run

Pick the command from [Which run is needed](#2-which-run-is-needed). Set the simulator names explicitly every time, so a changed default never picks another one:

```sh
mkdir -p .build
WAYPOINT_SIMULATOR=waypoint-01 WAYPOINT_IOS17_SIMULATOR=waypoint-02 WAYPOINT_PULL_REQUEST=<n> \
    scripts/test-mac.sh full > .build/test-mac.log 2>&1 &
echo $! > .build/test-mac.pid
wait "$(cat .build/test-mac.pid)"; echo "exit=$?"
```

- Run these lines as one background command that is allowed to run past the tier's **Stop it after** time, and wait for it to end. Never start a second Mac run while it runs.
- When it is still running at the **Stop it after** time, it is hung. Stop the step it is stuck in with `pkill -TERM -P "$(cat .build/test-mac.pid)"`. The script then fails that step, and its exit step shuts down its simulators and removes its locks. When the script is still running two minutes later, run `kill -TERM "$(cat .build/test-mac.pid)"`. Use `TERM`, not `INT`: a script started in the background ignores `INT`. Never `kill -9`. Then go to [When a run fails](#6-when-a-run-fails).
- `WAYPOINT_JOBS`, `WAYPOINT_BASE`, `WAYPOINT_UI_WORKERS` and `WAYPOINT_TUIST_OFFLINE` stay unset unless the person who asked for the run names a value.
- `WAYPOINT_PULL_REQUEST` is the number of the pull request the run tests, so Tuist posts its run report there. Leave it out for a merge batch of several pull requests, a `coverage` run, and a run of no pull request.

### Trust the caches

Mac runs reuse earlier work in three ways. Each one must give the result a run from scratch would give, never a false pass and never a false failure:

- **Selective testing**: `tuist test` skips a test target that already passed with the same hash.
- **The binary cache** (#445): `tuist test` takes every module outside the tests it runs, the package's and the example app's, as a binary built from exactly the same inputs. It ignores `Example/Tuist.swift`'s cache profile, which decides only `tuist generate` and `tuist cache`.
- **Xcode's compilation cache and the derived data folders**, which make builds incremental.

What keeps them honest:

1. **The hashes see every part.** `scripts/check-selective-testing-hashes.sh` runs in every `full` and `release` run, before any example test, and a failure stops the run. In a copy of the tree, it edits one file of each part: every package module, every example app folder, the asset catalog and every test folder. It also adds a new file. Each edit must change the hash of every test target that uses that part, and the cache key of every module built from it or above it, and must change nothing else. That proves both directions: a changed part always reruns its tests and rebuilds its modules, and an unchanged one is reused.
2. **What the hashes can't see, they aren't trusted with.** A branch that changes a file outside the package's and the example app's sources, such as a manifest, `.mise.toml`, a script or CI, runs with selective testing and the binary cache off.
3. **New tools mean no reuse.** A run records its Xcode, Tuist, macOS and simulator runtimes when it passes with every example test run from source and nothing skipped: a `coverage`, `release` or clean run, or any green run with both caches off. The record lives in `waypoint-clean-run-toolchain` in the clone's git folder. A run whose tools differ from that record, or that finds no record, turns selective testing and the binary cache off. The log says `toolchain since the last green clean run: same | changed | unrecorded`.
4. **A binary only comes from a green tree.** Only a green `full` or `coverage` run warms the binary cache, as its last step.

**Force a clean run** with `--clean`, on any tier: `WAYPOINT_SIMULATOR=waypoint-01 WAYPOINT_IOS17_SIMULATOR=waypoint-02 scripts/test-mac.sh full --clean`. It skips nothing, takes no binary, turns Xcode's compilation cache off, and builds the example app in fresh derived data folders (`.build/clean-example-derived-data` and `.build/clean-release-reports-derived-data`). The incremental folders stay as they were for the next run. The package's own steps build as they always do, through SwiftPM and xcodebuild with no shared cache. A green clean run records its tools, so later runs trust the caches again. Use it when a result looks wrong (see [When a run fails](#6-when-a-run-fails)), or when the person asking for the run says so.

### Pass or fail

- **Pass:** it prints `exit=0`, and the log has `All Mac tests passed (<tier>).` after the `Step times` table, where `<tier>` is the tier you ran.
- **Fail:** anything else, including a log that has `Creating simulator`. The failing step is the last `==> ` line in the log. Go to [When a run fails](#6-when-a-run-fails).

Copy the `Step times` table, the slowest-test lists and the two `Memory` lines from the end of the log into the report either way. The table is the run's phase timeline: each step's line starts with the clock time it started, and each `==> ` line in the log has that time too.

### Teardown

Teardown runs after every run, passed or failed, in this order:

1. **Simulators.** For every simulator the run used, check it is shut down:

   ```sh
   xcrun simctl list devices available | grep -E "^ +waypoint-01 \("
   ```

   When it still says `(Booted)`, shut it down by name: `xcrun simctl shutdown waypoint-01`.

2. **Locks.** `ls -d "${TMPDIR:-/tmp}/waypoint-test-waypoint-01.lock" 2>/dev/null` prints nothing for every simulator the run used. When a lock is still there and no `test-mac.sh` of yours is running, remove that one lock directory. `ls -l /tmp/waypoint-test-mac.lock 2>/dev/null` prints nothing too; when it still names your run's pid and that run has ended, leave it, since the next run clears it.

3. **Clone.** Keep the log under the commit's name, then put the clone back on `main`:

   ```sh
   cd <clone>
   cp .build/test-mac.log ".build/test-mac-$(git rev-parse --short HEAD).log"
   git checkout main
   git status --porcelain
   ```

   Pass: `git status --porcelain` prints nothing. The build products stay in `.build` and Xcode's DerivedData, so the next run builds only what its commit changed.

4. **Turn.** Tell whoever keeps the queue that this run's teardown is done, so the next run can start.

## 6. When a run fails

Find the first row that matches what the log says. Do what it says, once. Besides the one retry the script itself gives a failed example test ([Flaky tests and quarantine](#flaky-tests-and-quarantine)), a retry happens only where the table says so, and only once per run.

| The log says | It is | Do this |
|---|---|---|
| `error:` with a file and line from the Swift compiler, or `warning:` in a build with warnings as errors | A real failure: the code doesn't build cleanly | No retry. Report the first three `error:` lines. |
| `comment line is N columns (limit 100)` | A real failure: [Comments wrap at 100 columns](CODE_STYLE.md#comments-wrap-at-100-columns) | No retry. Report the file and line. |
| `imports` a module other than the allowed ones | A real failure: the core must stay pure Swift | No retry. Report the file and the import. |
| A line from `scripts/check-concurrency.sh` other than `ok:` | A real failure: an unsafe concurrency escape | No retry. Report its lines. |
| A line from `scripts/check-example-isolation.sh` ending "it is main actor by default" | A real failure: the [example app isolation rule](CODE_STYLE.md#the-example-app-is-main-actor-by-default-the-package-says-every-isolation) | No retry. Report the file and line. |
| `imports both Waypoint and WaypointCore` or `draws but imports WaypointCore` | A real failure: [one import](CODE_STYLE.md#a-file-imports-waypoint-or-waypointcore-alone-when-it-draws-nothing) | No retry. Report the file. |
| A line from `scripts/check-compile-failures.sh` that names a fixture and isn't `ok:` | A real failure: a compile promise broke | No retry. Report the fixture and the line. |
| `error: <test> failed every try`, `error: <test> passed only on a retry`, `✘` from Swift Testing, `XCTAssert…failed`, or `** TEST FAILED **` | A real failure: a test failed, and an example UI test failed its retry too | Report each failing test's name and its first failure line. An example UI test has already had its retry. A package test may run again once, to tell a flaky test from a broken one: `swift test --filter '<test function name>'` (Linux or the Mac host). Report what the second run did. The gate still failed. |
| `error: the quarantine file is wrong` | A real failure: `Example/quarantine.json` breaks the quarantine's rules | No retry. Report the line. |
| `ThreadSanitizer: data race` | A real failure: a data race | No retry. Report the first 20 lines of the report. |
| `error: a stale run lock is being cleared` | Not a test result: another run was clearing a lock left by an ended run, or a stopped run left its clearing folder | Wait two minutes and start the run again; the script removes a clearing folder older than a minute. When it says the same again, report it. |
| `error: another Mac test run took the run lock just now` | Not a test result: another run started at the same moment | Don't touch the clone. Report it to whoever keeps the queue. |
| `error: another Mac test run holds the run lock` | Not a test result: a second run was started while one was going | Don't remove the lock and don't touch the clone. Report it to whoever keeps the queue, with the holder's line from the error. Run again only when your turn comes. |
| `error: another test run (pid N) is using <name>` | Not a test result: two runs overlapped | Don't remove the lock and don't touch the clone. Report it to whoever keeps the queue, who decides which run starts again. |
| `error: no simulator named <name>`, or `Creating simulator` | Not a test result: a simulator is missing | Stop the run if it is still going. Don't delete what was created. Report the name. |
| `error: no iOS simulator runtime installed` | Not a test result: Xcode lacks a runtime | Stop. Report it. |
| `Unable to boot`, `Failed to install`, `Failed to launch`, `Test runner never began executing`, `Lost connection to the test runner` | Not a test result: the simulator misbehaved | Shut your simulator down by name, then run the same command once more. A second failure: report it as a simulator failure. |
| `FAIL:` from `scripts/check-selective-testing-hashes.sh` | A real failure: a hash or cache key misses a change, or moves without one, so the caches can't be trusted | No retry. Report the `FAIL:` lines. No pull request merges on a Mac run that skips or reuses anything until it is fixed; until then, gates run with `--clean`. |
| A build error about the build's own state, not the code: a module or `package` symbol "not found" or "inaccessible" in code that has it, `Undefined symbol` for code that exists, or a stale module file | Maybe not a test result: something an earlier build left | Run the same command once with `--clean`. Green: report it as a cache failure with both logs, and that clean run counts. Red again: it is a real failure, so report it as one. |
| The run was stopped as hung | Not a test result | Teardown, then report the last `==> ` line and the time it started. No retry. |
| Anything else | Unknown | Stop. Report the last 30 lines of the log. |

### Flaky tests and quarantine

A UI test that sometimes fails and sometimes passes on the same code is **flaky**. One flaky test must not turn a gate red on its own, and a real failure must still block. So:

1. **Retry once.** Every example app test step runs with `-retry-tests-on-failure -test-iterations 2`: a failed test runs once more, and no more. `--only` never retries and ignores the quarantine, since it is how a person looks at one test.
2. **The verdict.** After each example step, `scripts/flaky-tests.py` reads the step's result bundle and `Example/quarantine.json` and decides the step, whatever `tuist test` said:

   | The bundle shows | The step | The log says |
   |---|---|---|
   | A UI test failed, then passed on its retry | passes | `Flaky: <test> failed 1 of 2 tries, then passed (<first failure line>)` |
   | A UI test failed both tries, and isn't quarantined | fails | `error: <test> failed every try (2)` |
   | A UI test failed both tries, and is quarantined | passes | `Quarantined: <test> failed every try; it doesn't block until <date>, issue #<n>` |
   | A unit test failed, on any try | fails | `error: <test> passed only on a retry, which only a UI test may`, or `failed every try` |
   | The step failed, and no test failed (a build error, a runner that never started) | fails | `error: the step failed (status <n>) and no test failed` |
| The step failed with a failure outside its tests (a runner that crashed between tests, a build error the bundle records), whatever its tests did | fails | `error: the step failed outside its tests: <line>`, or `with <n> error(s) outside its tests` |

   The log ends with a `Flaky tests:` list of every flaky and quarantined test of the run, after the slowest tests.
3. **An issue for every flaky test.** After every Mac run, whoever reports it opens or updates one issue in the package repo for each test in the `Flaky tests:` list, with the GitHub tools from the cloud (the Mac never writes to GitHub). Its title is `Flaky UI test: <Class>/<test>`, its label `flaky test`, and its body keeps a dated list of the test's flakes: date, commit, run (gate, stress or coverage) and first failure line. A test that flaked before gets a new line in its open issue.
4. **Quarantine after two flakes in 7 days.** When a test's issue lists two flakes within 7 days, the reporter opens a pull request that adds it to `Example/quarantine.json`:

   ```json
   { "test": "WaypointExampleUITests/<Class>/<test>", "issue": <its issue number>, "since": "<today, YYYY-MM-DD>" }
   ```

   A quarantined test still runs. When it fails both tries, its failure is listed and doesn't fail the run. At most 3 tests are quarantined at once, each with an open issue: when the list is full, the test stays out and still fails the run when it fails both tries, and its issue says so. That pull request needs no Mac run ([Which run is needed](#2-which-run-is-needed)), and merges between merge batches, never while a batch's pull requests are merging, so `--before-merge` still finds the `main` it expects.

   - **A red run stays red.** A test quarantined after a run doesn't turn that run green: the batch runs `full` again.
   - **No issue, no quarantine.** When the flaky-test issue can't be opened (the package repo's Issues tab is off), the flake goes in the run's report, and its issue opens once it can. Until then the test can't be quarantined.
   - **Days are the Mac's.** `since` and the 7 days are dates in the Mac's time zone, which is the one the script reads.
5. **7 days at most.** An entry counts on the day in `since` and the 6 days after it. From the 7th day after `since`, runs ignore it and print `Quarantine expired: <test>`, so the test blocks again. The reporter then opens a pull request that removes the entry. The Linux check only warns about an expired entry, so an unrelated pull request stays green. A test whose entry expired is quarantined again only after a fix for it merges: a new entry for the same flake would only stretch the 7 days.
6. **Leaving quarantine.** A fix for a quarantined test merges like any change; the test's failure can't block it. The nightly `stress` run then proves the fix: when the log says `Stress passed: <test>`, the test passed its one try in the full run and all 5 repeats, and the reporter opens a pull request that removes its entry and closes its issue. `Stress failed: <test>` adds a flake to its issue, and the test stays until it passes a later night or its entry expires. A flake of any other test in a stress run is handled as in step 3. A night the Mac is asleep or offline moves the run to the next night.

`scripts/check-flaky-tests.sh` proves each row of the verdict on Linux from result bundle JSON, and refuses a quarantine file with more than 3 tests, a test that isn't a UI test, a test without an issue, a test listed twice, or a `since` that isn't a date or is in the future.

**A UI test that failed on a wait**. Look at the failure's screenshot in the result bundle. If it shows the screen the test expected next, the app got there late: a load timeout, most likely on a Mac with high swap. If it shows a wrong screen, or the right screen with the wrong content, the app did the wrong thing: a real failure. Either way the gate failed; the screenshot only tells the report which it was.

**Writing a UI test that checks a short-lived message.** A toast, a notice or the splash shows for a fixed time, so the test reads it right after the action that shows it, before it waits for anything else, and checks its text in the same query that finds it (`app.message(_:containing:)`): on a loaded Mac, reading `label` in a separate step once came more than 3 s after the message was found, when it was gone. Waits on state that stays (a screen, a banner, a count) use `UITestSteps.timeout`, which is long enough for a loaded Mac and costs a passing test nothing, since a wait ends as soon as its element shows. A check that an element stays, such as a locked sheet after a swipe, uses `UITestSteps.stayTime`, since it always spends its whole time. A row in a scrolling list is revealed with `reveal(_:)` before it is tapped, not tapped with `tapWhenReady()`: a row with only its top edge above the window's bottom counts as tappable to XCTest, and the tap lands on the edge instead (seen in `FallbackTests` on 2026-11-25).

## 7. Report the result

Every run ends with one report, passed or failed, in this shape. For a merge gate it goes in the pull request's **Tests** section.

```text
Result: passed | failed | not run (<why>)
Where: Linux | Mac
Command: <the exact command>
Commit: <sha>, contains main <main sha>: yes | no
Simulators: waypoint-01 (iOS 27.2) [, waypoint-02 (iOS 17.5)] | none
Time: <total seconds>
Failures: none | <test or step>: <first failure line>, one per line
Retry: none | <what ran again and what it did>
Flaky: none | <the `Flaky tests:` list from the end of the log>
Quarantine: none | <each quarantined test, until when, and whether it failed in this run>
Selective testing: off | on: <the targets `tuist test` listed under "Testing the following targets", or "none: no tests to run">
Caches: toolchain <same | changed | unrecorded>, binary cache <on | off>, clean <yes | no>
Tuist run report: on pull request <n> | none (<why>)
Batch: none | <the merge-batch.sh line>
Step times: <the table from the end of the log, Mac only>
Slowest tests: <the slowest-test lists from the end of the log, Mac only>
Teardown: simulators shut down, locks gone, clone back on main | <what is left>
```

## 8. Never do this

- Never skip, disable, comment out or delete a test, a check or a fixture to get a pass, and never change a timeout, a filter or a flag the command above doesn't name.
- Never edit code, tests or scripts during a run. A run reports; the fix is separate work.
- Never call a run passed when it didn't print its pass line, or when it ran on another commit. A run whose only failures were example UI tests that passed on the script's own retry, or quarantined tests, prints its pass line and passed; any other retry that passed doesn't make a run pass.
- Never add a test to `Example/quarantine.json` without its flaky-test issue and two flakes in 7 days, never quarantine more than 3 tests, and never move a `since` date to keep a test in quarantine longer.
- Never create, delete, erase or rename a simulator (Xcode's own temporary copies for parallel testing aside), never shut down one you don't hold, and never run `xcrun simctl shutdown all`.
- Never remove another run's lock, the run lock included, and never `kill -9` a test run (stop a hung one with `TERM`, as in [Run](#run-1)).
- Never start a Mac run before the run ahead of it in the queue has finished its teardown.
- Never stash, reset or delete changes in the Mac clone that aren't yours.

## 9. What a clean test suite means

A test is judged by what it really tests, never by how many tests there are. Cleaning the tests means making them solid and efficient. It never means dropping tests to cut the count, and coverage never drops.

- **Remove a test that tests nothing:** one whose assertions would pass with the behaviour broken, or that only repeats what the compiler or another test already proves.
- **Remove or rewrite a test that tests implementation** (private state, call order, internal types or exact log text where a business outcome would do): remove it when another test already pins the behaviour, otherwise rewrite it to pin the behaviour a person or a caller sees.
- **UI tests check what a person sees, without excess or double work:** a UI test covers a real interaction (a push, a sheet, a swipe, a tab switch, a link). Logic behind the screen is a unit test, and two UI tests that walk the same path become one.
- **One journey, one test:** separate tests that each set up the same screens to check one step are merged into one test that walks the journey and checks each step, when that covers it better.
- **Nothing is lost:** every removed, rewritten or merged test names the test that now pins its behaviour, and each module's coverage is the same or higher after the change.

The existing UI and unit tests were brought in line with this; every new test follows it.
