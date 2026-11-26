#!/usr/bin/env bash
#
#  core-coverage.sh
#  Waypoint
#
#  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
#  Copyright © 2026 Yousef Mohamed. MIT License.
#
# Writes the lines of Sources/WaypointCore that the core's unit tests ran, as an LCOV file, from
# the last `swift test --enable-code-coverage`. CI keeps it as the `coverage` artifact, which the
# checks workflow uploads to Codecov. It reports only: it never fails on a line no test runs.
# Extra arguments are the build flags that `swift test` used, so the bin path matches its build.
#
# Usage: scripts/core-coverage.sh <output.lcov> [swift build flags]

set -euo pipefail

cd "$(dirname "$0")/.."

if [[ $# -lt 1 ]]; then
    echo "usage: scripts/core-coverage.sh <output.lcov> [swift build flags]" >&2
    exit 2
fi
output="$1"
shift

build=$(swift build --show-bin-path "$@")
profile="$(dirname "$(swift test --show-codecov-path "$@")")/default.profdata"
if [[ ! -f "$profile" ]]; then
    echo "error: no coverage profile at $profile; run swift test --enable-code-coverage first" >&2
    exit 1
fi

# The core's test binary: a shared object with the newer build system, a test bundle with the
# older one, on Linux and on a Mac.
binary=""
for candidate in "$build/WaypointCoreTests.so" \
    "$build/WaypointCoreTests.xctest/Contents/MacOS/WaypointCoreTests" \
    "$build/WaypointPackageTests.xctest/Contents/MacOS/WaypointPackageTests" \
    "$build/WaypointPackageTests.xctest"; do
    if [[ -f "$candidate" ]]; then
        binary="$candidate"
        break
    fi
done
if [[ -z "$binary" ]]; then
    echo "error: no test binary for WaypointCoreTests in $build" >&2
    exit 1
fi

sources="$PWD/Sources/WaypointCore/"
llvm-cov export "$binary" -instr-profile="$profile" -format=lcov |
    awk -v sources="$sources" '
        /^SF:/ { keep = index(substr($0, 4), sources) == 1 }
        keep { print }
    ' >"$output"

files=$(grep -c '^SF:' "$output" || true)
if [[ "$files" == 0 ]]; then
    echo "error: the coverage report lists no file of Sources/WaypointCore" >&2
    exit 1
fi
echo "Wrote the coverage of $files files of Sources/WaypointCore to $output."
