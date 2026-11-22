#!/usr/bin/env bash
#
#  check-single-import.sh
#  Waypoint
#
#  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
#  Copyright © 2026 Yousef Mohamed. MIT License.
#
# Fails when app-facing code imports both `Waypoint` and `WaypointCore`, or imports
# `WaypointCore` next to SwiftUI or UIKit (#304). `Waypoint` re-exports the core, so a file
# imports `Waypoint`, or `WaypointCore` alone when it draws nothing. Checks every Swift file in the example app and every Swift code block in the README
# files, the DocC catalogs and docs/. The package's own sources and tests are not checked: they
# name each module they use.
#
# Usage: scripts/check-single-import.sh

set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"

import_pattern='^[[:space:]]*(@[A-Za-z_]+[[:space:]]+)*import[[:space:]]+'

failed=0

# Swift files: both imports anywhere in one file, or the core next to a UI framework.
while IFS= read -r -d '' file; do
    if grep -qE "${import_pattern}Waypoint([[:space:]]|$)" "$file" \
        && grep -qE "${import_pattern}WaypointCore([[:space:]]|$)" "$file"; then
        echo "$file: imports both Waypoint and WaypointCore; import Waypoint only" >&2
        failed=1
    elif grep -qE "${import_pattern}WaypointCore([[:space:]]|$)" "$file" \
        && grep -qE "${import_pattern}(SwiftUI|UIKit)([[:space:]]|$)" "$file"; then
        echo "$file: draws but imports WaypointCore; import Waypoint instead" >&2
        failed=1
    fi
done < <(find Example -name '*.swift' -not -path '*/Derived/*' -print0)

# Markdown: both imports in one ```swift block.
markdown_files=()
while IFS= read -r -d '' file; do
    markdown_files+=("$file")
done < <(find README.md Example/README.md Sources docs -name '*.md' -print0 2>/dev/null)

for file in "${markdown_files[@]}"; do
    awk -v file="$file" '
        /^[[:space:]]*```swift/ { inside = 1; start = NR; app = 0; core = 0; next }
        /^[[:space:]]*```/ && inside {
            if (app && core) {
                printf "%s:%d: a code block imports both Waypoint and WaypointCore; import Waypoint only\n", file, start > "/dev/stderr"
                bad = 1
            }
            inside = 0
            next
        }
        inside && /^[[:space:]]*(@[A-Za-z_]+[[:space:]]+)*import[[:space:]]+Waypoint[[:space:]]*$/ { app = 1 }
        inside && /^[[:space:]]*(@[A-Za-z_]+[[:space:]]+)*import[[:space:]]+WaypointCore[[:space:]]*$/ { core = 1 }
        END { exit bad }
    ' "$file" || failed=1
done

if [ "$failed" -ne 0 ]; then
    exit 1
fi
echo "No example app file or docs code block imports both Waypoint and WaypointCore"
