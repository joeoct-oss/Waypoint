#!/usr/bin/env bash
#
#  check-flaky-tests.sh
#  Waypoint
#
#  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
#  Copyright © 2026 Yousef Mohamed. MIT License.
#
# Checks what scripts/flaky-tests.py decides for an example app test step, from result bundle JSON
# shaped like `xcrun xcresulttool get test-results tests` writes, so it runs on Linux:
#
# - a UI test that passes on its retry doesn't block, and is listed as flaky;
# - a UI test that fails both tries blocks, unless it is quarantined and its entry hasn't expired;
# - a unit test that needed a retry blocks;
# - a step that failed with no failed test, or with a failure outside its tests, blocks;
# - a quarantine file with too many tests, a test without an issue, a bad or future date, or a
#   test listed twice is refused.
#
# It ends by checking the repo's own Example/quarantine.json.
#
# Usage: scripts/check-flaky-tests.sh

set -euo pipefail

cd "$(dirname "$0")/.."

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

FAILURES=0
fail() {
    echo "FAIL: $1" >&2
    FAILURES=$((FAILURES + 1))
}
pass() {
    echo "ok: $1"
}

TODAY=2026-11-26

# A result bundle with one UI test case and one unit test case, each with the given tries.
# Arguments: the UI test's tries and the unit test's tries, as comma-separated results.
bundle() {
    /usr/bin/env python3 - "$1" "$2" <<'EOF'
import json, sys

def case(name, tries):
    results = [result for result in tries.split(",") if result]
    reps = [{"nodeType": "Repetition", "name": f"Repetition {i}", "result": result,
             "children": ([{"nodeType": "Failure Message",
                            "name": "SheetTests.swift:42: the sheet never showed"}]
                          if result == "Failed" else [])}
            for i, result in enumerate(results, start=1)]
    final = results[-1] if results else "Passed"
    node = {"nodeType": "Test Case", "name": f"{name}()", "result": final}
    if len(results) > 1:
        node["children"] = reps
    elif reps:
        node["children"] = reps[0]["children"]
    return node

print(json.dumps({"testNodes": [{"nodeType": "Test Plan", "name": "WaypointExample", "children": [
    {"nodeType": "UI test bundle", "name": "WaypointExampleUITests", "children": [
        {"nodeType": "Test Suite", "name": "SheetTests",
         "children": [case("testFiltersSheet", sys.argv[1])]}]},
    {"nodeType": "Unit test bundle", "name": "WaypointExampleTests", "children": [
        {"nodeType": "Test Suite", "name": "CartTests",
         "children": [case("testTotal", sys.argv[2])]}]}]}]}))
EOF
}

quarantine() {
    cat >"$WORK/quarantine.json"
}
quarantine <<'EOF'
{ "tests": [] }
EOF

# Runs the verdict; prints its output and leaves its status in VERDICT.
judge() {
    local tries_ui="$1" tries_unit="$2" step_status="$3"
    VERDICT=0
    bundle "$tries_ui" "$tries_unit" |
        scripts/flaky-tests.py --step-status "$step_status" --quarantine "$WORK/quarantine.json" \
            --today "$TODAY" --out "$WORK/out.json" >"$WORK/verdict.log" 2>&1 || VERDICT=$?
}

UI=WaypointExampleUITests/SheetTests/testFiltersSheet

judge Passed Passed 0
if [[ $VERDICT -eq 0 ]] && ! grep -q "^Flaky:" "$WORK/verdict.log"; then
    pass "a step where every test passed passes, with no flaky test"
else
    fail "a step where every test passed passes ($(cat "$WORK/verdict.log"))"
fi

judge Failed,Passed Passed 0
if [[ $VERDICT -eq 0 ]] &&
    grep -q "^Flaky: $UI failed 1 of 2 tries, then passed (SheetTests.swift:42" "$WORK/verdict.log" &&
    grep -q "\"kind\": \"flaky\"" "$WORK/out.json"; then
    pass "a UI test that passes on its retry doesn't block, and is listed as flaky"
else
    fail "a UI test that passes on its retry doesn't block ($(cat "$WORK/verdict.log"))"
fi

# xcodebuild's own status after a retry that passed isn't documented, so the verdict decides.
judge Failed,Passed Passed 65
if [[ $VERDICT -eq 0 ]]; then
    pass "a flaky UI test doesn't block even when xcodebuild failed the step"
else
    fail "a flaky UI test doesn't block even when xcodebuild failed the step ($(cat "$WORK/verdict.log"))"
fi

judge Failed,Failed Passed 65
if [[ $VERDICT -eq 1 ]] && grep -q "error: $UI failed every try (2)" "$WORK/verdict.log"; then
    pass "a UI test that fails both tries blocks"
else
    fail "a UI test that fails both tries blocks ($(cat "$WORK/verdict.log"))"
fi

judge Failed,Failed Passed 0
if [[ $VERDICT -eq 1 ]]; then
    pass "a UI test that fails both tries blocks even when xcodebuild passed the step"
else
    fail "a UI test that fails both tries blocks even when xcodebuild passed the step"
fi

judge Passed Failed,Passed 0
if [[ $VERDICT -eq 1 ]] &&
    grep -q "WaypointExampleTests/CartTests/testTotal passed only on a retry" "$WORK/verdict.log"; then
    pass "a unit test that needed a retry blocks"
else
    fail "a unit test that needed a retry blocks ($(cat "$WORK/verdict.log"))"
fi

judge Passed Failed 65
if [[ $VERDICT -eq 1 ]]; then
    pass "a unit test that failed blocks"
else
    fail "a unit test that failed blocks"
fi

# A Swift Testing test with a display name is still named by its identifier.
VERDICT=0
bundle Passed Failed | python3 -c '
import json, sys
data = json.load(sys.stdin)
case = data["testNodes"][0]["children"][1]["children"][0]["children"][0]
case["name"] = "The total adds every line"
case["nodeIdentifier"] = "CartTests/testTotal()"
print(json.dumps(data))' |
    scripts/flaky-tests.py --step-status 65 --today "$TODAY" >"$WORK/verdict.log" 2>&1 || VERDICT=$?
if [[ $VERDICT -eq 1 ]] && grep -q "error: WaypointExampleTests/CartTests/testTotal failed" "$WORK/verdict.log"; then
    pass "a test with a display name is named by its identifier"
else
    fail "a test with a display name is named by its identifier ($(cat "$WORK/verdict.log"))"
fi

judge Passed Passed 65
if [[ $VERDICT -eq 1 ]] && grep -q "no test failed" "$WORK/verdict.log"; then
    pass "a step that failed with no failed test, such as a build error, blocks"
else
    fail "a step that failed with no failed test blocks ($(cat "$WORK/verdict.log"))"
fi

VERDICT=0
printf '' | scripts/flaky-tests.py --step-status 65 --today "$TODAY" >"$WORK/verdict.log" 2>&1 ||
    VERDICT=$?
if [[ $VERDICT -eq 1 ]]; then
    pass "a failed step with no readable results keeps its failure"
else
    fail "a failed step with no readable results keeps its failure"
fi

# A failed step passes only when its tests account for every failure.
VERDICT=0
bundle Failed,Passed Passed | python3 -c '
import json, sys
data = json.load(sys.stdin)
data["testNodes"][0]["children"][0]["children"].append(
    {"nodeType": "Failure Message", "name": "Test runner crashed between tests"})
print(json.dumps(data))' |
    scripts/flaky-tests.py --step-status 65 --today "$TODAY" >"$WORK/verdict.log" 2>&1 || VERDICT=$?
if [[ $VERDICT -eq 1 ]] && grep -q "failed outside its tests: Test runner crashed" "$WORK/verdict.log"; then
    pass "a failure outside the tests keeps a failed step failed, even beside a flaky test"
else
    fail "a failure outside the tests keeps a failed step failed ($(cat "$WORK/verdict.log"))"
fi
VERDICT=0
bundle Failed,Passed Passed |
    scripts/flaky-tests.py --step-status 65 --other-errors 1 --today "$TODAY" >"$WORK/verdict.log" 2>&1 ||
    VERDICT=$?
if [[ $VERDICT -eq 1 ]] && grep -q "1 error(s) outside its tests" "$WORK/verdict.log"; then
    pass "a build error in the bundle keeps a failed step failed, even beside a flaky test"
else
    fail "a build error in the bundle keeps a failed step failed ($(cat "$WORK/verdict.log"))"
fi

quarantine <<EOF
{ "tests": [ { "test": "$UI", "issue": 12, "since": "2026-11-20" } ] }
EOF
judge Failed,Failed Passed 65
if [[ $VERDICT -eq 0 ]] &&
    grep -q "^Quarantined: $UI failed every try; it doesn't block until 2026-11-26, issue #12" \
        "$WORK/verdict.log"; then
    pass "a quarantined UI test that fails both tries doesn't block, and is listed"
else
    fail "a quarantined UI test that fails both tries doesn't block ($(cat "$WORK/verdict.log"))"
fi

judge Failed,Failed Failed 65
if [[ $VERDICT -eq 1 ]]; then
    pass "a quarantined test doesn't hide another test's failure"
else
    fail "a quarantined test doesn't hide another test's failure"
fi

quarantine <<EOF
{ "tests": [ { "test": "$UI", "issue": 12, "since": "2026-11-19" } ] }
EOF
judge Failed,Failed Passed 65
if [[ $VERDICT -eq 1 ]] && grep -q "^Quarantine expired: $UI" "$WORK/verdict.log"; then
    pass "a test quarantined 7 days ago blocks again"
else
    fail "a test quarantined 7 days ago blocks again ($(cat "$WORK/verdict.log"))"
fi

# The quarantine file's shape.
refused() {
    local reason="$1" expected="$2" status=0
    scripts/flaky-tests.py --check-quarantine "$WORK/quarantine.json" --today "$TODAY" \
        >"$WORK/check.log" 2>&1 || status=$?
    if [[ $status -eq 2 ]] && grep -q "$expected" "$WORK/check.log"; then
        pass "a quarantine file with $reason is refused"
    else
        fail "a quarantine file with $reason is refused ($(cat "$WORK/check.log"))"
    fi
}
quarantine <<'EOF'
{ "tests": [
  { "test": "WaypointExampleUITests/A/testA", "issue": 1, "since": "2026-11-25" },
  { "test": "WaypointExampleUITests/B/testB", "issue": 2, "since": "2026-11-25" },
  { "test": "WaypointExampleUITests/C/testC", "issue": 3, "since": "2026-11-25" },
  { "test": "WaypointExampleUITests/D/testD", "issue": 4, "since": "2026-11-25" }
] }
EOF
refused "4 tests" "at most 3 may be"
quarantine <<'EOF'
{ "tests": [ { "test": "WaypointExampleUITests/A/testA", "since": "2026-11-25" } ] }
EOF
refused "a test without an issue" "needs the number of its open flaky-test issue"
quarantine <<'EOF'
{ "tests": [ { "test": "WaypointExampleUITests/A/testA", "issue": 1, "since": "2026-12-01" } ] }
EOF
refused "a future date" "is in the future"
quarantine <<'EOF'
{ "tests": [ { "test": "WaypointExampleUITests/A/testA", "issue": 1, "since": "soon" } ] }
EOF
refused "a bad date" "since must be a date"
quarantine <<'EOF'
{ "tests": [
  { "test": "WaypointExampleUITests/A/testA", "issue": 1, "since": "2026-11-25" },
  { "test": "WaypointExampleUITests/A/testA", "issue": 2, "since": "2026-11-25" }
] }
EOF
refused "a test listed twice" "listed twice"
quarantine <<'EOF'
{ "tests": [ { "test": "WaypointExampleTests/CartTests/testTotal", "issue": 1, "since": "2026-11-25" } ] }
EOF
refused "a unit test" "the test must read WaypointExampleUITests"

quarantine <<'EOF'
{ "tests": [ { "test": "WaypointExampleUITests/A/testA", "issue": 1, "since": "2026-11-10" } ] }
EOF
if scripts/flaky-tests.py --check-quarantine "$WORK/quarantine.json" --today "$TODAY" \
    >"$WORK/check.log" 2>&1 && grep -q "^warning: WaypointExampleUITests/A/testA was quarantined" \
    "$WORK/check.log"; then
    pass "an expired entry only warns, so an unrelated pull request stays green"
else
    fail "an expired entry only warns ($(cat "$WORK/check.log"))"
fi

# A run that gets a wrong quarantine file fails rather than guessing.
quarantine <<'EOF'
{ "tests": "none" }
EOF
judge Failed,Failed Passed 65
if [[ $VERDICT -eq 2 ]]; then
    pass "a run with a wrong quarantine file fails"
else
    fail "a run with a wrong quarantine file fails"
fi

# The repo's own list.
if scripts/flaky-tests.py --check-quarantine Example/quarantine.json; then
    pass "Example/quarantine.json keeps the quarantine rules"
else
    fail "Example/quarantine.json keeps the quarantine rules"
fi

if [[ $FAILURES -gt 0 ]]; then
    echo "$FAILURES flaky-test check(s) failed" >&2
    exit 1
fi
echo "All flaky-test checks passed."
