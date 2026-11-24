#!/usr/bin/env bash
#
#  test-mac.sh
#  Waypoint
#
#  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
#  Copyright © 2026 Yousef Mohamed. MIT License.
#
# Runs the Mac test layers in one of three tiers, so a run while working loads the Mac far less
# than the run before a merge (planning #395):
#
# - quick (the default, while working on a branch): the concurrency guard rail, the compile
#   fixtures, the host build and unit tests with warnings as errors, and the package tests on the
#   project simulator with warnings as errors. The example app's unit and UI tests join when the
#   branch changes `Example/` or a renderer, or with --ui. Parts the branch can't affect are
#   skipped.
# - full (before every merge): every check, whatever changed. Adds the example app's unit and UI
#   tests, the unified log tests under the thread sanitizer, the system link and missing
#   destination UI tests again in the release configuration, and the check that Tuist's test
#   hashes see every part of the package. Tuist's selective testing may skip an example test target
#   that already passed on the same inputs (planning #429), unless the branch changes a file those
#   hashes don't cover.
# - release (before a tag): full, plus a build for an iOS device with warnings as errors, and the
#   package and example app tests again on the iOS 17 simulator. It never skips a test.
# - coverage (on `main`, as TESTING.md schedules it): every example app test, never skipped, on
#   `main`'s own commit, then `tuist coverage complete`, so the Tuist dashboard charts `main`'s
#   code coverage (planning #431). It refuses any other commit, and runs none of the package's
#   steps.
#
# Every run that uses Tuist collects code coverage (`Example/Tuist.swift`, planning #431) and tells
# Tuist the branch it tests through GITHUB_HEAD_REF, which Tuist reads on any machine: the branch
# the clone is on, or, on a merge batch's detached commit, the batch's branches joined with `+`. A
# run for one pull request (WAYPOINT_PULL_REQUEST) also tells Tuist that pull request through
# GITHUB_REF, so Tuist posts its run report on it: the tests run and skipped, and links to the runs.
# Tuist takes the commit from the checkout, so GITHUB_SHA is never set.
#
# Each build is made once: the host build with warnings as errors is the build `swift test` runs,
# and the simulator build with warnings as errors is the build its tests run. Builds use at most
# WAYPOINT_JOBS jobs, only one run uses a simulator at a time, and the script shuts down each
# simulator it booted. The example app's tests run through `tuist test`, which also generates the
# project, on WAYPOINT_UI_WORKERS temporary copies of the simulator at once (planning #427); Xcode
# makes the copies and removes them, and the package's tests never use copies. It ends with the time
# each step took and the 10 slowest tests of each simulator test step, the package's included
# (planning #421), read from its result bundle.
#
# One run at a time: the script first takes a run lock that every clone of the repo shares
# (planning #420). A second run stops at once and names the run that holds it. A lock left by a run
# that is no longer going is cleared; a lock whose run is still going is never touched.
#
# Usage: scripts/test-mac.sh [quick|full|release|coverage] [--ui] [--all] [--only <Target/Class[/test]>] [--plan]
#   --ui    quick also runs the example app's unit and UI tests.
#   --all   quick runs every part, whatever the branch changed.
#   --only quick runs only the guard rail and this example UI test (passed to `tuist test
#   --test-targets`),
#           for example `--only WaypointExampleUITests/StackTests/testPushAndBack`.
#   --plan  prints what the run would do, including whether Tuist's selective testing is on, and
#           stops: no lock, no simulator, no build.
#
# Environment:
#   WAYPOINT_SIMULATOR        the project simulator (default waypoint-01), created when missing.
#   WAYPOINT_IOS17_SIMULATOR  the iOS 17 simulator for release (default waypoint-02); must exist.
#   WAYPOINT_JOBS             build jobs (default half the performance cores, at least 2).
#   WAYPOINT_UI_WORKERS       simulator copies the example app's tests run on at once (default 2;
#                             1 runs them on the simulator itself).
#   WAYPOINT_TUIST_OFFLINE    1 turns off Tuist's server features: selective testing and uploads
#                             (default 0).
#   WAYPOINT_PULL_REQUEST     the number of the pull request this run tests, whose page gets
#                             Tuist's run report; unset for a merge batch of several branches.
#   WAYPOINT_BASE             what the branch is compared with (default origin/main), for what
#                             quick runs and whether selective testing is on.
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
PLAN_ONLY=false
while [[ $# -gt 0 ]]; do
    case "$1" in
        quick | full | release | coverage) TIER="$1" ;;
        --ui) WITH_UI=true ;;
        --all) RUN_ALL=true ;;
        --plan) PLAN_ONLY=true ;;
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
    echo "error: --only works with quick; full, release and coverage run every test" >&2
    exit 2
fi

SIMULATOR_NAME="${WAYPOINT_SIMULATOR:-waypoint-01}"
IOS17_SIMULATOR_NAME="${WAYPOINT_IOS17_SIMULATOR:-waypoint-02}"
BASE_REF="${WAYPOINT_BASE:-origin/main}"
RUN_LOCK="${WAYPOINT_RUN_LOCK:-/tmp/waypoint-test-mac.lock}"

# A coverage run marks `main`'s commit complete on the Tuist dashboard (planning #431), so it runs
# only on `main`'s own commit, unchanged, which is BASE_REF's: checked out as `main`, or detached
# there, as the preflight's checkout leaves it. Never on another branch or a merge batch, whose
# commits never land on `main`: a squash or a merge commit makes new commits. Tuist is told the
# branch is `main` either way.
if [[ "$TIER" == coverage ]]; then
    current_branch=$(git symbolic-ref -q --short HEAD || true)
    if [[ -n "$current_branch" && "$current_branch" != main ]]; then
        echo "error: a coverage run runs on main only, not on $current_branch" >&2
        exit 2
    fi
    if [[ -n "$(git status --porcelain)" ]]; then
        echo "error: a coverage run needs a clean main; this clone has changes" >&2
        exit 2
    fi
    if [[ "$(git rev-parse HEAD)" != "$(git rev-parse -q --verify "$BASE_REF^{commit}" || true)" ]]; then
        echo "error: a coverage run runs on $BASE_REF's commit only; check it out first" >&2
        exit 2
    fi
    export GITHUB_HEAD_REF=main
    if [[ "${WAYPOINT_TUIST_OFFLINE:-0}" == 1 ]]; then
        echo "error: a coverage run uploads to Tuist, so it can't run with WAYPOINT_TUIST_OFFLINE=1" >&2
        exit 2
    fi
fi

# The branch Tuist shows for this run's tests and builds (planning #431). Tuist reads
# GITHUB_HEAD_REF on any machine, ahead of `git branch --show-current`, which names nothing on a
# detached commit. A merge batch (scripts/merge-batch.sh) is a detached chain of merge commits by
# "Merge batch": its name is the merged branches, in merge order, joined with `+`. Any other
# detached commit, such as the preflight's `git checkout --detach origin/<branch>`, takes the
# `origin` branches that point at it (`main` only when no other does), and none when no branch does.
# A GITHUB_HEAD_REF already set wins, except in a coverage run, which is always `main`.
tuist_branch() {
    local branch commit subject names=()
    local merge_subject="^Merge (remote-tracking )?branch '([^']+)'"
    if branch=$(git symbolic-ref -q --short HEAD); then
        echo "$branch"
        return
    fi
    commit=$(git rev-parse -q --verify HEAD) || return 0
    while [[ "$(git log -1 --format=%ae "$commit")" == merge-batch@localhost ]]; do
        subject=$(git log -1 --format=%s "$commit")
        if [[ "$subject" =~ $merge_subject ]]; then
            names=("${BASH_REMATCH[2]#origin/}" ${names[@]+"${names[@]}"})
        fi
        commit=$(git rev-parse -q --verify "$commit^1") || break
    done
    if [[ ${#names[@]} -eq 0 ]]; then
        local ref on_main=false
        while IFS= read -r ref; do
            ref="${ref#refs/remotes/origin/}"
            case "$ref" in
                HEAD | refs/*) ;;
                main) on_main=true ;;
                *) names+=("$ref") ;;
            esac
        done < <(git branch -r --points-at HEAD --format='%(refname)')
        if [[ ${#names[@]} -eq 0 ]] && $on_main; then
            names=(main)
        fi
    fi
    if [[ ${#names[@]} -gt 0 ]]; then
        (
            IFS=+
            echo "${names[*]}"
        )
    fi
}
if [[ -z "${GITHUB_HEAD_REF:-}" ]]; then
    TUIST_BRANCH=$(tuist_branch)
    if [[ -n "$TUIST_BRANCH" ]]; then
        export GITHUB_HEAD_REF="$TUIST_BRANCH"
    fi
fi

# The pull request Tuist posts its run report on. Tuist reads GITHUB_REF on any
# machine, and its GitHub app comments on the pull request a `refs/pull/<n>/...` ref names, with
# the commit the checkout is on. The script sets GITHUB_REF itself or clears it, so a value left in
# the shell never sends a report to the wrong pull request, and stops when the pull request's
# branch (read with `gh`, read-only) isn't the branch under test; when `gh` can't answer, no report.
# None for a coverage run (it tests `main`), an offline run (it uploads nothing), or a merge batch
# of several branches (one report can't name them all).
TUIST_PULL_REQUEST=""
unset GITHUB_REF
if [[ -n "${WAYPOINT_PULL_REQUEST:-}" ]]; then
    if [[ ! "$WAYPOINT_PULL_REQUEST" =~ ^[1-9][0-9]*$ ]]; then
        echo "error: WAYPOINT_PULL_REQUEST must be a pull request number, not '$WAYPOINT_PULL_REQUEST'" >&2
        exit 2
    fi
    if [[ "$TIER" == coverage ]]; then
        echo "note: a coverage run tests main, so it posts no run report on pull request $WAYPOINT_PULL_REQUEST" >&2
    elif [[ "${WAYPOINT_TUIST_OFFLINE:-0}" == 1 ]]; then
        echo "note: an offline run uploads nothing, so it posts no run report on pull request $WAYPOINT_PULL_REQUEST" >&2
    elif [[ "${GITHUB_HEAD_REF:-}" == *+* ]]; then
        echo "note: a merge batch tests several branches, so it posts no run report on pull request $WAYPOINT_PULL_REQUEST" >&2
    elif ! pr_branch=$(gh pr view "$WAYPOINT_PULL_REQUEST" --repo joeoct-oss/Waypoint \
        --json headRefName --jq .headRefName 2>/dev/null) || [[ -z "$pr_branch" ]]; then
        echo "note: gh couldn't say which branch pull request $WAYPOINT_PULL_REQUEST is, so this run posts no run report" >&2
    elif [[ "$pr_branch" != "${GITHUB_HEAD_REF:-}" ]]; then
        # A wrong number would post this run's report on another pull request.
        echo "error: pull request $WAYPOINT_PULL_REQUEST is $pr_branch, but this run tests ${GITHUB_HEAD_REF:-no branch}" >&2
        exit 2
    else
        TUIST_PULL_REQUEST="$WAYPOINT_PULL_REQUEST"
        export GITHUB_REF="refs/pull/$TUIST_PULL_REQUEST/head"
    fi
fi
# How long each tier may run before TESTING.md calls it hung, in minutes.
case "$TIER" in
    quick) STOP_AFTER_MINUTES=30 ;;
    full) STOP_AFTER_MINUTES=35 ;;
    release) STOP_AFTER_MINUTES=50 ;;
    coverage) STOP_AFTER_MINUTES=30 ;;
esac

# Half the performance cores, so the Mac and other simulators stay usable during a run.
default_jobs() {
    local cores
    cores=$(sysctl -n hw.perflevel0.physicalcpu 2>/dev/null || sysctl -n hw.physicalcpu)
    echo $((cores / 2 > 2 ? cores / 2 : 2))
}
JOBS="${WAYPOINT_JOBS:-$(default_jobs)}"

# Settings the package's simulator tests run with: the job cap, and no parallel testing, which
# would clone the simulator once per worker.
XCODE_TEST_FLAGS=(-quiet -jobs "$JOBS" -parallel-testing-enabled NO)

# The example app's tests run on this many simulator copies at once (planning #427), so they take
# about half as long.
UI_WORKERS="${WAYPOINT_UI_WORKERS:-2}"
if [[ "$UI_WORKERS" -gt 1 ]]; then
    EXAMPLE_PARALLEL_FLAGS=(-parallel-testing-enabled YES -parallel-testing-worker-count "$UI_WORKERS")
else
    EXAMPLE_PARALLEL_FLAGS=(-parallel-testing-enabled NO)
fi

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

# This run's result bundles, one per simulator test step, whose slowest tests the report lists.
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
    # A run stopped during a package step may leave Tuist's project aside (planning #429). A run
    # turned away at the run lock leaves it alone: the run holding the lock may be in that step.
    if $OWNS_RUN_LOCK; then
        scripts/package-xcodebuild.sh --restore || true
    fi
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
if ! $PLAN_ONLY; then
    take_run_lock
fi
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
# CHANGED_OUTSIDE_TEST_HASHES says whether the branch changes a file that Tuist's test hashes
# don't cover (planning #429): those hashes take the package's and the example app's sources, so a
# change to a script, a manifest, a tool version or CI could change a result while every hash stays
# the same. Selective testing is off then.
CHANGED_PACKAGE=true
CHANGED_UI=true
CHANGED_OUTSIDE_TEST_HASHES=true
detect_changes() {
    local merge_base files
    if ! merge_base=$(git merge-base HEAD "$BASE_REF" 2>/dev/null); then
        echo "note: $BASE_REF not found, so every part runs and selective testing is off" >&2
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
    CHANGED_OUTSIDE_TEST_HASHES=false
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
        # The package's tests never run under selective testing, so a change to them can't skip
        # one. The example app's manifests are left out of the hashed files on purpose: what Tuist
        # hashes of them isn't documented.
        case "$file" in
            Example/Project.swift | Example/Tuist.swift | Example/Tuist/*) CHANGED_OUTSIDE_TEST_HASHES=true ;;
            Sources/* | Tests/* | Example/*) ;;
            *) CHANGED_OUTSIDE_TEST_HASHES=true ;;
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

# The package's unit tests on the simulator `udid`, built with warnings as errors: the one
# simulator build checks the warnings and runs the tests. The result bundle `bundle_name` in
# `.build/results` puts the step's test count and slowest tests in the report, as the example app's
# steps do.
package_tests_on() {
    local udid="$1" bundle_name="$2"
    mkdir -p "$RESULTS_DIR"
    scripts/package-xcodebuild.sh test "${XCODE_TEST_FLAGS[@]}" \
        -scheme Waypoint-Package \
        -destination "platform=iOS Simulator,id=$udid" \
        -resultBundlePath "$RESULTS_DIR/$bundle_name.xcresult" \
        SWIFT_TREAT_WARNINGS_AS_ERRORS=YES
}

# Prints the iOS version of the simulator `udid`, such as 27.2, read from its runtime's name.
simulator_os() {
    xcrun simctl list devices -j |
        /usr/bin/python3 -c 'import json,re,sys; u=sys.argv[1]; d=json.load(sys.stdin)["devices"]; print(next((re.sub(r".*iOS-(\d+)-(\d+).*", r"\1.\2", k) for k, r in d.items() for x in r if x["udid"]==u), ""))' "$1"
}

# The example app's unit and UI tests through `tuist test`, which generates the project first, on
# the simulator `name`, with a result bundle named `bundle_name` in `.build/results` that the
# report reads its slowest tests from (planning #427). Extra arguments go to `tuist test`, such as
# `--test-targets` or `--configuration`.
#
# Tuist's binary cache is off (planning #429): with the package in Tuist's graph it could swap the
# package's targets for cached binaries, and every run builds the package from source with its
# warnings as errors. Every run's results go to the project's Tuist dashboard (Test Insights: run
# times and flaky tests). Selective testing, which skips a test
# target that already passed with the same hash, is on in quick and full runs unless the branch
# changes a file the hashes don't cover; release, `--only`, `--ui` and `--all` run every test
# they name. A run narrowed to a class or a test never records a pass, so only whole targets are
# ever skipped (planning #429). Tuist's quarantine is never applied (`--skip-quarantine`): a flaky
# test still runs and still fails the run. All of it uses the Tuist server project in
# `Example/Tuist.swift`; WAYPOINT_TUIST_OFFLINE=1 turns every server feature off, for a Mac that
# isn't signed in. The example app builds into a derived data folder of its own in the clone, not
# Xcode's shared one. On 2026-11-24 the app failed to build in the shared folder after the package
# moved into Tuist's graph (planning #429): `package` symbols were "inaccessible", although the
# generated targets set the package name, and the same build in a fresh folder was clean. Older
# builds of the same workspace had left module state the new settings didn't invalidate. A folder
# only these runs use starts clean on every Mac and still builds incrementally from one run to the
# next.
EXAMPLE_DERIVED_DATA="$PWD/.build/example-derived-data"
# The release reports step builds into a folder of its own (planning #431). Tuist reads a run's
# coverage from one products folder of the derived data, the one holding most of the run's test
# bundles and the newest on a tie, whatever the configuration: with Release products beside the
# Debug ones, it read the uninstrumented Release builds and uploaded no covered file (measured
# 2026-11-24).
RELEASE_REPORTS_DERIVED_DATA="$PWD/.build/release-reports-derived-data"

example_tests_on() {
    local udid="$1" simulator="$2" bundle_name="$3"
    shift 3
    local bundle="$RESULTS_DIR/$bundle_name.xcresult"
    local os
    os=$(simulator_os "$udid")
    local tuist_flags=() offline_settings=()
    case "$SELECTIVE_TESTING" in
        offline)
            tuist_flags=(--no-selective-testing --no-binary-cache --no-upload --inspect-mode off --skip-quarantine)
            # The build's post-action reads it too, so it sends no build timings.
            offline_settings=(WAYPOINT_TUIST_OFFLINE=1)
            ;;
        off) tuist_flags=(--no-selective-testing --no-binary-cache --skip-quarantine) ;;
        on) tuist_flags=(--no-binary-cache --skip-quarantine) ;;
    esac
    mkdir -p "$RESULTS_DIR"
    # Release products an older run left beside the Debug ones would be read for coverage instead.
    if [[ "$EXAMPLE_DERIVED_DATA" != "$RELEASE_REPORTS_DERIVED_DATA" ]]; then
        rm -rf "$EXAMPLE_DERIVED_DATA/Build/Products/Release-iphonesimulator"
    fi
    # The package comes through Tuist's package integration, which `tuist install` resolves.
    tuist_cmd install --path Example
    tuist_cmd test WaypointExample \
        --path Example \
        --device "$simulator" \
        ${os:+--os "$os"} \
        ${tuist_flags[@]+"${tuist_flags[@]}"} \
        -T "$bundle" \
        "$@" \
        -- -quiet -jobs "$JOBS" -derivedDataPath "$EXAMPLE_DERIVED_DATA" "${EXAMPLE_PARALLEL_FLAGS[@]}" \
        ${offline_settings[@]+"${offline_settings[@]}"}
}

# What this run does.
RUN_HOST=true
RUN_SANITIZER=false
RUN_HASH_CHECK=false
RUN_SIMULATOR=true
RUN_UI=false
RUN_RELEASE_REPORTS=false
RUN_DEVICE_BUILD=false
RUN_IOS17=false
RUN_COVERAGE_COMPLETE=false
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
    coverage)
        # Only the example app's tests, every one of them, on `main`'s own commit.
        RUN_HOST=false
        RUN_SIMULATOR=false
        RUN_UI=true
        RUN_COVERAGE_COMPLETE=true
        ;;
    full | release)
        # Every part runs; the changes decide only whether selective testing is on.
        detect_changes
        RUN_SANITIZER=true
        RUN_HASH_CHECK=true
        RUN_UI=true
        RUN_RELEASE_REPORTS=true
        if [[ "$TIER" == "release" ]]; then
            RUN_DEVICE_BUILD=true
            RUN_IOS17=true
        fi
        ;;
esac

# Whether `tuist test` may skip a test target that already passed with the same hash (selective
# testing, planning #429). Its hash covers the package's and the example app's sources, so it is on
# in quick and full runs, and off when the branch changes a file the hashes don't cover, or when the
# branch's changes can't be told (no BASE_REF, or no changes at all). A release run, a test asked
# for by name, --ui and --all always run every test.
if [[ "${WAYPOINT_TUIST_OFFLINE:-0}" == 1 ]]; then
    SELECTIVE_TESTING=offline
elif [[ "$TIER" == release || "$TIER" == coverage || -n "$ONLY_TEST" ]] || $WITH_UI || $RUN_ALL || $CHANGED_OUTSIDE_TEST_HASHES; then
    SELECTIVE_TESTING=off
else
    SELECTIVE_TESTING=on
fi
# The release reports step never skips: offline stays offline, and on becomes off.
RELEASE_REPORTS_SELECTIVE_TESTING="$SELECTIVE_TESTING"
if [[ "$SELECTIVE_TESTING" == on ]]; then
    RELEASE_REPORTS_SELECTIVE_TESTING=off
fi
# The report says whether a passed target could have been skipped (TESTING.md, Report the result).
echo "selective testing: $SELECTIVE_TESTING, release reports selective testing $RELEASE_REPORTS_SELECTIVE_TESTING"
echo "tuist branch: ${GITHUB_HEAD_REF:-none}"
echo "tuist pull request: ${TUIST_PULL_REQUEST:-none}"
if $PLAN_ONLY; then
    echo "plan: $TIER, example tests $RUN_UI, selective testing $SELECTIVE_TESTING, release reports selective testing $RELEASE_REPORTS_SELECTIVE_TESTING, tuist branch ${GITHUB_HEAD_REF:-none}, tuist pull request ${TUIST_PULL_REQUEST:-none}"
    trap - EXIT
    exit 0
fi

# The daily coverage run says whether a newer stable Tuist than the pinned one is out
# (planning #434). It only reports, so it is no step and never fails the run.
if $RUN_COVERAGE_COMPLETE; then
    scripts/check-tuist-version.sh
fi

step "Checking the concurrency guard rail" scripts/check-concurrency.sh
step "Checking the example app's isolation" scripts/check-example-isolation.sh
step "Checking that app code imports Waypoint once" scripts/check-single-import.sh

# `swift test` and the fixture check build with the same flags, so the core is built once.
SWIFT_FLAGS=(-Xswiftc -warnings-as-errors --jobs "$JOBS")
if $RUN_HOST; then
    step "Checking compile fixtures" env WAYPOINT_SWIFT_BUILD_FLAGS="${SWIFT_FLAGS[*]}" \
        scripts/check-compile-failures.sh
    step "swift test with warnings as errors (macOS host)" swift test "${SWIFT_FLAGS[@]}"
fi

# Selective testing is only as safe as Tuist's hashes: they must change with every part of the
# package and the app (planning #429). Full and release runs check it.
if $RUN_HASH_CHECK; then
    step "Checking that Tuist's test hashes see the package" scripts/check-selective-testing-hashes.sh
fi

if $RUN_SANITIZER; then
    step "swift test WaypointOSLogTests under the thread sanitizer (macOS host)" \
        swift test --sanitize=thread --scratch-path .build/thread-sanitizer --jobs "$JOBS" \
        --filter WaypointOSLogTests
fi

if $RUN_DEVICE_BUILD; then
    step "xcodebuild build Waypoint-Package for an iOS device with warnings as errors" \
        scripts/package-xcodebuild.sh build -quiet -jobs "$JOBS" -scheme Waypoint-Package -destination generic/platform=iOS \
        SWIFT_TREAT_WARNINGS_AS_ERRORS=YES
fi

if $RUN_SIMULATOR || $RUN_UI; then
    UDID=$(project_simulator_udid)
    claim_simulator "$SIMULATOR_NAME" "$UDID"
fi

if $RUN_SIMULATOR; then
    step "xcodebuild test Waypoint-Package with warnings as errors on $SIMULATOR_NAME" package_tests_on "$UDID" package
fi

if $RUN_UI; then
    if [[ -n "$ONLY_TEST" ]]; then
        step "tuist test $ONLY_TEST on $SIMULATOR_NAME" \
            example_tests_on "$UDID" "$SIMULATOR_NAME" example-only --test-targets "$ONLY_TEST"
    else
        step "tuist test example app on $SIMULATOR_NAME" example_tests_on "$UDID" "$SIMULATOR_NAME" example
    fi
fi

# A coverage run tells Tuist that `main`'s commit has every run it will get, so the dashboard
# charts its coverage (planning #431). It runs only after the example app's tests passed.
if $RUN_COVERAGE_COMPLETE; then
    step "tuist coverage complete" tuist_cmd coverage complete --path Example
fi

# A system link (planning #349) and a route with no destination in its stack (planning #361) must be
# reported in release builds too, so their UI tests run again with the app and the tests built in
# the release configuration. They always run: the Debug step just passed their target, and nothing
# shows that Tuist's hash tells the two configurations apart (planning #429).
#
# It collects no coverage (planning #431): it tests two classes again in Release, after the Debug
# step measured them, so it would add about a minute and nothing new. It always runs every test it
# names, so the different hash costs no reuse. It builds into its own derived data folder, so the
# example step's coverage is read from Debug.
release_reports_on() {
    local SELECTIVE_TESTING="$RELEASE_REPORTS_SELECTIVE_TESTING"
    local EXAMPLE_DERIVED_DATA="$RELEASE_REPORTS_DERIVED_DATA"
    TUIST_COVERAGE_ENABLED=0 TUIST_COVERAGE_UPLOAD=0 example_tests_on "$@"
}
if $RUN_RELEASE_REPORTS; then
    step "tuist test release reports (Release) on $SIMULATOR_NAME" \
        release_reports_on "$UDID" "$SIMULATOR_NAME" release-reports \
        --configuration Release \
        --test-targets WaypointExampleUITests/SystemLinkTests \
        --test-targets WaypointExampleUITests/MissingDestinationTests
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
    step "xcodebuild test Waypoint-Package on $IOS17_SIMULATOR_NAME" package_tests_on "$IOS17_UDID" package-ios17
    step "tuist test example app on $IOS17_SIMULATOR_NAME" \
        example_tests_on "$IOS17_UDID" "$IOS17_SIMULATOR_NAME" example-ios17
fi
