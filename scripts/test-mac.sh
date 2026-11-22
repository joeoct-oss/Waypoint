#!/usr/bin/env bash
#
#  test-mac.sh
#  Waypoint
#
#  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
#  Copyright © 2026 Yousef Mohamed. MIT License.
#
# Runs the Mac test layers in one of three tiers, so a run while working loads the Mac far less
# than the run before a merge (#247):
#
# - quick (the default, while working on a branch): the concurrency guard rail, the compile
#   fixtures, the host build and unit tests with warnings as errors, and the package tests on the
#   project simulator with warnings as errors. The example app's unit and UI tests join when the
#   branch changes `Example/` or a renderer, or with --ui. Parts the branch can't affect are skipped.
# - full (before every merge): every check, whatever changed. Adds the example app's unit and UI
#   tests, the unified log tests under the thread sanitizer, and the system link and missing destination UI
#   tests again in the release configuration.
# - release (before a tag): full, plus a build for an iOS device with warnings as errors, and the
#   package and example app tests again on the iOS 17 simulator.
#
# Each build is made once: the host build with warnings as errors is the build `swift test` runs,
# and the simulator build with warnings as errors is the build its tests run. Builds use at most
# WAYPOINT_JOBS jobs, Xcode never clones the simulator, only one run uses a simulator at a time,
# and the script shuts down each simulator it booted. It ends with the time each step took and
# the 10 slowest example app tests of each run (#295), read from its result bundle.
#
# One run at a time: the script first takes a run lock that every clone of the repo shares
# (#294). A second run stops at once and names the run that holds it. A lock left by a run that
# is no longer going is cleared; a lock whose run is still going is never touched.
#
# Usage: scripts/test-mac.sh [quick|full|release] [--ui] [--all] [--only <Target/Class[/test]>]
#   --ui    quick also runs the example app's unit and UI tests.
#   --all   quick runs every part, whatever the branch changed.
#   --only  quick runs only the guard rail and this example UI test (passed to -only-testing),
#           for example `--only WaypointExampleUITests/StackTests/testPushAndBack`.
#
# Environment:
#   WAYPOINT_SIMULATOR        the project simulator (default waypoint-01), created when missing.
#   WAYPOINT_IOS17_SIMULATOR  the iOS 17 simulator for release (default waypoint-02); must exist.
#   WAYPOINT_JOBS             build jobs (default half the performance cores, at least 2).
#   WAYPOINT_BASE             what quick compares the branch with (default origin/main).
#   WAYPOINT_RUN_LOCK         the run lock (default /tmp/waypoint-test-mac.lock); only the
#                             script's own checks set it, and WAYPOINT_RUN_LOCK_TEST_PAUSE.

set -euo pipefail

SCRIPT="$(cd "$(dirname "$0")" && pwd)/$(basename "$0")"
cd "$(dirname "$0")/.."

usage() {
    sed -n 's/^# \{0,1\}//; /^Usage:/,/^$/p' "$SCRIPT" >&2
    exit 2
}

TIER="quick"
WITH_UI=false
RUN_ALL=false
ONLY_TEST=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        quick | full | release) TIER="$1" ;;
        --ui) WITH_UI=true ;;
        --all) RUN_ALL=true ;;
        --only)
            [[ $# -ge 2 ]] || usage
            ONLY_TEST="$2"
            WITH_UI=true
            shift
            ;;
        -h | --help) usage ;;
        *)
            echo "error: unknown argument $1" >&2
            usage
            ;;
    esac
    shift
done
if [[ -n "$ONLY_TEST" && "$TIER" != "quick" ]]; then
    echo "error: --only works with quick; full and release run every test" >&2
    exit 2
fi

SIMULATOR_NAME="${WAYPOINT_SIMULATOR:-waypoint-01}"
IOS17_SIMULATOR_NAME="${WAYPOINT_IOS17_SIMULATOR:-waypoint-02}"
BASE_REF="${WAYPOINT_BASE:-origin/main}"
RUN_LOCK="${WAYPOINT_RUN_LOCK:-/tmp/waypoint-test-mac.lock}"
# How long each tier may run before TESTING.md calls it hung, in minutes.
case "$TIER" in
    quick) STOP_AFTER_MINUTES=30 ;;
    full) STOP_AFTER_MINUTES=35 ;;
    release) STOP_AFTER_MINUTES=50 ;;
esac

# Half the performance cores, so the Mac and other simulators stay usable during a run.
default_jobs() {
    local cores
    cores=$(sysctl -n hw.perflevel0.physicalcpu 2>/dev/null || sysctl -n hw.physicalcpu)
    echo $((cores / 2 > 2 ? cores / 2 : 2))
}
JOBS="${WAYPOINT_JOBS:-$(default_jobs)}"

# Settings every simulator test run shares: the job cap, and no parallel testing, which would
# clone the simulator once per worker.
XCODE_TEST_FLAGS=(-quiet -jobs "$JOBS" -parallel-testing-enabled NO)

# The steps run so far, with the seconds each took, printed when the script ends.
STEP_NAMES=()
STEP_SECONDS=()
# The simulators this run booted or locked, released when the script ends.
BOOTED_UDIDS=()
LOCK_DIRS=()
OWNS_RUN_LOCK=false
# The process group of the step that is running, if any.
STEP_PID=""

# Every process this run started, children and their children, deepest last.
run_descendants() {
    ps -A -o pid= -o ppid= | awk -v root=$$ '
        { parent[$1] = $2; pids[NR] = $1 }
        END {
            for (i = 1; i <= NR; i++) {
                p = pids[i]
                for (q = parent[p]; q != "" && q > 1; q = parent[q]) {
                    if (q == root) { print p; break }
                }
            }
        }'
}

# A run stopped with TERM leaves its step's tools running, a step's script and what that script
# started included, even when the step's first process was stopped already; stop the step's
# process group and anything else the run started, so the clone and the simulators are free
# before the locks go.
stop_step_tools() {
    local pids
    if [[ -n "$STEP_PID" ]]; then
        kill -TERM -- "-$STEP_PID" 2>/dev/null || true
        for _ in $(seq 1 60); do
            kill -0 -- "-$STEP_PID" 2>/dev/null || break
            sleep 0.5
        done
    fi
    pids=$(run_descendants)
    [[ -n "$pids" ]] || return 0
    # shellcheck disable=SC2086
    kill -TERM $pids 2>/dev/null || true
    local pid alive
    for _ in $(seq 1 60); do
        alive=false
        for pid in $pids; do
            kill -0 "$pid" 2>/dev/null && alive=true
        done
        $alive || return 0
        sleep 0.5
    done
}

# This run's result bundles, one per example app test step, whose slowest tests the report lists.
RESULTS_DIR=.build/results
SLOWEST_TEST_COUNT=10

# Lists the slowest tests of each result bundle. Only a report: it never fails the run.
report_slowest_tests() {
    local bundle
    for bundle in "$RESULTS_DIR"/*.xcresult; do
        [[ -d "$bundle" ]] || continue
        echo
        echo "$(basename "$bundle" .xcresult):"
        xcrun xcresulttool get test-results tests --path "$bundle" 2>/dev/null |
            scripts/slowest-tests.py "$SLOWEST_TEST_COUNT" || echo "note: no test times in $bundle"
    done
}

finish() {
    local status=$?
    local udid lock index
    stop_step_tools
    for udid in ${BOOTED_UDIDS[@]+"${BOOTED_UDIDS[@]}"}; do
        xcrun simctl shutdown "$udid" >/dev/null 2>&1 || true
    done
    for lock in ${LOCK_DIRS[@]+"${LOCK_DIRS[@]}"}; do
        rm -rf "$lock"
    done
    if [[ ${#STEP_NAMES[@]} -gt 0 ]]; then
        echo
        echo "Step times ($TIER, $JOBS jobs):"
        for index in "${!STEP_NAMES[@]}"; do
            printf '  %5ss  %s\n' "${STEP_SECONDS[$index]}" "${STEP_NAMES[$index]}"
        done
        printf '  %5ss  total\n' "$SECONDS"
    fi
    # A run turned away at the run lock reports nothing of the run that holds it.
    if $OWNS_RUN_LOCK; then
        report_slowest_tests
    fi
    if [[ $status -eq 0 ]]; then
        echo "All Mac tests passed ($TIER)."
    else
        echo "Mac tests failed ($TIER)." >&2
    fi
    # The run lock goes last, once the simulators are shut down and their locks are gone.
    if $OWNS_RUN_LOCK && [[ "$(readlink "$RUN_LOCK" 2>/dev/null)" == "$$" ]]; then
        rm -f "$RUN_LOCK" "$RUN_LOCK.info"
    fi
}
trap finish EXIT

# Whether `pid` is a running test-mac.sh, so a lock pointing at it is a live run's.
is_test_run() {
    [[ -n "$1" ]] && ps -p "$1" -o command= 2>/dev/null | grep -q "test-mac.sh"
}

# Takes the run lock, a symbolic link to this run's pid, so only one Mac run goes at a time in
# any clone. Stops when another run holds it, and clears a lock whose run has ended.
take_run_lock() {
    if ! ln -s "$$" "$RUN_LOCK" 2>/dev/null; then
        # The link is read once: the pid checked is the pid a clear compares with.
        local holder
        holder=$(readlink "$RUN_LOCK" 2>/dev/null || true)
        if is_test_run "$holder"; then
            local started info minutes
            info=$(sed -n 2p "$RUN_LOCK.info" 2>/dev/null || true)
            started=$(sed -n 1p "$RUN_LOCK.info" 2>/dev/null || true)
            echo "error: another Mac test run holds the run lock (pid $holder${info:+, $info})" >&2
            if [[ "$started" =~ ^[0-9]+$ ]]; then
                minutes=$((($(date +%s) - started) / 60))
                echo "  it has run for $minutes min" >&2
            fi
            echo "  wait for it to finish its teardown; when it runs past its tier's stop time," >&2
            echo "  stop it as TESTING.md says (Run a Mac tier). Never remove a live run's lock." >&2
            exit 1
        fi
        local stale="$holder"
        # Only for the script's own check: a pause here stands for a run that stalls between
        # finding a stale lock and clearing it.
        sleep "${WAYPOINT_RUN_LOCK_TEST_PAUSE:-0}"
        # Clearing happens under a second lock, a folder only one run can make, so the link
        # checked is the link removed: a live run can't put its link there meanwhile, since a new
        # link only lands on an empty path. A clearing lock left by a stopped run goes after a
        # minute.
        local clearing="$RUN_LOCK.clearing"
        if [[ -n "$(find "$clearing" -maxdepth 0 -mmin +1 2>/dev/null)" ]]; then
            rmdir "$clearing" 2>/dev/null || true
        fi
        if mkdir "$clearing" 2>/dev/null; then
            if [[ "$(readlink "$RUN_LOCK" 2>/dev/null)" == "$stale" ]]; then
                rm -f "$RUN_LOCK" "$RUN_LOCK.info"
                echo "note: cleared a run lock left by a run that has ended (pid ${stale:-unknown})" >&2
            fi
            rmdir "$clearing"
        elif [[ -d "$clearing" ]]; then
            echo "error: a stale run lock is being cleared (or a stopped run left $clearing);" >&2
            echo "  try again in two minutes" >&2
            exit 1
        fi
        if ! ln -s "$$" "$RUN_LOCK" 2>/dev/null; then
            echo "error: another Mac test run took the run lock just now; wait for it" >&2
            exit 1
        fi
    fi
    OWNS_RUN_LOCK=true
    {
        date +%s
        echo "$TIER, commit $(git rev-parse --short HEAD 2>/dev/null || echo unknown), started $(date '+%Y-%m-%d %H:%M'), in $(pwd), stop after $STOP_AFTER_MINUTES min"
    } >"$RUN_LOCK.info"
}
take_run_lock
# The result bundles of an earlier run would show in this run's report.
rm -rf "$RESULTS_DIR"

# Runs one step and records how long it took. A failing step stops the script.
step() {
    local name="$1"
    shift
    echo "==> $name"
    local start=$SECONDS status=0
    # Each step runs in a process group of its own, so stopping the run stops everything the
    # step started, a script's own tools included (`stop_step_tools`).
    set -m
    "$@" </dev/null &
    STEP_PID=$!
    set +m
    wait "$STEP_PID" || status=$?
    if [[ $status -ne 0 ]]; then
        exit "$status"
    fi
    STEP_PID=""
    STEP_NAMES+=("$name")
    STEP_SECONDS+=($((SECONDS - start)))
}

# Which parts the branch changed, compared with BASE_REF, including uncommitted and untracked
# files. quick runs only those parts; with no changes at all, or no BASE_REF, it runs them all.
CHANGED_PACKAGE=true
CHANGED_UI=true
detect_changes() {
    local merge_base files
    if ! merge_base=$(git merge-base HEAD "$BASE_REF" 2>/dev/null); then
        echo "note: $BASE_REF not found, so quick runs every part" >&2
        return
    fi
    files=$(
        {
            git diff --name-only "$merge_base"
            git ls-files --others --exclude-standard
        } | sort -u
    )
    if [[ -z "$files" ]]; then
        return
    fi
    CHANGED_PACKAGE=false
    CHANGED_UI=false
    local file
    while IFS= read -r file; do
        case "$file" in
            *.md | *.docc/* | docs-theme/*) continue ;;
        esac
        case "$file" in
            Sources/Waypoint/* | Sources/WaypointUIKit/* | Example/*) CHANGED_UI=true ;;
        esac
        case "$file" in
            Example/*) ;;
            *) CHANGED_PACKAGE=true ;;
        esac
    done <<<"$files"
}

# Prints the UDID of the named simulator, or nothing when it doesn't exist.
find_simulator() {
    xcrun simctl list devices available -j |
        /usr/bin/python3 -c 'import json,sys; name=sys.argv[1]; d=json.load(sys.stdin)["devices"]; print(next((x["udid"] for r in d.values() for x in r if x["name"]==name), ""))' "$1"
}

# Prints the UDID of the project simulator, creating it on the newest iOS runtime with the newest
# iPhone device type when it does not exist yet.
project_simulator_udid() {
    local udid
    udid=$(find_simulator "$SIMULATOR_NAME")
    if [[ -n "$udid" ]]; then
        echo "$udid"
        return
    fi
    local runtime device_type
    runtime=$(xcrun simctl list runtimes available -j |
        /usr/bin/python3 -c 'import json,sys; r=[x for x in json.load(sys.stdin)["runtimes"] if x["platform"]=="iOS"]; r.sort(key=lambda x: [int(p) for p in x["version"].split(".")]); print(r[-1]["identifier"] if r else "")')
    if [[ -z "$runtime" ]]; then
        echo "error: no iOS simulator runtime installed (Xcode > Settings > Components)" >&2
        exit 1
    fi
    device_type=$(xcrun simctl list runtimes available -j |
        /usr/bin/python3 -c '
import json, re, sys
rid = sys.argv[1]
runtime = next(x for x in json.load(sys.stdin)["runtimes"] if x["identifier"] == rid)
phones = [x for x in runtime.get("supportedDeviceTypes", []) if x.get("productFamily") == "iPhone"]
def rank(t):
    m = re.search(r"iPhone (\d+)", t["name"])
    return (int(m.group(1)) if m else 0, "Pro" in t["name"], "Max" not in t["name"])
print(max(phones, key=rank)["identifier"] if phones else "")' "$runtime")
    echo "Creating simulator $SIMULATOR_NAME ($device_type, $runtime)" >&2
    xcrun simctl create "$SIMULATOR_NAME" "$device_type" "$runtime"
}

# Takes the named simulator for this run: fails when another run holds it, and remembers to shut
# it down at the end when it wasn't already booted. Another thread's simulator is never touched.
claim_simulator() {
    local name="$1" udid="$2"
    local lock="${TMPDIR:-/tmp}/waypoint-test-$name.lock"
    if ! mkdir "$lock" 2>/dev/null; then
        local holder
        holder=$(cat "$lock/pid" 2>/dev/null || true)
        if [[ -n "$holder" ]] && kill -0 "$holder" 2>/dev/null; then
            echo "error: another test run (pid $holder) is using $name; wait for it or set WAYPOINT_SIMULATOR" >&2
            exit 1
        fi
        rm -rf "$lock"
        mkdir "$lock"
    fi
    echo $$ >"$lock/pid"
    LOCK_DIRS+=("$lock")
    local state
    state=$(xcrun simctl list devices -j |
        /usr/bin/python3 -c 'import json,sys; u=sys.argv[1]; d=json.load(sys.stdin)["devices"]; print(next((x["state"] for r in d.values() for x in r if x["udid"]==u), ""))' "$udid")
    if [[ "$state" != "Booted" ]]; then
        BOOTED_UDIDS+=("$udid")
    fi
}

# Runs Tuist through mise when mise pins it, and the installed Tuist otherwise.
tuist_cmd() {
    if command -v mise >/dev/null && [[ -f .mise.toml ]]; then
        mise exec -- tuist "$@"
    else
        tuist "$@"
    fi
}

# The package's unit tests on a simulator, built with warnings as errors: the one simulator build
# checks the warnings and runs the tests.
package_tests_on() {
    xcodebuild test "${XCODE_TEST_FLAGS[@]}" \
        -scheme Waypoint-Package \
        -destination "platform=iOS Simulator,id=$1" \
        SWIFT_TREAT_WARNINGS_AS_ERRORS=YES
}

# The example app's unit and UI tests on a simulator, with a result bundle named `name` in
# `.build/results` that the report reads its slowest tests from. Extra arguments go to xcodebuild.
example_tests_on() {
    local udid="$1" name="$2"
    shift 2
    local bundle="$RESULTS_DIR/$name.xcresult"
    mkdir -p "$RESULTS_DIR"
    xcodebuild test "${XCODE_TEST_FLAGS[@]}" \
        -workspace Example/WaypointExample.xcworkspace \
        -scheme WaypointExample \
        -destination "platform=iOS Simulator,id=$udid" \
        -resultBundlePath "$bundle" \
        "$@"
}

# What this run does.
RUN_HOST=true
RUN_SANITIZER=false
RUN_SIMULATOR=true
RUN_UI=false
RUN_RELEASE_REPORTS=false
RUN_DEVICE_BUILD=false
RUN_IOS17=false
case "$TIER" in
    quick)
        if ! $RUN_ALL; then
            detect_changes
        fi
        RUN_HOST=$CHANGED_PACKAGE
        RUN_SIMULATOR=$CHANGED_PACKAGE
        if $CHANGED_UI || $WITH_UI; then
            RUN_UI=true
        fi
        if [[ -n "$ONLY_TEST" ]]; then
            RUN_HOST=false
            RUN_SIMULATOR=false
        fi
        echo "quick: host $RUN_HOST, simulator $RUN_SIMULATOR, example UI $RUN_UI (compared with $BASE_REF)"
        ;;
    full | release)
        RUN_SANITIZER=true
        RUN_UI=true
        RUN_RELEASE_REPORTS=true
        if [[ "$TIER" == "release" ]]; then
            RUN_DEVICE_BUILD=true
            RUN_IOS17=true
        fi
        ;;
esac

step "Checking the concurrency guard rail" scripts/check-concurrency.sh

# `swift test` and the fixture check build with the same flags, so the core is built once.
SWIFT_FLAGS=(-Xswiftc -warnings-as-errors --jobs "$JOBS")
if $RUN_HOST; then
    step "Checking compile fixtures" env WAYPOINT_SWIFT_BUILD_FLAGS="${SWIFT_FLAGS[*]}" \
        scripts/check-compile-failures.sh
    step "swift test with warnings as errors (macOS host)" swift test "${SWIFT_FLAGS[@]}"
fi

if $RUN_SANITIZER; then
    step "swift test WaypointOSLogTests under the thread sanitizer (macOS host)" \
        swift test --sanitize=thread --scratch-path .build/thread-sanitizer --jobs "$JOBS" \
        --filter WaypointOSLogTests
fi

if $RUN_DEVICE_BUILD; then
    step "xcodebuild build Waypoint-Package for an iOS device with warnings as errors" \
        xcodebuild build -quiet -jobs "$JOBS" -scheme Waypoint-Package -destination generic/platform=iOS \
        SWIFT_TREAT_WARNINGS_AS_ERRORS=YES
fi

if $RUN_SIMULATOR || $RUN_UI; then
    UDID=$(project_simulator_udid)
    claim_simulator "$SIMULATOR_NAME" "$UDID"
fi

if $RUN_SIMULATOR; then
    step "xcodebuild test Waypoint-Package with warnings as errors on $SIMULATOR_NAME" package_tests_on "$UDID"
fi

if $RUN_UI || $RUN_IOS17; then
    step "tuist generate example app" tuist_cmd generate --path Example --no-open
fi

if $RUN_UI; then
    if [[ -n "$ONLY_TEST" ]]; then
        step "xcodebuild test $ONLY_TEST on $SIMULATOR_NAME" example_tests_on "$UDID" example-only -only-testing:"$ONLY_TEST"
    else
        step "xcodebuild test example app on $SIMULATOR_NAME" example_tests_on "$UDID" example
    fi
fi

# A system link (#147) and a route with no destination in its stack (#166) must be reported in
# release builds too, so their UI tests run again with the app and the tests built in the release
# configuration.
if $RUN_RELEASE_REPORTS; then
    step "xcodebuild test release reports (Release) on $SIMULATOR_NAME" \
        example_tests_on "$UDID" release-reports \
        -configuration Release \
        -only-testing:WaypointExampleUITests/SystemLinkTests \
        -only-testing:WaypointExampleUITests/MissingDestinationTests
fi

# The minimum iOS version runs last, on its own simulator, which the script never creates: it
# needs the iOS 17 runtime, not the newest one.
if $RUN_IOS17; then
    IOS17_UDID=$(find_simulator "$IOS17_SIMULATOR_NAME")
    if [[ -z "$IOS17_UDID" ]]; then
        echo "error: no simulator named $IOS17_SIMULATOR_NAME; create one on an iOS 17 runtime" >&2
        exit 1
    fi
    claim_simulator "$IOS17_SIMULATOR_NAME" "$IOS17_UDID"
    step "xcodebuild test Waypoint-Package on $IOS17_SIMULATOR_NAME" package_tests_on "$IOS17_UDID"
    step "xcodebuild test example app on $IOS17_SIMULATOR_NAME" example_tests_on "$IOS17_UDID" example-ios17
fi
