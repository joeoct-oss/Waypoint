#!/usr/bin/env bash
#
#  check-coordinator-size.sh
#  Waypoint
#
#  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
#  Copyright © 2026 Yousef Mohamed. MIT License.
#
# Fails when an example app coordinator file reaches 500 lines (CODE_STYLE.md, "An example app
# coordinator file stays under 500 lines"). A coordinator file is a Swift file in
# Example/WaypointExample whose name ends in `Coordinator.swift`. Bash and awk only, so it runs
# in CI's fast checks without a Swift toolchain.
#
# Usage: scripts/check-coordinator-size.sh

set -euo pipefail

cd "$(dirname "$0")/.."

LIMIT=500

failed=0
checked=0
while IFS= read -r -d '' file; do
    checked=$((checked + 1))
    lines=$(awk 'END { print NR }' "$file")
    if [[ "$lines" -ge "$LIMIT" ]]; then
        echo "error: $file has $lines lines; a coordinator file stays under $LIMIT" >&2
        failed=1
    fi
done < <(find Example/WaypointExample -name '*Coordinator.swift' -type f -print0)

if [[ "$checked" == 0 ]]; then
    echo "error: found no coordinator file in Example/WaypointExample" >&2
    exit 1
fi
if [[ "$failed" == 0 ]]; then
    echo "All $checked example app coordinator files are under $LIMIT lines."
fi
exit "$failed"
