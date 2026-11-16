#!/usr/bin/env bash
#
#  check-core-imports.sh
#  Waypoint
#
#  Created by Yousef Mohamed <52625092+JoeOCT91@users.noreply.github.com>.
#  Copyright © 2026 Yousef Mohamed. MIT License.
#
# Fails when a file in Sources/WaypointCore imports a module other than the allowed ones.
# WaypointCore must stay pure Swift so it builds and tests on Linux.
#
# Usage: scripts/check-core-imports.sh [core-sources-dir]

set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
core_dir="${1:-$root/Sources/WaypointCore}"
allowed="Foundation Observation Synchronization WaypointCore"

if [ ! -d "$core_dir" ]; then
    echo "error: $core_dir does not exist" >&2
    exit 2
fi

failed=0
while IFS= read -r -d '' file; do
    # Matches `import X`, `@testable import X`, `@_exported import X`, `import struct X.Y` and `import X.Y`.
    while IFS=: read -r line text; do
        module="$(printf '%s\n' "$text" \
            | sed -E 's/^[[:space:]]*(@[A-Za-z_]+[[:space:]]+)*import[[:space:]]+((typealias|struct|class|enum|protocol|let|var|func)[[:space:]]+)?([A-Za-z_][A-Za-z0-9_]*).*/\4/')"
        case " $allowed " in
            *" $module "*) ;;
            *)
                echo "${file#"$root"/}:$line: WaypointCore may not import $module (allowed: $allowed)" >&2
                failed=1
                ;;
        esac
    done < <(grep -nE '^[[:space:]]*(@[A-Za-z_]+[[:space:]]+)*import[[:space:]]+' "$file" || true)
done < <(find "$core_dir" -name '*.swift' -print0)

if [ "$failed" -ne 0 ]; then
    exit 1
fi
echo "WaypointCore imports only: $allowed"
