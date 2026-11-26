#!/usr/bin/env bash
#
#  own-warnings-as-errors.sh
#  Waypoint
#
#  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
#  Copyright © 2026 Yousef Mohamed. MIT License.
#
# Runs a command, usually xcodebuild through scripts/package-xcodebuild.sh, and fails it on any
# warning in the package's own `Sources/` or `Tests/`. `SWIFT_TREAT_WARNINGS_AS_ERRORS=YES` on the
# command line can't do this: it reaches every target, and Xcode builds a remote package such as
# Understudy with `-suppress-warnings`, which the compiler refuses alongside `-warnings-as-errors`.
# A dependency's warnings never count. The command's own status wins when it fails. The same rule
# as `own_warnings_as_errors` in scripts/test-mac.sh, for the Apple checks on GitHub's runners.
#
# Usage: scripts/own-warnings-as-errors.sh <command> [arguments]

set -euo pipefail

cd "$(dirname "$0")/.."

if [[ $# -lt 1 ]]; then
    echo "usage: scripts/own-warnings-as-errors.sh <command> [arguments]" >&2
    exit 2
fi

log=$(mktemp "${TMPDIR:-/tmp}/waypoint-xcodebuild.XXXXXX")
trap 'rm -f "$log"' EXIT
status=0
"$@" 2>&1 | tee "$log" || status=$?
if [[ "$status" == 0 ]]; then
    warnings=$(grep -E "^$PWD/(Sources|Tests)/[^:]+:[0-9]+:[0-9]+: warning:" "$log" | sort -u || true)
    if [[ -n "$warnings" ]]; then
        echo "error: warnings in Waypoint's own code, which count as errors:" >&2
        echo "$warnings" >&2
        status=1
    fi
fi
exit "$status"
