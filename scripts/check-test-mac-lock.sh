#!/usr/bin/env bash
#
#  check-test-mac-lock.sh
#  Waypoint
#
#  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
#  Copyright © 2026 Yousef Mohamed. MIT License.
#
# Checks the run lock of scripts/test-mac.sh (planning #420) with stand-in tools, so it runs on Linux and
# on the Mac without Xcode or a simulator:
#
# - a second run while one holds the lock stops at once and runs nothing;
# - a lock left by a run that has ended, or pointing at a process that isn't a test run, is
#   cleared and the run goes on;
# - the lock is gone after a pass, a failure, and a stop with TERM, and a stopped run never says it passed.
#
# It also checks the phase timeline and the memory lines every report prints, that the release
# reports step runs without parallel workers, and that a run removes only the simulator copies it
# made, by UDID (planning #489).
#
# It also checks what the script hands Tuist: selective testing per tier (planning #429), the derived data
# folder after `--` (planning #430), the branch through GITHUB_HEAD_REF and the `coverage` tier on `main`
# (planning #431), the pull request through GITHUB_REF, and that the Build Insights
# post-action runs the Tuist mise pins (planning #431).
#
# Each case runs `test-mac.sh quick --only` with its own lock path and temporary folder, so a
# real run on the Mac is never touched.
#
# Usage: scripts/check-test-mac-lock.sh

set -euo pipefail

cd "$(dirname "$0")/.."

# The lock and the script use these; without `ps` a live lock would look stale.
missing=()
for tool in ps pgrep pkill /usr/bin/python3; do
    command -v "$tool" >/dev/null || missing+=("$tool")
done
if [[ ${#missing[@]} -gt 0 ]]; then
    echo "error: the run lock check needs ${missing[*]} (on Linux: the procps and python3 packages)" >&2
    exit 1
fi

WORK=$(mktemp -d)
cleanup() {
    rm -rf "$WORK"
}
trap cleanup EXIT

STUBS="$WORK/bin"
mkdir -p "$STUBS"
CALLS="$WORK/calls"
: >"$CALLS"

# Stand-ins for the tools the script calls. `tuist test`, which runs the example app's tests,
# sleeps STUB_SECONDS and exits STUB_STATUS.
cat >"$STUBS/xcrun" <<'EOF'
#!/usr/bin/env bash
echo "xcrun $*" >>"$STUB_CALLS"
# Xcode's own device set lists the copies in STUB_CLONES, a file the stand-in tuist may change.
if [[ "$1 $2" == "simctl --set" ]]; then
    if [[ "$*" == *"list devices"* ]]; then
        # STUB_CLONES_FAIL makes the first listing fail, as simctl can.
        if [[ -n "${STUB_CLONES_FAIL:-}" && ! -e "$STUB_CLONES_FAIL" ]]; then
            touch "$STUB_CLONES_FAIL"
            exit 1
        fi
        cat "${STUB_CLONES:-/dev/null}"
    fi
    exit 0
fi
if [[ "$1 $2" == "simctl shutdown" && -L "$WAYPOINT_RUN_LOCK" ]]; then
    echo "shutdown while the run lock was held" >>"$STUB_CALLS"
fi
if [[ "$*" == *"list devices"* ]]; then
    echo '{"devices":{"com.apple.CoreSimulator.SimRuntime.iOS-27-2":[{"name":"waypoint-01","udid":"STUB-UDID","state":"Shutdown"}]}}'
fi
EOF
cat >"$STUBS/xcodebuild" <<'EOF'
#!/usr/bin/env bash
echo "xcodebuild $*" >>"$STUB_CALLS"
# What the build prints, such as a compiler warning.
[[ -z "${STUB_XCODEBUILD_OUTPUT:-}" ]] || echo "$STUB_XCODEBUILD_OUTPUT"
# The wait runs in a grandchild of test-mac.sh, as a step's script and its tools do.
"$(dirname "$0")/stub-grandchild" "${STUB_SECONDS:-0}"
exit "${STUB_STATUS:-0}"
EOF
cat >"$STUBS/stub-grandchild" <<'EOF'
#!/usr/bin/env bash
sleep "$1"
EOF
cat >"$STUBS/tuist" <<'EOF'
#!/usr/bin/env bash
echo "tuist $*" >>"$STUB_CALLS"
if [[ "$1" == test ]]; then
    echo "GITHUB_REF seen by tuist test: ${GITHUB_REF:-}" >>"$STUB_CALLS"
    echo "TUIST_WAYPOINT_BINARY_CACHE seen by tuist test: ${TUIST_WAYPOINT_BINARY_CACHE:-}" >>"$STUB_CALLS"
    echo "WAYPOINT_TUIST_TEST_RUN seen by tuist test: ${WAYPOINT_TUIST_TEST_RUN:-}" >>"$STUB_CALLS"
    # The tests boot simulator copies: STUB_CLONES_DURING replaces what Xcode's device set lists.
    [[ -z "${STUB_CLONES_DURING:-}" ]] || cp "$STUB_CLONES_DURING" "$STUB_CLONES"
    "$(dirname "$0")/stub-grandchild" "${STUB_SECONDS:-0}"
    exit "${STUB_STATUS:-0}"
fi
EOF
# The script runs Tuist through mise where mise is installed; the stand-in runs what follows `--`,
# so the stand-in tuist runs, never the real one.
cat >"$STUBS/mise" <<'EOF'
#!/usr/bin/env bash
while [[ $# -gt 0 && "$1" != "--" ]]; do
    shift
done
shift
exec "$@"
EOF
# `gh pr view` names the pull request's branch: STUB_PR_BRANCH, or fails when that is empty.
cat >"$STUBS/gh" <<'EOF'
#!/usr/bin/env bash
[[ -n "${STUB_PR_BRANCH:-}" ]] || exit 1
echo "$STUB_PR_BRANCH"
EOF
cat >"$STUBS/sysctl" <<'EOF'
#!/usr/bin/env bash
echo 4
EOF
# `swift` too, so the package's steps never build or test a copied tree for real: the check
# needs no Swift toolchain, and CI runs it on a runner host that has none.
cat >"$STUBS/swift" <<'EOF'
#!/usr/bin/env bash
echo "swift $*" >>"${STUB_CALLS:-/dev/null}"
EOF
chmod +x "$STUBS"/*

FAILURES=0
fail() {
    echo "FAIL: $1" >&2
    FAILURES=$((FAILURES + 1))
}
pass() {
    echo "ok: $1"
}

LOCK="$WORK/run.lock"

# Runs test-mac.sh with the stand-ins. Extra environment goes first, as NAME=value words.
run_script() {
    env PATH="$STUBS:$PATH" TMPDIR="$WORK" STUB_CALLS="$CALLS" WAYPOINT_RUN_LOCK="$LOCK" \
        WAYPOINT_SIMULATOR=waypoint-01 "$@" \
        scripts/test-mac.sh quick --only WaypointExampleUITests/StackTests/testPushAndBack
}

lock_gone() {
    [[ ! -e "$LOCK" && ! -L "$LOCK" && ! -e "$LOCK.info" ]]
}

# 1. A pass leaves no lock, and the lock goes only after the simulator is shut down.
if run_script >"$WORK/1.log" 2>&1 && lock_gone; then
    pass "a passing run releases the lock"
else
    fail "a passing run releases the lock (log: $(tail -3 "$WORK/1.log"))"
fi
if grep -q "^xcrun simctl shutdown" "$CALLS" && grep -q "shutdown while the run lock was held" "$CALLS"; then
    pass "the run lock goes after the simulator is shut down"
else
    fail "the run lock goes after the simulator is shut down"
fi
if grep -q "^tuist test WaypointExample" "$CALLS"; then
    pass "the stand-in tuist ran, never the real one"
else
    fail "the stand-in tuist ran, never the real one"
fi
# The example app's tests run through `tuist test` (planning #427): on the project simulator, into a
# result bundle, with three parallel workers (planning #447).
TUIST_CALL=$(grep "^tuist test WaypointExample" "$CALLS" | head -1)
for part in "--path Example" "--device waypoint-01" \
    "--os 27.2" "--skip-quarantine" \
    "-T .build/results/example-only.xcresult" \
    "--test-targets WaypointExampleUITests/StackTests/testPushAndBack" \
    "-parallel-testing-enabled YES" "-parallel-testing-worker-count 3"; do
    if [[ "$TUIST_CALL" == *" $part"* ]]; then
        pass "tuist test gets $part"
    else
        fail "tuist test gets $part (call: $TUIST_CALL)"
    fi
done
# A quick run may take the package's modules from Tuist's binary cache (planning #441): Example/Tuist.swift
# turns the cache's profile on through TUIST_WAYPOINT_BINARY_CACHE=1, and `--destination simulator`
# matches the simulator slices that runs warm.
if [[ "$TUIST_CALL" != *"--no-binary-cache"* && "$TUIST_CALL" == *" --destination simulator"* ]] &&
    grep -q "^TUIST_WAYPOINT_BINARY_CACHE seen by tuist test: 1$" "$CALLS"; then
    pass "a quick run's example step may use the binary cache"
else
    fail "a quick run's example step may use the binary cache (call: $TUIST_CALL)"
fi
# `tuist test` sends its own results, so the scheme's Test Insights post-action must skip (planning #456).
if grep -q "^WAYPOINT_TUIST_TEST_RUN seen by tuist test: 1$" "$CALLS" &&
    [[ "$TUIST_CALL" == *" -- "*" WAYPOINT_TUIST_TEST_RUN=1"* ]]; then
    pass "tuist test tells the scheme's test post-action to skip"
else
    fail "tuist test tells the scheme's test post-action to skip"
fi
if ! grep -q "^tuist cache" "$CALLS"; then
    pass "a quick run doesn't warm the binary cache"
else
    fail "a quick run doesn't warm the binary cache"
fi
# The derived data folder goes to xcodebuild after `--`, the way Tuist asks (planning #430).
if [[ "${TUIST_CALL#* -- }" == *"-derivedDataPath $PWD/.build/example-derived-data"* &&
    "$TUIST_CALL" != *"--derived-data-path"* ]]; then
    pass "tuist test passes -derivedDataPath after --"
else
    fail "tuist test passes -derivedDataPath after -- (call: $TUIST_CALL)"
fi
if grep -q "^selective testing: off, release reports selective testing off$" "$WORK/1.log"; then
    pass "the log says selective testing is off for the release reports step"
else
    fail "the log says selective testing is off for the release reports step ($(grep '^selective' "$WORK/1.log"))"
fi
# The package comes through Tuist's package integration, which `tuist install` resolves first
# (planning #429).
INSTALL_LINE=$(grep -m1 -n "^tuist install --path Example" "$CALLS" | cut -d: -f1 || true)
TEST_LINE=$(grep -m1 -n "^tuist test" "$CALLS" | cut -d: -f1 || true)
if [[ -n "$INSTALL_LINE" && -n "$TEST_LINE" && "$INSTALL_LINE" -lt "$TEST_LINE" ]]; then
    pass "tuist install runs before tuist test"
else
    fail "tuist install runs before tuist test ($(grep '^tuist' "$CALLS" | tr '\n' ';'))"
fi
if [[ "$TUIST_CALL" == *"--no-selective-testing"* ]]; then
    pass "a test asked for with --only always runs: selective testing is off"
else
    fail "a test asked for with --only always runs: selective testing is off (call: $TUIST_CALL)"
fi
: >"$CALLS"
if run_script WAYPOINT_TUIST_OFFLINE=1 >"$WORK/1b.log" 2>&1 &&
    grep "^tuist test" "$CALLS" | grep -q -- "--no-selective-testing --no-binary-cache --no-upload --inspect-mode off --skip-quarantine" &&
    grep "^tuist test" "$CALLS" | grep -q -- " WAYPOINT_TUIST_OFFLINE=1" &&
    grep -q "^TUIST_WAYPOINT_BINARY_CACHE seen by tuist test: 0$" "$CALLS"; then
    pass "WAYPOINT_TUIST_OFFLINE=1 turns Tuist's server features off"
else
    fail "WAYPOINT_TUIST_OFFLINE=1 turns Tuist's server features off"
fi

# 1c. Tuist's selective testing (planning #429) is on in quick and full runs whose changes Tuist's test
# hashes cover (the package's and the example app's sources), and off in a release run, after a
# change to a file the hashes don't cover, and when there are no changes to judge. `--plan` prints
# the decision without a run, in a copy of the working tree with its own one-commit history.
TREE="$WORK/tree"
mkdir -p "$TREE"
git ls-files -z | tar --null -T - -cf - | tar -xf - -C "$TREE"
# The compile fixtures need a real compiler, so the copy's fixture check is a stand-in.
printf '#!/usr/bin/env bash\n' >"$TREE/scripts/check-compile-failures.sh"
git -C "$TREE" init -q -b main
git -C "$TREE" add -A
git -C "$TREE" -c user.name=check -c user.email=check@example.invalid commit -q -m base
# GITHUB_HEAD_REF is unset: CI sets it, and it would win over the branch the script works out.
plan_of() {
    (cd "$TREE" && env -u GITHUB_HEAD_REF PATH="$STUBS:$PATH" TMPDIR="$WORK" WAYPOINT_BASE=HEAD \
        scripts/test-mac.sh "$@" --plan 2>/dev/null | grep '^plan:')
}
expect_plan() {
    local name="$1" want="$2" got
    shift 2
    got=$(plan_of "$@" || true)
    if [[ "$got" == *", selective testing $want,"* ]]; then
        pass "$name"
    else
        fail "$name (plan: ${got:-none})"
    fi
}
# Each probe file is made, judged and removed again, so the next case starts from no changes.
expect_plan_with() {
    local probe="$1"
    shift
    mkdir -p "$(dirname "$TREE/$probe")"
    if [[ -e "$TREE/$probe" ]]; then
        echo "// probe" >>"$TREE/$probe"
        expect_plan "$@"
        git -C "$TREE" checkout -q -- "$probe"
    else
        touch "$TREE/$probe"
        expect_plan "$@"
        rm "$TREE/$probe"
    fi
}
expect_plan "a full run with no changes to judge runs every test" off full
expect_plan "a quick run with no changes to judge runs every test" off quick
expect_plan_with Sources/WaypointCore/SelectiveProbe.swift \
    "a full run that changes the package may skip passed tests" on full
expect_plan_with Sources/WaypointCore/SelectiveProbe.swift \
    "a quick run that changes the package may skip passed tests" on quick
expect_plan_with Example/WaypointExample/SelectiveProbe.swift \
    "a quick run that changes only Example/ may skip passed tests" on quick
expect_plan_with Tests/WaypointCoreTests/SelectiveProbe.swift \
    "a full run that changes only the package's tests may skip passed tests" on full
expect_plan_with scripts/test-mac.sh \
    "a full run that changes a script runs every test" off full
expect_plan_with Example/Project.swift \
    "a full run that changes the example app's manifest runs every test" off full
expect_plan_with Example/Tuist/Package.swift \
    "a full run that changes the package integration runs every test" off full
expect_plan_with Package.swift \
    "a full run that changes Package.swift runs every test" off full
expect_plan_with Sources/WaypointCore/SelectiveProbe.swift \
    "a release run never skips a test" off release
# The release reports step runs right after its target passed in Debug, so it never skips.
touch "$TREE/Sources/WaypointCore/SelectiveProbe.swift"
got=$(plan_of full || true)
rm "$TREE/Sources/WaypointCore/SelectiveProbe.swift"
if [[ "$got" == *"selective testing on, release reports selective testing off"* ]]; then
    pass "a full run's release reports step never skips its tests"
else
    fail "a full run's release reports step never skips its tests (plan: ${got:-none})"
fi

# 1c2. Tuist's binary cache (planning #441): quick and full runs may use it; release, coverage,
# offline runs and runs for a pull request build from source; green full and coverage runs warm it; the release reports step
# never uses it.
expect_cache() {
    local name="$1" want="$2" got
    shift 2
    got=$(cd "$TREE" && env -u GITHUB_HEAD_REF PATH="$STUBS:$PATH" TMPDIR="$WORK" WAYPOINT_BASE=HEAD \
        "${@:2}" scripts/test-mac.sh "$1" --plan 2>/dev/null | grep '^plan:' || true)
    if [[ "$got" == *", $want, "* ]]; then
        pass "$name"
    else
        fail "$name (plan: ${got:-none})"
    fi
}
expect_cache "a quick run uses the binary cache and doesn't warm it" \
    "binary cache on, warm binary cache false" quick
expect_cache "a full run uses the binary cache and warms it" \
    "binary cache on, warm binary cache true" full
expect_cache "a release run builds from source and doesn't warm" \
    "binary cache off, warm binary cache false" release
expect_cache "a coverage run builds from source and warms" \
    "binary cache off, warm binary cache true" coverage
expect_cache "an offline full run builds from source and doesn't warm" \
    "binary cache off, warm binary cache false" full WAYPOINT_TUIST_OFFLINE=1
# A pull request's run report shows its coverage, which cached package modules would leave out.
expect_cache "a full run for a pull request builds from source and warms" \
    "binary cache off, warm binary cache true" full WAYPOINT_PULL_REQUEST=42 STUB_PR_BRANCH=main
# The package's own test steps send their result bundles to Tuist's Test Insights (planning #457),
# except offline, and a failed send never fails the step.
expect_package_insights() {
    local name="$1" want="$2" got
    shift 2
    got=$(cd "$TREE" && env -u GITHUB_HEAD_REF PATH="$STUBS:$PATH" TMPDIR="$WORK" WAYPOINT_BASE=HEAD \
        "${@:2}" scripts/test-mac.sh "$1" --plan 2>/dev/null | grep '^plan:' || true)
    if [[ "$got" == *", package test insights $want, "* ]]; then
        pass "$name"
    else
        fail "$name (plan: ${got:-none})"
    fi
}
expect_package_insights "a quick run sends the package's test results to Tuist" on quick
expect_package_insights "a release run sends the package's test results to Tuist" on release
expect_package_insights "an offline run sends the package's results nowhere" off full WAYPOINT_TUIST_OFFLINE=1
if grep -A16 "^package_tests_on()" scripts/test-mac.sh | grep -q 'send_package_test_results "$bundle" || true' &&
    grep -A8 "^send_package_test_results()" scripts/test-mac.sh |
    grep -q 'tuist_cmd inspect test --path Example "$1"; then'; then
    pass "each package test step sends its result bundle, and a failed send doesn't fail it"
else
    fail "each package test step sends its result bundle, and a failed send doesn't fail it"
fi
if grep -q "local BINARY_CACHE=off" scripts/test-mac.sh &&
    grep -A3 "^release_reports_on()" scripts/test-mac.sh | grep -q "local BINARY_CACHE=off"; then
    pass "the release reports step never uses the binary cache"
else
    fail "the release reports step never uses the binary cache"
fi

# 1d. Tuist is told the branch each run tests (planning #431), through GITHUB_HEAD_REF: the branch the clone
# is on; on a merge batch's detached commit, the batch's branches in merge order; on any other
# detached commit, nothing.
expect_branch() {
    local name="$1" want="$2" got
    shift 2
    got=$(plan_of "$@" || true)
    if [[ "$got" == *", tuist branch $want, "* ]]; then
        pass "$name"
    else
        fail "$name (plan: ${got:-none})"
    fi
}
expect_branch "a run on a branch tells Tuist that branch" main quick
batch_commit() {
    git -C "$TREE" -c user.name=check -c user.email=check@example.invalid "$@"
}
batch_commit checkout -q -b feature/first-part
echo "// first" >"$TREE/BranchProbeA.swift"
batch_commit add BranchProbeA.swift
batch_commit commit -q -m first
batch_commit checkout -q -b fix/second-part main
echo "// second" >"$TREE/BranchProbeB.swift"
batch_commit add BranchProbeB.swift
batch_commit commit -q -m second
batch_commit checkout -q --detach main
for branch in feature/first-part fix/second-part; do
    git -C "$TREE" -c user.name="Merge batch" -c user.email="merge-batch@localhost" \
        merge -q --no-ff --no-edit "$branch"
done
expect_branch "a merge batch tells Tuist its branches in merge order" \
    "feature/first-part+fix/second-part" full
# The preflight checks out `origin/<branch>` detached: the remote branch names it.
git -C "$TREE" update-ref refs/remotes/origin/feature/first-part feature/first-part
git -C "$TREE" update-ref refs/remotes/origin/main main
git -C "$TREE" symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/main
batch_commit checkout -q --detach origin/feature/first-part
expect_branch "a branch checked out detached from origin tells Tuist that branch" \
    feature/first-part full
batch_commit checkout -q --detach origin/main
expect_branch "main checked out detached from origin tells Tuist main" main full
batch_commit checkout -q --detach feature/first-part
batch_commit commit -q --allow-empty -m "no branch here"
expect_branch "a detached commit no branch points at tells Tuist no branch" none full
batch_commit checkout -q main
got=$(cd "$TREE" && env PATH="$STUBS:$PATH" TMPDIR="$WORK" WAYPOINT_BASE=HEAD \
    GITHUB_HEAD_REF=chosen/by-hand scripts/test-mac.sh quick --plan 2>/dev/null | grep '^plan:' || true)
if [[ "$got" == *", tuist branch chosen/by-hand, "* ]]; then
    pass "a GITHUB_HEAD_REF already set wins"
else
    fail "a GITHUB_HEAD_REF already set wins (plan: ${got:-none})"
fi

# 1j. A run for one pull request tells Tuist that pull request, through
# GITHUB_REF=refs/pull/<n>/head, so Tuist's GitHub app posts its run report there. A coverage run,
# an offline run and a merge batch of several branches name none, a GITHUB_REF left in the shell
# never reaches Tuist, and a value that isn't a number, or a pull request of another branch, stops
# the run; when gh can't name the pull request's branch, no report.
expect_pull_request() {
    local name="$1" want="$2" got
    shift 2
    got=$(cd "$TREE" && env -u GITHUB_HEAD_REF PATH="$STUBS:$PATH" TMPDIR="$WORK" WAYPOINT_BASE=HEAD \
        "${@:2}" scripts/test-mac.sh "$1" --plan 2>/dev/null | grep '^plan:' || true)
    if [[ "$got" == *", tuist pull request $want" ]]; then
        pass "$name"
    else
        fail "$name (plan: ${got:-none})"
    fi
}
batch_commit checkout -q feature/first-part
expect_pull_request "a run for a pull request tells Tuist that pull request" 42 \
    full WAYPOINT_PULL_REQUEST=42 STUB_PR_BRANCH=feature/first-part
expect_pull_request "a run whose pull request gh can't name tells Tuist none" none \
    full WAYPOINT_PULL_REQUEST=42
if (cd "$TREE" && env -u GITHUB_HEAD_REF PATH="$STUBS:$PATH" TMPDIR="$WORK" WAYPOINT_BASE=HEAD \
    WAYPOINT_PULL_REQUEST=42 STUB_PR_BRANCH=fix/second-part \
    scripts/test-mac.sh full --plan >/dev/null 2>&1); then
    fail "a pull request of another branch stops the run"
else
    pass "a pull request of another branch stops the run"
fi
expect_pull_request "a run without a pull request number tells Tuist none" none \
    full GITHUB_REF=refs/pull/7/head
expect_pull_request "an offline run tells Tuist no pull request" none \
    full WAYPOINT_PULL_REQUEST=42 STUB_PR_BRANCH=feature/first-part WAYPOINT_TUIST_OFFLINE=1
batch_commit checkout -q --detach main
for branch in feature/first-part fix/second-part; do
    git -C "$TREE" -c user.name="Merge batch" -c user.email="merge-batch@localhost" \
        merge -q --no-ff --no-edit "$branch"
done
expect_pull_request "a merge batch of several branches tells Tuist no pull request" none \
    full WAYPOINT_PULL_REQUEST=42
batch_commit checkout -q --detach main
expect_pull_request "a coverage run tells Tuist no pull request" none \
    coverage WAYPOINT_PULL_REQUEST=42
batch_commit checkout -q feature/first-part
if (cd "$TREE" && env -u GITHUB_HEAD_REF PATH="$STUBS:$PATH" TMPDIR="$WORK" WAYPOINT_BASE=HEAD \
    WAYPOINT_PULL_REQUEST=fix/second-part scripts/test-mac.sh full --plan >/dev/null 2>&1); then
    fail "a pull request that isn't a number stops the run"
else
    pass "a pull request that isn't a number stops the run"
fi
batch_commit checkout -q main
: >"$CALLS"
if run_script WAYPOINT_PULL_REQUEST=42 GITHUB_HEAD_REF=probe/branch STUB_PR_BRANCH=probe/branch \
    >"$WORK/1j.log" 2>&1 &&
    grep -qx "GITHUB_REF seen by tuist test: refs/pull/42/head" "$CALLS"; then
    pass "tuist test gets the pull request's ref"
else
    fail "tuist test gets the pull request's ref (calls: $(grep 'GITHUB_REF' "$CALLS" | tr '\n' ';'))"
fi
: >"$CALLS"
if grep -q "^tuist coverage complete" "$CALLS"; then
    fail "a run of one test leaves its commit's coverage in progress"
else
    pass "a run of one test leaves its commit's coverage in progress"
fi
# A run of every example test for a pull request completes its commit's coverage, after the tests.
pr_run() {
    (cd "$TREE" && env -u GITHUB_HEAD_REF PATH="$STUBS:$PATH" TMPDIR="$WORK" STUB_CALLS="$CALLS" \
        WAYPOINT_RUN_LOCK="$LOCK" WAYPOINT_SIMULATOR=waypoint-01 WAYPOINT_BASE=main \
        WAYPOINT_PULL_REQUEST=42 STUB_PR_BRANCH=feature/first-part "$@" scripts/test-mac.sh quick --ui)
}
batch_commit checkout -q feature/first-part
: >"$CALLS"
if pr_run >"$WORK/1j.log" 2>&1 &&
    [[ "$(grep -n "^tuist coverage complete --path Example" "$CALLS" | cut -d: -f1)" -gt \
        "$(grep -n "^tuist test" "$CALLS" | tail -1 | cut -d: -f1)" ]]; then
    pass "a pull request's run completes its commit's coverage after its tests"
else
    fail "a pull request's run completes its commit's coverage after its tests (calls: $(tr '\n' ';' <"$CALLS"))"
fi
# The package's xcodebuild steps fail on a warning in Waypoint's own code, and only there: a
# remote package such as Understudy is built with its warnings suppressed, which the compiler
# refuses alongside warnings as errors on the command line, so the script reads the build's output.
if pr_run STUB_XCODEBUILD_OUTPUT="$TREE/Sources/WaypointCore/Probe.swift:3:5: warning: probe" \
    >"$WORK/1w.log" 2>&1; then
    fail "a warning in Waypoint's own code fails the package's xcodebuild step"
elif grep -q "warnings in Waypoint's own code" "$WORK/1w.log"; then
    pass "a warning in Waypoint's own code fails the package's xcodebuild step"
else
    fail "a warning in Waypoint's own code fails the package's xcodebuild step (log: $(tail -3 "$WORK/1w.log"))"
fi
if pr_run STUB_XCODEBUILD_OUTPUT="$TREE/.build/checkouts/Understudy/Sources/Understudy/Spy.swift:3:5: warning: probe" \
    >"$WORK/1x.log" 2>&1; then
    pass "a warning in a dependency doesn't fail the package's xcodebuild step"
else
    fail "a warning in a dependency doesn't fail the package's xcodebuild step (log: $(tail -3 "$WORK/1x.log"))"
fi
if grep -v "^ *#" scripts/test-mac.sh | grep -q "SWIFT_TREAT_WARNINGS_AS_ERRORS"; then
    fail "no xcodebuild step passes warnings as errors to every target"
else
    pass "no xcodebuild step passes warnings as errors to every target"
fi
: >"$CALLS"
if pr_run STUB_STATUS=1 >"$WORK/1j.log" 2>&1; then
    fail "a pull request's run whose tests fail fails"
elif grep -q "^tuist coverage complete" "$CALLS"; then
    fail "a pull request's run whose tests fail never completes the commit"
else
    pass "a pull request's run whose tests fail never completes the commit"
fi
: >"$CALLS"
if pr_run WAYPOINT_PULL_REQUEST= >"$WORK/1j.log" 2>&1 && ! grep -q "^tuist coverage complete" "$CALLS"; then
    pass "a run for no pull request leaves its commit's coverage in progress"
else
    fail "a run for no pull request leaves its commit's coverage in progress (calls: $(tr '\n' ';' <"$CALLS"))"
fi
batch_commit checkout -q main
: >"$CALLS"
if run_script GITHUB_REF=refs/pull/7/head >"$WORK/1j.log" 2>&1 &&
    grep -qx "GITHUB_REF seen by tuist test: " "$CALLS"; then
    pass "a GITHUB_REF left in the shell never reaches tuist test"
else
    fail "a GITHUB_REF left in the shell never reaches tuist test (calls: $(grep 'GITHUB_REF' "$CALLS" | tr '\n' ';'))"
fi
: >"$CALLS"

# 1e. A coverage run (planning #431) runs on `main`'s own unchanged commit only, runs every example test,
# and marks the commit complete only after they pass.
expect_plan "a coverage run on main runs every example test" off coverage
batch_commit checkout -q feature/first-part
if plan_of coverage >/dev/null; then
    fail "a coverage run refuses a branch other than main"
else
    pass "a coverage run refuses a branch other than main"
fi
batch_commit checkout -q --detach main
expect_branch "a coverage run on main's commit, detached as the preflight leaves it, tells Tuist main" \
    main coverage
got=$(cd "$TREE" && env PATH="$STUBS:$PATH" TMPDIR="$WORK" WAYPOINT_BASE=HEAD \
    GITHUB_HEAD_REF=chosen/by-hand scripts/test-mac.sh coverage --plan 2>/dev/null | grep '^plan:' || true)
if [[ "$got" == *", tuist branch main, "* ]]; then
    pass "a coverage run always tells Tuist main, whatever GITHUB_HEAD_REF says"
else
    fail "a coverage run always tells Tuist main, whatever GITHUB_HEAD_REF says (plan: ${got:-none})"
fi
batch_commit checkout -q --detach feature/first-part
if (cd "$TREE" && env -u GITHUB_HEAD_REF PATH="$STUBS:$PATH" TMPDIR="$WORK" WAYPOINT_BASE=main \
    scripts/test-mac.sh coverage --plan >/dev/null 2>&1); then
    fail "a coverage run refuses a detached commit that isn't main's"
else
    pass "a coverage run refuses a detached commit that isn't main's"
fi
batch_commit checkout -q main
touch "$TREE/Sources/WaypointCore/CoverageProbe.swift"
if plan_of coverage >/dev/null; then
    fail "a coverage run refuses a clone with changes"
else
    pass "a coverage run refuses a clone with changes"
fi
rm "$TREE/Sources/WaypointCore/CoverageProbe.swift"
if (cd "$TREE" && env -u GITHUB_HEAD_REF PATH="$STUBS:$PATH" TMPDIR="$WORK" WAYPOINT_BASE=HEAD~1 \
    scripts/test-mac.sh coverage --plan >/dev/null 2>&1); then
    fail "a coverage run refuses a main that isn't the base's"
else
    pass "a coverage run refuses a main that isn't the base's"
fi
coverage_run() {
    (cd "$TREE" && env -u GITHUB_HEAD_REF PATH="$STUBS:$PATH" TMPDIR="$WORK" STUB_CALLS="$CALLS" \
        WAYPOINT_RUN_LOCK="$LOCK" WAYPOINT_SIMULATOR=waypoint-01 WAYPOINT_BASE=HEAD "$@" \
        scripts/test-mac.sh coverage)
}
: >"$CALLS"
if coverage_run >"$WORK/1e.log" 2>&1 &&
    grep "^tuist test" "$CALLS" | grep -q -- "--no-selective-testing" &&
    grep -q "^tuist coverage complete --path Example" "$CALLS" &&
    ! grep -q "^xcodebuild" "$CALLS"; then
    pass "a coverage run tests every example test, skips the package steps and completes the commit"
else
    fail "a coverage run tests every example test, skips the package steps and completes the commit (log: $(tail -3 "$WORK/1e.log"); calls: $(tr '\n' ';' <"$CALLS"))"
fi
: >"$CALLS"
if coverage_run STUB_STATUS=1 >"$WORK/1f.log" 2>&1; then
    fail "a coverage run whose tests fail fails"
elif grep -q "^tuist coverage complete" "$CALLS"; then
    fail "a coverage run whose tests fail never completes the commit"
else
    pass "a coverage run whose tests fail never completes the commit"
fi
: >"$CALLS"

# 1i. The Tuist version check (planning #434) compares the pin with Tuist's latest stable release, ignores
# canaries and release candidates, tells a new major version apart, and never fails. The daily
# coverage run prints it.
TAGS="$WORK/tuist-tags"
PINNED=$(sed -n 's/^tuist *= *"\([^"]*\)".*/\1/p' .mise.toml | head -1)
IFS=. read -r PIN_MAJOR PIN_MINOR PIN_PATCH <<<"$PINNED"
tuist_check() {
    printf '%s\n' "$@" >"$TAGS"
    WAYPOINT_TUIST_TAGS_FILE="$TAGS" scripts/check-tuist-version.sh 2>&1
}
expect_tuist_check() {
    local name="$1" want="$2" got status=0
    shift 2
    got=$(tuist_check "$@") || status=$?
    if [[ $status -eq 0 && "$got" == *"$want"* ]]; then
        pass "$name"
    else
        fail "$name (exit $status: ${got:-nothing})"
    fi
}
expect_tuist_check "the Tuist check says when the pin is the latest stable Tuist" \
    "pinned $PINNED is the latest stable Tuist" \
    "$PINNED" "$PIN_MAJOR.$PIN_MINOR.$((PIN_PATCH + 1))-rc.1" \
    "$PIN_MAJOR.$((PIN_MINOR + 1)).0-canary.3" "$PIN_MAJOR.$PIN_MINOR.0"
expect_tuist_check "the Tuist check asks for a bump when a newer patch version is out" \
    "Tuist $PIN_MAJOR.$PIN_MINOR.$((PIN_PATCH + 2)) is out: open a pull request" \
    "$PINNED" "$PIN_MAJOR.$PIN_MINOR.$((PIN_PATCH + 2))" "$PIN_MAJOR.$PIN_MINOR.$((PIN_PATCH + 1))"
expect_tuist_check "the Tuist check reads tags with a leading v and minor versions" \
    "Tuist $PIN_MAJOR.$((PIN_MINOR + 1)).0 is out: open a pull request" \
    "$PINNED" "v$PIN_MAJOR.$((PIN_MINOR + 1)).0"
expect_tuist_check "the Tuist check sends a new major version to Yousef" \
    "Tuist $((PIN_MAJOR + 1)).0.0 is out, a new major version: ask Yousef" \
    "$PINNED" "$((PIN_MAJOR + 1)).0.0"
expect_tuist_check "the Tuist check never fails when it can't read Tuist's releases" \
    "couldn't read Tuist's releases"
: >"$CALLS"
if coverage_run WAYPOINT_TUIST_TAGS_FILE="$TAGS" >"$WORK/1i.log" 2>&1 &&
    grep -q "^Tuist version check: pinned $PINNED" "$WORK/1i.log"; then
    pass "a coverage run prints the Tuist version check"
else
    fail "a coverage run prints the Tuist version check (log: $(tail -3 "$WORK/1i.log"))"
fi
: >"$CALLS"

# 1g. The release reports step collects no coverage (planning #431): the Debug step measured its tests.
if sed -n '/^release_reports_on() {/,/^}/p' scripts/test-mac.sh |
    grep -q 'TUIST_COVERAGE_ENABLED=0 TUIST_COVERAGE_UPLOAD=0 example_tests_on'; then
    pass "the release reports step runs with coverage off"
else
    fail "the release reports step runs with coverage off"
fi

# 1h. The release reports step builds into its own derived data (planning #431): Tuist reads coverage from
# one products folder and took the Release one when both sat in the example app's derived data.
# An example run removes Release products an older run left there.
if sed -n '/^release_reports_on() {/,/^}/p' scripts/test-mac.sh |
    grep -q 'local EXAMPLE_DERIVED_DATA="$RELEASE_REPORTS_DERIVED_DATA"' &&
    grep -q '^RELEASE_REPORTS_DERIVED_DATA="$PWD/.build/release-reports-derived-data"$' scripts/test-mac.sh; then
    pass "the release reports step builds into its own derived data"
else
    fail "the release reports step builds into its own derived data"
fi
STALE_RELEASE="$TREE/.build/example-derived-data/Build/Products/Release-iphonesimulator"
mkdir -p "$STALE_RELEASE"
: >"$CALLS"
(cd "$TREE" && run_script) >"$WORK/1h.log" 2>&1 || true
if [[ ! -e "$STALE_RELEASE" ]] && grep -q "^tuist test" "$CALLS"; then
    pass "an example run removes Release products left in its derived data"
else
    fail "an example run removes Release products left in its derived data (log: $(tail -3 "$WORK/1h.log"))"
fi
: >"$CALLS"

# 1f. The Build and Test Insights post-actions run the Tuist that mise pins (planning #431), not one on
# the PATH, and the test one skips runs `tuist test` already reports (planning #456).
if grep -q '"$MISE" exec -C "$SRCROOT" -- tuist inspect \\(command)' Example/Project.swift &&
    ! grep -q 'activate -C "$SRCROOT"' Example/Project.swift &&
    grep -q 'insightsScript("build", skippedBy: \["WAYPOINT_TUIST_OFFLINE"\])' Example/Project.swift &&
    grep -q 'skippedBy: \["WAYPOINT_TUIST_OFFLINE", "WAYPOINT_TUIST_TEST_RUN"\]' Example/Project.swift &&
    grep -q 'testAction: .targets(schemeTestTargets, postActions: \[testInsights\], options: testOptions)' Example/Project.swift; then
    pass "the Build and Test Insights post-actions run Tuist through mise exec"
else
    fail "the Build and Test Insights post-actions run Tuist through mise exec"
fi
# A failed UI test keeps screenshots, not a screen recording, so a failing run's result bundle stays
# small enough to upload (planning #489).
if grep -q '^let testOptions = TestActionOptions.options(preferredScreenCaptureFormat: .screenshots)$' Example/Project.swift; then
    pass "a failed UI test keeps screenshots, not a screen recording"
else
    fail "a failed UI test keeps screenshots, not a screen recording"
fi

# 2. A second run stops at once and runs nothing while the first holds the lock.
: >"$CALLS"
run_script STUB_SECONDS=4 >"$WORK/2a.log" 2>&1 &
first=$!
for _ in $(seq 1 40); do
    [[ -L "$LOCK" ]] && break
    sleep 0.1
done
holder=$(readlink "$LOCK" || true)
if run_script >"$WORK/2b.log" 2>&1; then
    fail "a second run stops while the first holds the lock"
elif ! grep -q "another Mac test run holds the run lock (pid $holder," "$WORK/2b.log"; then
    fail "the second run names the holder (log: $(tail -3 "$WORK/2b.log"))"
else
    pass "a second run stops and names the run that holds the lock"
fi
wait "$first" || fail "the first run passes while a second one is turned away"
if [[ "$(grep -c '^tuist test' "$CALLS")" == 1 ]] && lock_gone; then
    pass "the second run ran nothing, and the first released the lock"
else
    fail "the second run ran nothing, and the first released the lock ($(grep -c '^tuist test' "$CALLS") tuist test calls)"
fi

# 2b. A run turned away at the run lock leaves Tuist's package project where the run holding the
# lock put it, since that run may be in a package step (planning #429); the holder puts it back when it
# ends. Both runs go in the copy of the working tree, so the clone's own folders are never touched.
ASIDE="$TREE/.build/tuist-package-project"
(cd "$TREE" && run_script STUB_SECONDS=4) >"$WORK/2c.log" 2>&1 &
first=$!
for _ in $(seq 1 40); do
    [[ -L "$LOCK" ]] && break
    sleep 0.1
done
mkdir -p "$ASIDE/Derived"
(cd "$TREE" && run_script) >"$WORK/2d.log" 2>&1 || true
if [[ -d "$ASIDE/Derived" && ! -e "$TREE/Derived" ]]; then
    pass "a run turned away at the run lock leaves Tuist's package project aside"
else
    fail "a run turned away at the run lock leaves Tuist's package project aside"
fi
wait "$first" || fail "the first run passes while a second one is turned away (log: $(tail -3 "$WORK/2c.log"))"
if [[ -d "$TREE/Derived" && ! -e "$ASIDE/Derived" ]]; then
    pass "the run holding the lock puts Tuist's package project back when it ends"
else
    fail "the run holding the lock puts Tuist's package project back when it ends"
fi
rm -rf "$TREE/Derived"

# 3. A lock left by a run that has ended is cleared.
sleep 0 &
dead=$!
wait "$dead"
ln -s "$dead" "$LOCK"
echo "0" >"$LOCK.info"
if run_script >"$WORK/3.log" 2>&1 && grep -q "cleared a run lock" "$WORK/3.log" && lock_gone; then
    pass "a lock left by an ended run is cleared"
else
    fail "a lock left by an ended run is cleared (log: $(tail -3 "$WORK/3.log"))"
fi

# 4. A lock whose pid now belongs to another process is cleared too.
sleep 30 &
other=$!
ln -s "$other" "$LOCK"
if run_script >"$WORK/4.log" 2>&1 && grep -q "cleared a run lock" "$WORK/4.log" && lock_gone; then
    pass "a lock pointing at a process that isn't a test run is cleared"
else
    fail "a lock pointing at a process that isn't a test run is cleared (log: $(tail -3 "$WORK/4.log"))"
fi
kill "$other" 2>/dev/null || true
wait "$other" 2>/dev/null || true

# 5. A failing run leaves no lock.
if run_script STUB_STATUS=1 >"$WORK/5.log" 2>&1; then
    fail "a failing test fails the run"
elif lock_gone; then
    pass "a failing run releases the lock"
else
    fail "a failing run releases the lock"
fi

# 6. A run stopped with TERM, the way TESTING.md stops a hung run, leaves no lock.
for how in step script; do
    run_script STUB_SECONDS=20 >"$WORK/6-$how.log" 2>&1 &
    run=$!
    for _ in $(seq 1 50); do
        grep -q '^tuist test' "$CALLS" 2>/dev/null && [[ -L "$LOCK" ]] && break
        sleep 0.1
    done
    sleep 0.5
    script_pid=$(readlink "$LOCK" || true)
    if [[ "$how" == step ]]; then
        pkill -TERM -P "$script_pid" || true
    else
        kill -TERM "$script_pid" || true
    fi
    wait "$run" 2>/dev/null || true
    if pgrep -f "$STUBS/tuist|$STUBS/stub-grandchild" >/dev/null; then
        fail "a run stopped with TERM ($how) stops its step's tools, grandchildren included"
        pkill -f "$STUBS/tuist|$STUBS/stub-grandchild" || true
    fi
    if grep -q "All Mac tests passed" "$WORK/6-$how.log"; then
        fail "a run stopped with TERM ($how) never says it passed"
    else
        pass "a run stopped with TERM ($how) never says it passed"
    fi
    if [[ "$how" == script ]] && ! grep -q "Mac tests stopped by TERM" "$WORK/6-$how.log"; then
        fail "a run stopped with TERM (script) says it stopped (log: $(tail -3 "$WORK/6-$how.log"))"
    fi
    if lock_gone; then
        pass "a run stopped with TERM ($how) releases the lock"
    else
        fail "a run stopped with TERM ($how) releases the lock"
        rm -f "$LOCK" "$LOCK.info"
    fi
    : >"$CALLS"
done

# 7. A run that finds a stale lock and stalls before clearing it, while another run clears it
# and takes the lock: the stalled run stops and the other run's lock stays.
sleep 0 &
dead=$!
wait "$dead"
ln -s "$dead" "$LOCK"
run_script WAYPOINT_RUN_LOCK_TEST_PAUSE=2 >"$WORK/7b.log" 2>&1 &
stalled=$!
sleep 0.5
run_script STUB_SECONDS=4 >"$WORK/7a.log" 2>&1 &
first=$!
stalled_status=0
wait "$stalled" || stalled_status=$?
holder=$(readlink "$LOCK" 2>/dev/null || true)
first_status=0
wait "$first" || first_status=$?
if [[ $stalled_status -ne 0 && $first_status -eq 0 && -n "$holder" ]] &&
    grep -q "another Mac test run" "$WORK/7b.log" && lock_gone; then
    pass "a run that stalls on a stale lock stops, and leaves the live run's lock alone"
else
    fail "a run that stalls on a stale lock stops ($stalled_status, $first_status, holder ${holder:-none})"
fi

# 8. The report prints the phase timeline, each step with the clock time it started, and the
# memory at the start and the end (planning #489).
: >"$CALLS"
run_script >"$WORK/8.log" 2>&1 || true
if grep -Eq '^==> [0-9]{2}:[0-9]{2}:[0-9]{2} ' "$WORK/8.log" &&
    grep -Eq '^  [0-9]{2}:[0-9]{2}:[0-9]{2} +[0-9]+s  tuist test' "$WORK/8.log" &&
    grep -Eq '^  [0-9]{2}:[0-9]{2}:[0-9]{2} +[0-9]+s  total$' "$WORK/8.log"; then
    pass "the report prints when each step started"
else
    fail "the report prints when each step started (log: $(grep -A4 '^Step times' "$WORK/8.log"))"
fi
if grep -q '^Memory at the start: ' "$WORK/8.log" && grep -q '^Memory at the end: ' "$WORK/8.log"; then
    pass "the report prints the memory at the start and the end"
else
    fail "the report prints the memory at the start and the end"
fi

# 8b. The release reports step runs its two classes on the project simulator, with no copies.
if sed -n '/^release_reports_on() {/,/^}/p' scripts/test-mac.sh |
    grep -q 'local EXAMPLE_PARALLEL_FLAGS=(-parallel-testing-enabled NO)'; then
    pass "the release reports step runs without parallel workers"
else
    fail "the release reports step runs without parallel workers"
fi

# 8c. A run removes, by UDID, only the shut-down copies it made: a copy there before the run stays,
# booted or not, a copy still booted at the end (someone else's test run) stays, and the pool
# simulators are never touched.
DEVICES="$WORK/XCTestDevices"
mkdir -p "$DEVICES"
clone() {
    echo "{\"name\":\"Clone $1 of waypoint-01\",\"udid\":\"CLONE-$1\",\"state\":\"$2\"}"
}
pool='{"name":"waypoint-01","udid":"POOL-UDID","state":"Booted"}'
echo "{\"devices\":{\"iOS-27-2\":[$(clone 1 Booted),$(clone 2 Shutdown),$pool]}}" >"$WORK/clones"
echo "{\"devices\":{\"iOS-27-2\":[$(clone 1 Booted),$(clone 2 Shutdown),$(clone 3 Booted),$(clone 4 Shutdown),$(clone 5 Shutdown),$pool]}}" >"$WORK/clones-during"
: >"$CALLS"
if run_script WAYPOINT_TEST_DEVICES="$DEVICES" STUB_CLONES="$WORK/clones" \
    STUB_CLONES_DURING="$WORK/clones-during" >"$WORK/8c.log" 2>&1; then
    touched=$(grep "^xcrun simctl --set $DEVICES \(shutdown\|delete\|erase\)" "$CALLS" | sort || true)
    expected=$(printf '%s\n' "delete CLONE-4" "delete CLONE-5" |
        sed "s|^|xcrun simctl --set $DEVICES |")
    if [[ "$touched" == "$expected" ]]; then
        pass "a run removes only the copies it made, by UDID"
    else
        fail "a run removes only the copies it made (calls: ${touched:-none})"
    fi
    if ! grep -Eq "simctl (shutdown|delete|erase) .*(POOL-UDID|waypoint-0)|shutdown all|delete (all|unavailable)" "$CALLS"; then
        pass "a run never removes a pool simulator or everything at once"
    else
        fail "a run never removes a pool simulator or everything at once"
    fi
else
    fail "a run with simulator copies passes (log: $(tail -3 "$WORK/8c.log"))"
fi

# 8d. When the copies can't be listed at the start, the run removes none of them.
cp "$WORK/clones" "$WORK/clones-8d"
: >"$CALLS"
if run_script WAYPOINT_TEST_DEVICES="$DEVICES" STUB_CLONES="$WORK/clones-8d" \
    STUB_CLONES_DURING="$WORK/clones-during" STUB_CLONES_FAIL="$WORK/listing-failed" >"$WORK/8d.log" 2>&1 &&
    ! grep -q "^xcrun simctl --set $DEVICES \(shutdown\|delete\)" "$CALLS" &&
    grep -q "this run removes none" "$WORK/8d.log"; then
    pass "a run that can't list the copies at the start removes none"
else
    fail "a run that can't list the copies at the start removes none (calls: $(grep -- '--set' "$CALLS" | tail -3))"
fi

if [[ $FAILURES -gt 0 ]]; then
    echo "$FAILURES run lock check(s) failed" >&2
    exit 1
fi
echo "All run lock checks passed."
