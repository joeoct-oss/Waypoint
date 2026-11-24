#!/usr/bin/env bash
#
#  check-test-mac-lock.sh
#  Waypoint
#
#  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
#  Copyright © 2026 Yousef Mohamed. MIT License.
#
# Checks the run lock of scripts/test-mac.sh (#294) with stand-in tools, so it runs on Linux and
# on the Mac without Xcode or a simulator:
#
# - a second run while one holds the lock stops at once and runs nothing;
# - a lock left by a run that has ended, or pointing at a process that isn't a test run, is
#   cleared and the run goes on;
# - the lock is gone after a pass, a failure, and a stop with TERM.
#
# It also checks what the script hands Tuist: selective testing per tier (#324), the derived data
# folder after `--` (#326), the branch through GITHUB_HEAD_REF and the `coverage` tier on `main`
# (#327), and that the Build Insights post-action runs the Tuist mise pins (#327).
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
cat >"$STUBS/sysctl" <<'EOF'
#!/usr/bin/env bash
echo 4
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
# The example app's tests run through `tuist test` (#312): on the project simulator, into a
# result bundle, with two parallel workers.
TUIST_CALL=$(grep "^tuist test WaypointExample" "$CALLS" | head -1)
for part in "--path Example" "--device waypoint-01" \
    "--os 27.2" "--no-binary-cache" "--skip-quarantine" \
    "-T .build/results/example-only.xcresult" \
    "--test-targets WaypointExampleUITests/StackTests/testPushAndBack" \
    "-parallel-testing-enabled YES" "-parallel-testing-worker-count 2"; do
    if [[ "$TUIST_CALL" == *" $part"* ]]; then
        pass "tuist test gets $part"
    else
        fail "tuist test gets $part (call: $TUIST_CALL)"
    fi
done
# The derived data folder goes to xcodebuild after `--`, the way Tuist asks (#326).
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
# (#324).
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
    grep "^tuist test" "$CALLS" | grep -q -- " WAYPOINT_TUIST_OFFLINE=1"; then
    pass "WAYPOINT_TUIST_OFFLINE=1 turns Tuist's server features off"
else
    fail "WAYPOINT_TUIST_OFFLINE=1 turns Tuist's server features off"
fi

# 1c. Tuist's selective testing (#324) is on in quick and full runs whose changes Tuist's test
# hashes cover (the package's and the example app's sources), and off in a release run, after a
# change to a file the hashes don't cover, and when there are no changes to judge. `--plan` prints
# the decision without a run, in a copy of the working tree with its own one-commit history.
TREE="$WORK/tree"
mkdir -p "$TREE"
git ls-files -z | tar --null -T - -cf - | tar -xf - -C "$TREE"
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

# 1d. Tuist is told the branch each run tests (#327), through GITHUB_HEAD_REF: the branch the clone
# is on; on a merge batch's detached commit, the batch's branches in merge order; on any other
# detached commit, nothing. GITHUB_REF and GITHUB_SHA are never set, so no pull request comment.
expect_branch() {
    local name="$1" want="$2" got
    shift 2
    got=$(plan_of "$@" || true)
    if [[ "$got" == *", tuist branch $want" ]]; then
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
batch_commit checkout -q --detach feature/first-part
expect_branch "another detached commit tells Tuist no branch" none full
batch_commit checkout -q main
got=$(cd "$TREE" && env PATH="$STUBS:$PATH" TMPDIR="$WORK" WAYPOINT_BASE=HEAD \
    GITHUB_HEAD_REF=chosen/by-hand scripts/test-mac.sh quick --plan 2>/dev/null | grep '^plan:' || true)
if [[ "$got" == *", tuist branch chosen/by-hand" ]]; then
    pass "a GITHUB_HEAD_REF already set wins"
else
    fail "a GITHUB_HEAD_REF already set wins (plan: ${got:-none})"
fi
if grep -Eq '(export|^[[:space:]]*)GITHUB_(REF|SHA)=' scripts/test-mac.sh; then
    fail "the script never sets GITHUB_REF or GITHUB_SHA"
else
    pass "the script never sets GITHUB_REF or GITHUB_SHA"
fi

# 1e. A coverage run (#327) runs on `main`'s own unchanged commit only, runs every example test,
# and marks the commit complete only after they pass.
expect_plan "a coverage run on main runs every example test" off coverage
batch_commit checkout -q feature/first-part
if plan_of coverage >/dev/null; then
    fail "a coverage run refuses a branch other than main"
else
    pass "a coverage run refuses a branch other than main"
fi
batch_commit checkout -q --detach main
if plan_of coverage >/dev/null; then
    fail "a coverage run refuses a detached commit"
else
    pass "a coverage run refuses a detached commit"
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

# 1f. The Build Insights post-action runs the Tuist that mise pins (#327), not one on the PATH.
if grep -q '"$MISE" exec -C "$SRCROOT" -- tuist inspect build' Example/Project.swift &&
    ! grep -q 'activate -C "$SRCROOT"' Example/Project.swift; then
    pass "the Build Insights post-action runs Tuist through mise exec"
else
    fail "the Build Insights post-action runs Tuist through mise exec"
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
# lock put it, since that run may be in a package step (#324); the holder puts it back when it
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

if [[ $FAILURES -gt 0 ]]; then
    echo "$FAILURES run lock check(s) failed" >&2
    exit 1
fi
echo "All run lock checks passed."
