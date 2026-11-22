#!/usr/bin/env bash
#
#  test-linux.sh
#  Waypoint
#
#  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
#  Copyright © 2026 Yousef Mohamed. MIT License.
#
# Runs the WaypointCore checks that must pass on Linux: the import check, the concurrency guard
# rail, the Mac test script's run lock check (#294), the merge batch check (#295), a build with warnings as errors, the
# compile-fixture check, the unit tests, and the unit tests again under the thread sanitizer (#24).
# The renderer targets compile empty on Linux, so this covers the core only.
#
# Usage: scripts/test-linux.sh [extra swift test arguments]

set -euo pipefail

cd "$(dirname "$0")/.."

echo "==> Checking WaypointCore imports"
scripts/check-core-imports.sh

echo "==> Checking comment line width"
scripts/check-comment-width.sh

echo "==> Checking the concurrency guard rail"
scripts/check-concurrency.sh

echo "==> Checking the example app's isolation"
scripts/check-example-isolation.sh

echo "==> Checking that app code imports Waypoint once"
scripts/check-single-import.sh

echo "==> Checking the Mac test script's run lock"
scripts/check-test-mac-lock.sh

echo "==> Checking merge batches"
scripts/check-merge-batch.sh

echo "==> swift build"
swift build

echo "==> swift build --build-tests with warnings as errors"
swift build --build-tests -Xswiftc -warnings-as-errors --scratch-path .build/warnings-as-errors

echo "==> Checking compile fixtures"
scripts/check-compile-failures.sh

echo "==> swift test"
swift test "$@"

echo "==> swift test under the thread sanitizer"
swift test --sanitize=thread --scratch-path .build/thread-sanitizer "$@"

echo "==> Linux checks passed"
