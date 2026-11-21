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

## 1. Where each test runs

There are two places a test can run:

- **Linux**: a Linux machine with a Swift 6 toolchain, such as a cloud container. `WaypointCore` is pure Swift, so the core builds and tests here. The renderer targets compile empty on Linux, so nothing here touches SwiftUI or UIKit.
- **The Mac**: a Mac with Xcode 16 or later, and the tools from `scripts/bootstrap.sh` ([setup](CONTRIBUTING.md#setup)). Everything that needs Apple's frameworks, Xcode or a simulator runs here.

| Layer | Where it lives | Linux | Mac |
|---|---|---|---|
| Core imports check | `scripts/check-core-imports.sh` | ✅ | |
| Comment width check | `scripts/check-comment-width.sh` | ✅ | |
| Concurrency guard rail | `scripts/check-concurrency.sh` | ✅ | ✅ every tier |
| Compile fixtures (must fail, must build) | `Tests/CompileFailures`, `Tests/CompileSuccesses`, checked by `scripts/check-compile-failures.sh` | ✅ | ✅ |
| Core unit tests | `Tests/WaypointCoreTests` | ✅ plain and thread sanitizer | ✅ macOS host and simulator |
| Renderer unit tests | `Tests/WaypointTests`, `Tests/WaypointUIKitTests` (the parts not behind `canImport(SwiftUI)` or `canImport(UIKit)` also run on Linux) | partly | ✅ macOS host and simulator |
| Unified log tests | `Tests/WaypointOSLogTests` | | ✅ thread sanitizer in `full` and `release` |
| Example app UI tests (XCUITest) | `Example/WaypointExampleUITests` | | ✅ simulator |
| iOS device build | `Waypoint-Package` for `generic/platform=iOS` | | ✅ `release` only |

The tests in `Tests/WaypointCoreTests/LinuxBehaviourTests.swift` pin the Observation, main actor and `Sendable` behaviour the core relies on, so a difference between Linux and Apple platforms shows up there first.

Two scripts run every layer. Nothing else counts as a test run:

- `scripts/test-linux.sh` runs, in order: the core imports check, the comment width check, the concurrency guard rail, `swift build`, `swift build --build-tests` with warnings as errors, the compile fixtures, `swift test`, and `swift test` under the thread sanitizer. Extra arguments go to both `swift test` runs.
- `scripts/test-mac.sh [quick|full|release]` runs the Mac layers in tiers. What each tier runs is in the script's header comment and in the table below.

| Tier | Runs | Simulators | Time on the Mac (2026-11-20) | Stop it after |
|---|---|---|---|---|
| `quick` (default) | The guard rail, the compile fixtures, the host and simulator package tests (each built once with warnings as errors), and the UI tests when the branch changes `Example/` or a renderer. It skips parts the branch can't affect: a branch with only docs changes runs the guard rail alone. `--ui` adds the UI tests, `--all` runs every part, `--only <Target/Class[/test]>` runs the guard rail and that one UI test. | `WAYPOINT_SIMULATOR` | about 12 min with the UI tests | 30 min |
| `full` | Every part, whatever changed: the guard rail, the compile fixtures, host and simulator package tests, the unified log tests under the thread sanitizer, all UI tests, then the system link and missing destination UI tests again in the Release configuration. | `WAYPOINT_SIMULATOR` | about 14 min | 35 min |
| `release` | `full`, then the iOS device build, then the package tests and all UI tests again on the iOS 17 simulator. | `WAYPOINT_SIMULATOR` and `WAYPOINT_IOS17_SIMULATOR` | about 23 min | 50 min |

`scripts/test-linux.sh` takes about 3 minutes in a cloud container from a clean checkout (2026-11-21); stop it after 15 minutes.

## 2. Which run is needed

Find the row for the moment you are at. Run every command in its row, Linux first. A row with "none" needs no run in that place.

| Moment | Linux | Mac |
|---|---|---|
| While working, after a change to anything but docs | `scripts/test-linux.sh` | `scripts/test-mac.sh quick` when the change touches `Sources/Waypoint`, `Sources/WaypointUIKit`, `Sources/WaypointOSLog`, `Example/` or a `Tests/` folder other than `WaypointCoreTests`; otherwise none |
| While working on one UI test | none | `scripts/test-mac.sh quick --only WaypointExampleUITests/<Class>/<test>` |
| **Before a pull request merges**, docs only | `scripts/test-linux.sh` | none |
| **Before a pull request merges**, anything else | `scripts/test-linux.sh` | `scripts/test-mac.sh full` |
| Before a tag | `scripts/test-linux.sh` | `scripts/test-mac.sh release` |
| The issue's tests name iOS 17 | as above | as above, plus `WAYPOINT_SIMULATOR=waypoint-02 scripts/test-mac.sh quick --all` |
| The issue's tests name iPad | as above | as above, plus `WAYPOINT_SIMULATOR=waypoint-03 scripts/test-mac.sh quick --all` |

A pull request is **docs only** when every file it changes matches `*.md`, `*.docc/**` or `docs-theme/**`. Read the changed files from the pull request itself, not from its labels. A pull request labelled `runs:mac` always needs `full`, even when it is docs only.

A result belongs to one commit. The merge gate holds only for the head commit it ran on, and that commit must contain the current `main`. When the branch gets a new commit after the run (including a merge of `main`), run the gate again. The one exception: when every file changed since the tested commit is docs only, `scripts/test-linux.sh` alone is enough.

## 3. The simulators

The Mac has a fixed pool of three simulators. Use them by name only.

| Name | Device | iOS | Used by |
|---|---|---|---|
| `waypoint-01` | iPhone | 27.2 | Every tier (the default `WAYPOINT_SIMULATOR`) |
| `waypoint-02` | iPhone | 17.5 | `release` (the default `WAYPOINT_IOS17_SIMULATOR`), and iOS 17 checks |
| `waypoint-03` | iPad | 27.2 | iPad checks only |

- **Mac runs are queued, one at a time.** Runs go in the order they ask. The first run takes the simulators it needs (`release` uses `waypoint-01` and `waypoint-02`). Every later run waits until that run has finished its teardown. Then it checks out its own commit, and the script builds and installs that version on the simulator. There is only one clone on the Mac, so a second run at the same time would change the first run's checkout under it, even on another simulator. Ask whoever keeps the queue for your turn before preflight, and say when your teardown is done. The script also locks each simulator it uses (`${TMPDIR:-/tmp}/waypoint-test-<name>.lock`), but only from the moment it reaches the simulator, and the lock never protects the clone: the queue does.
- **Never create a simulator.** `scripts/test-mac.sh` creates `WAYPOINT_SIMULATOR` when it is missing, so preflight step 3 checks it exists first and the script never gets the chance.
- **Never delete, erase or rename a simulator**, and never shut down one you don't hold. Shut down only your own, by name: `xcrun simctl shutdown waypoint-01`. Never `xcrun simctl shutdown all`.

## 4. Run the Linux suite

### Preflight

1. Check the toolchain:

   ```sh
   swift --version
   ```

   Pass: it prints `Swift version 6.` followed by a minor version. When `swift` is missing, install a Swift 6 toolchain (<https://www.swift.org/install/linux/>, or the machine's own setup script), then check again. Any other answer: stop and report it.

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

## 5. Run a Mac tier

Every step runs on the Mac, from the root of the Waypoint package clone, which this section calls `<clone>`. Write down the answer of every check: the report needs them.

### Preflight

1. **Have your turn.** The queue has given this run its turn, and the run before it has finished its teardown ([The simulators](#3-the-simulators)). Without your turn, stop and wait for it.

2. **Check the tools.**

   ```sh
   xcodebuild -version
   mise exec -- tuist version || tuist version
   ```

   Pass: Xcode 16 or later, and a Tuist version. When Tuist is missing, run `scripts/bootstrap.sh` once and check again; if it still fails, stop and report it.

3. **Check nothing else is running, and each simulator exists and is free.** First, no other Mac run may be going:

   ```sh
   pgrep -fl "scripts/test-mac.sh"
   ```

   It must print nothing. When it prints a line, another run is going: stop, don't touch the clone, and tell whoever keeps the queue. Then, for every simulator the tier uses:

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
WAYPOINT_SIMULATOR=waypoint-01 WAYPOINT_IOS17_SIMULATOR=waypoint-02 \
    scripts/test-mac.sh full > .build/test-mac.log 2>&1 &
echo $! > .build/test-mac.pid
wait "$(cat .build/test-mac.pid)"; echo "exit=$?"
```

- Run these lines as one background command that is allowed to run past the tier's **Stop it after** time, and wait for it to end. Never start a second Mac run while it runs.
- When it is still running at the **Stop it after** time, it is hung. Stop the step it is stuck in with `pkill -TERM -P "$(cat .build/test-mac.pid)"`. The script then fails that step, and its exit step shuts down its simulators and removes its locks. When the script is still running a minute later, run `kill -TERM "$(cat .build/test-mac.pid)"`. Use `TERM`, not `INT`: a script started in the background ignores `INT`. Never `kill -9`. Then go to [When a run fails](#6-when-a-run-fails).
- `WAYPOINT_JOBS` and `WAYPOINT_BASE` stay unset unless the person who asked for the run names a value.

### Pass or fail

- **Pass:** it prints `exit=0`, and the log has `All Mac tests passed (<tier>).` after the `Step times` table, where `<tier>` is the tier you ran.
- **Fail:** anything else, including a log that has `Creating simulator`. The failing step is the last `==> ` line in the log. Go to [When a run fails](#6-when-a-run-fails).

Copy the `Step times` table from the end of the log into the report either way.

### Teardown

Teardown runs after every run, passed or failed, in this order:

1. **Simulators.** For every simulator the run used, check it is shut down:

   ```sh
   xcrun simctl list devices available | grep -E "^ +waypoint-01 \("
   ```

   When it still says `(Booted)`, shut it down by name: `xcrun simctl shutdown waypoint-01`.

2. **Locks.** `ls -d "${TMPDIR:-/tmp}/waypoint-test-waypoint-01.lock" 2>/dev/null` prints nothing for every simulator the run used. When a lock is still there and no `test-mac.sh` of yours is running, remove that one lock directory.

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

Find the first row that matches what the log says. Do what it says, once. A retry happens only where the table says so, and only once per run. A run that passed only on a retry of a single test still failed the gate.

| The log says | It is | Do this |
|---|---|---|
| `error:` with a file and line from the Swift compiler, or `warning:` in a build with warnings as errors | A real failure: the code doesn't build cleanly | No retry. Report the first three `error:` lines. |
| `comment line is N columns (limit 100)` | A real failure: [Comments wrap at 100 columns](CODE_STYLE.md#comments-wrap-at-100-columns) | No retry. Report the file and line. |
| `imports` a module other than the allowed ones | A real failure: the core must stay pure Swift | No retry. Report the file and the import. |
| A line from `scripts/check-concurrency.sh` other than `ok:` | A real failure: an unsafe concurrency escape | No retry. Report its lines. |
| A line from `scripts/check-compile-failures.sh` that names a fixture and isn't `ok:` | A real failure: a compile promise broke | No retry. Report the fixture and the line. |
| `✘` from Swift Testing, `XCTAssert…failed`, or `** TEST FAILED **` | A real failure: a test failed | Report each failing test's name and its first failure line. To tell a flaky test from a broken one, you may run that one test again once: `swift test --filter '<test function name>'` (Linux or the Mac host), or `scripts/test-mac.sh quick --only WaypointExampleUITests/<Class>/<test>` (UI). Report what the second run did. The gate still failed. |
| `ThreadSanitizer: data race` | A real failure: a data race | No retry. Report the first 20 lines of the report. |
| `error: another test run (pid N) is using <name>` | Not a test result: two runs overlapped | Don't remove the lock and don't touch the clone. Report it to whoever keeps the queue, who decides which run starts again. |
| `error: no simulator named <name>`, or `Creating simulator` | Not a test result: a simulator is missing | Stop the run if it is still going. Don't delete what was created. Report the name. |
| `error: no iOS simulator runtime installed` | Not a test result: Xcode lacks a runtime | Stop. Report it. |
| `Unable to boot`, `Failed to install`, `Failed to launch`, `Test runner never began executing`, `Lost connection to the test runner` | Not a test result: the simulator misbehaved | Shut your simulator down by name, then run the same command once more. A second failure: report it as a simulator failure. |
| The run was stopped as hung | Not a test result | Teardown, then report the last `==> ` line and the time it started. No retry. |
| Anything else | Unknown | Stop. Report the last 30 lines of the log. |

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
Step times: <the table from the end of the log, Mac only>
Teardown: simulators shut down, locks gone, clone back on main | <what is left>
```

## 8. Never do this

- Never skip, disable, comment out or delete a test, a check or a fixture to get a pass, and never change a timeout, a filter or a flag the command above doesn't name.
- Never edit code, tests or scripts during a run. A run reports; the fix is separate work.
- Never call a run passed when it didn't print its pass line, when only a retry passed, or when it ran on another commit.
- Never create, delete, erase or rename a simulator, never shut down one you don't hold, and never run `xcrun simctl shutdown all`.
- Never remove another run's lock, and never `kill -9` a test run (stop a hung one with `TERM`, as in [Run](#run-1)).
- Never start a Mac run before the run ahead of it in the queue has finished its teardown.
- Never stash, reset or delete changes in the Mac clone that aren't yours.
