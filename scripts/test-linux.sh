#!/usr/bin/env bash
#
#  test-linux.sh
#  Waypoint
#
#  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
#  Copyright © 2026 Yousef Mohamed. MIT License.
#
# Runs the WaypointCore checks that must pass on Linux: the import check, the concurrency guard
# rail, the Mac test script's run lock check (planning #420), the merge batch check (planning #421), one build with
# warnings as errors that the compile-fixture check and the unit tests reuse, and the unit tests
# again under the thread sanitizer (planning #278).
# The renderer targets compile empty on Linux, so this covers the core only.
#
# The script checks need no Swift, only bash, git, perl, python3 and procps, so CI runs them on
# the runner host with --checks-only and the Swift part in the Swift container with --swift-only.
# With neither flag, both run, as a local run needs.
#
# Usage: scripts/test-linux.sh [--checks-only | --swift-only] [extra swift test arguments]

set -euo pipefail

cd "$(dirname "$0")/.."

part=all
case "${1:-}" in
    --checks-only) part=checks; shift ;;
    --swift-only) part=swift; shift ;;
esac

if [ "$part" != swift ]; then
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

    echo "==> Checking the example app's folder order"
    scripts/check-example-module-edges.sh

    echo "==> Checking the Mac test script's run lock"
    scripts/check-test-mac-lock.sh

    echo "==> Checking the package's xcodebuild wrapper"
    scripts/check-package-xcodebuild.sh

    echo "==> Checking merge batches"
    scripts/check-merge-batch.sh

    if [ "$part" = checks ]; then
        echo "==> Linux script checks passed"
        exit 0
    fi
fi

# One build with warnings as errors serves the build check, the fixture check and the tests, as in
# scripts/test-mac.sh: a plain `swift build` first would only build the same code a second time.
SWIFT_FLAGS=(-Xswiftc -warnings-as-errors)

echo "==> swift build --build-tests with warnings as errors"
swift build --build-tests "${SWIFT_FLAGS[@]}"

echo "==> Checking compile fixtures"
WAYPOINT_SWIFT_BUILD_FLAGS="${SWIFT_FLAGS[*]}" scripts/check-compile-failures.sh

echo "==> swift test with warnings as errors"
swift test "${SWIFT_FLAGS[@]}" "$@"

echo "==> swift test under the thread sanitizer"
swift test --sanitize=thread --scratch-path .build/thread-sanitizer "$@"

echo "==> Linux checks passed"
