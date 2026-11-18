#!/usr/bin/env bash
#
#  test-linux.sh
#  Waypoint
#
#  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
#  Copyright © 2026 Yousef Mohamed. MIT License.
#
# Runs the WaypointCore checks that must pass on Linux: the import check, a build, the
# compile-failure check and the unit tests.
# The renderer targets compile empty on Linux, so this covers the core only.
#
# Usage: scripts/test-linux.sh [extra swift test arguments]

set -euo pipefail

cd "$(dirname "$0")/.."

echo "==> Checking WaypointCore imports"
scripts/check-core-imports.sh

echo "==> Checking comment line width"
scripts/check-comment-width.sh

echo "==> swift build"
swift build

echo "==> Checking compile failures"
scripts/check-compile-failures.sh

echo "==> swift test"
swift test "$@"

echo "==> Linux checks passed"
