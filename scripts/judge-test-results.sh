#!/usr/bin/env bash
#
#  judge-test-results.sh
#  Waypoint
#
#  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
#  Copyright © 2026 Yousef Mohamed. MIT License.
#
# Decides an example app test step on a CI runner, as `judged_example_tests_on` in
# scripts/test-mac.sh does on the Mac: scripts/flaky-tests.py reads the step's result bundle and
# Example/quarantine.json (TESTING.md, "Flaky tests and quarantine"). A UI test that passed on its
# retry is flaky and doesn't block; a UI test that failed both tries blocks unless it is
# quarantined; a unit test that needed a retry blocks; a failure outside the tests blocks. Without
# a result bundle, or without results in it, the step's own status stands. The verdict is written
# to `<bundle>-flaky.json` beside the bundle, and the exit status is the step's.
#
# Usage: scripts/judge-test-results.sh <step status> <result bundle>

set -euo pipefail

cd "$(dirname "$0")/.."

if [[ $# -ne 2 ]]; then
    echo "usage: scripts/judge-test-results.sh <step status> <result bundle>" >&2
    exit 2
fi
status="$1"
bundle="$2"

if [[ ! -d "$bundle" ]]; then
    echo "note: no result bundle at $bundle to judge; the step's own status ($status) stands"
    exit "$status"
fi
results=$(mktemp "${TMPDIR:-/tmp}/waypoint-test-results.XXXXXX")
trap 'rm -f "$results"' EXIT
if ! xcrun xcresulttool get test-results tests --path "$bundle" >"$results" 2>/dev/null; then
    echo "note: no test results in $bundle to judge; the step's own status ($status) stands"
    exit "$status"
fi
# A build error the bundle records is a failure outside the tests, so the tests can't excuse it.
other_errors=$(xcrun xcresulttool get build-results --path "$bundle" 2>/dev/null |
    /usr/bin/python3 -c 'import json,sys; print(int(json.load(sys.stdin).get("errorCount", 0)))' \
        2>/dev/null || true)
[[ "$other_errors" =~ ^[0-9]+$ ]] || other_errors=0
scripts/flaky-tests.py --step-status "$status" --other-errors "$other_errors" \
    --quarantine Example/quarantine.json --out "${bundle%.xcresult}-flaky.json" <"$results"
