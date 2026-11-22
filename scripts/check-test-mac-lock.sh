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
# Each case runs `test-mac.sh quick --only` with its own lock path and temporary folder, so a
# real run on the Mac is never touched.
#
# Usage: scripts/check-test-mac-lock.sh

set -euo pipefail

cd "$(dirname "$0")/.."

WORK=$(mktemp -d)
cleanup() {
    rm -rf "$WORK"
}
trap cleanup EXIT

STUBS="$WORK/bin"
mkdir -p "$STUBS"
CALLS="$WORK/calls"
: >"$CALLS"

# Stand-ins for the tools the script calls. xcodebuild sleeps STUB_SECONDS and exits STUB_STATUS.
cat >"$STUBS/xcrun" <<'EOF'
#!/usr/bin/env bash
echo "xcrun $*" >>"$STUB_CALLS"
if [[ "$*" == *"list devices"* ]]; then
    echo '{"devices":{"ios":[{"name":"waypoint-01","udid":"STUB-UDID","state":"Shutdown"}]}}'
fi
EOF
cat >"$STUBS/xcodebuild" <<'EOF'
#!/usr/bin/env bash
echo "xcodebuild $*" >>"$STUB_CALLS"
sleep "${STUB_SECONDS:-0}"
exit "${STUB_STATUS:-0}"
EOF
cat >"$STUBS/tuist" <<'EOF'
#!/usr/bin/env bash
echo "tuist $*" >>"$STUB_CALLS"
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

# 1. A pass leaves no lock.
if run_script >"$WORK/1.log" 2>&1 && lock_gone; then
    pass "a passing run releases the lock"
else
    fail "a passing run releases the lock (log: $(tail -3 "$WORK/1.log"))"
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
if [[ "$(grep -c '^xcodebuild' "$CALLS")" == 1 ]] && lock_gone; then
    pass "the second run ran nothing, and the first released the lock"
else
    fail "the second run ran nothing, and the first released the lock ($(grep -c '^xcodebuild' "$CALLS") xcodebuild calls)"
fi

# 3. A lock left by a run that has ended is cleared.
sleep 0 &
dead=$!
wait "$dead"
ln -s "$dead" "$LOCK"
echo "0" >"$LOCK.info"
if run_script >"$WORK/3.log" 2>&1 && grep -q "clearing a run lock" "$WORK/3.log" && lock_gone; then
    pass "a lock left by an ended run is cleared"
else
    fail "a lock left by an ended run is cleared (log: $(tail -3 "$WORK/3.log"))"
fi

# 4. A lock whose pid now belongs to another process is cleared too.
sleep 30 &
other=$!
ln -s "$other" "$LOCK"
if run_script >"$WORK/4.log" 2>&1 && grep -q "clearing a run lock" "$WORK/4.log" && lock_gone; then
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
        grep -q '^xcodebuild' "$CALLS" 2>/dev/null && [[ -L "$LOCK" ]] && break
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
    if lock_gone; then
        pass "a run stopped with TERM ($how) releases the lock"
    else
        fail "a run stopped with TERM ($how) releases the lock"
        rm -f "$LOCK" "$LOCK.info"
    fi
    : >"$CALLS"
done

if [[ $FAILURES -gt 0 ]]; then
    echo "$FAILURES run lock check(s) failed" >&2
    exit 1
fi
echo "All run lock checks passed."
