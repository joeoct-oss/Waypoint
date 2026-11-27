#!/usr/bin/env bash
#
#  build-example-tests.sh
#  Waypoint
#
#  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
#  Copyright © 2026 Yousef Mohamed. MIT License.
#
# Builds the example app and every test bundle its scheme runs, once, for the iPhone simulator
# a CI runner has, and packs the test products into .build/example-test-products.tar for the test
# jobs. Tuist generates the project first; it must be on the PATH (scripts/install-tuist.sh). The
# Xcode compilation cache is off, since its local proxy only runs on a Mac set up for it. A tar
# keeps the bundle's symbolic links and file modes, which an artifact's zip doesn't. The checks
# workflow's "Apple build" job runs it, and the Apple tests run it again only when that build's
# products can't be fetched.
#
# Usage: scripts/build-example-tests.sh <simulator name> <iOS version>

set -euo pipefail

cd "$(dirname "$0")/.."

if [[ $# -ne 2 ]]; then
    echo "usage: scripts/build-example-tests.sh <simulator name> <iOS version>" >&2
    exit 2
fi

tuist install --path Example
tuist generate --path Example --no-open

udid=$(scripts/find-ci-simulator.sh "$1" "$2")
xcodebuild build-for-testing -quiet \
    -workspace Example/WaypointExample.xcworkspace \
    -scheme WaypointExample \
    -destination "id=$udid" \
    -derivedDataPath .build/example-derived-data \
    -testProductsPath .build/WaypointExample.xctestproducts \
    -skipMacroValidation \
    COMPILATION_CACHE_ENABLE_CACHING=NO \
    WAYPOINT_TUIST_OFFLINE=1 WAYPOINT_TUIST_TEST_RUN=1

tar -C .build -cf .build/example-test-products.tar WaypointExample.xctestproducts
