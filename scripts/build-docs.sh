#!/usr/bin/env bash
#
#  build-docs.sh
#  Waypoint
#
#  Created by Yousef Mohamed <52625092+JoeOCT91@users.noreply.github.com>.
#  Copyright © 2026 Yousef Mohamed. MIT License.
#
# Builds the documentation site: the WaypointCore, Waypoint and WaypointUIKit
# catalogs, built for iOS so the renderer pages have their symbols, merged into
# one archive and made ready for static hosting.
#
# Usage: scripts/build-docs.sh
# Output: .build/docs-site (upload it with scripts/deploy-docs.sh).
# Runs on a Mac with Xcode. On Linux the renderers compile empty, so the site
# would have no SwiftUI or UIKit symbols.

set -euo pipefail

cd "$(dirname "$0")/.."

MODULES=(WaypointCore Waypoint WaypointUIKit)
WORK_DIR=.build/docs-work
SITE_DIR=.build/docs-site

rm -rf "$WORK_DIR" "$SITE_DIR"
mkdir -p "$WORK_DIR"

echo "==> xcodebuild docbuild Waypoint-Package for iOS"
xcodebuild docbuild -quiet \
    -scheme Waypoint-Package \
    -destination "generic/platform=iOS" \
    -derivedDataPath "$WORK_DIR/DerivedData"

ARCHIVES=()
for module in "${MODULES[@]}"; do
    archive=$(find "$WORK_DIR/DerivedData/Build/Products" -type d -name "$module.doccarchive" -print -quit)
    if [[ -z "$archive" ]]; then
        echo "error: no $module.doccarchive in the build products" >&2
        exit 1
    fi
    ARCHIVES+=("$archive")
done

echo "==> docc merge ${MODULES[*]}"
xcrun docc merge "${ARCHIVES[@]}" \
    --synthesized-landing-page-name Waypoint \
    --output-path "$WORK_DIR/Waypoint.doccarchive"

echo "==> docc transform-for-static-hosting"
xcrun docc process-archive transform-for-static-hosting "$WORK_DIR/Waypoint.doccarchive" \
    --output-path "$SITE_DIR"

# The archive's root page is empty, so the site's root opens the documentation.
printf '/ /documentation 302\n' > "$SITE_DIR/_redirects"

echo "Documentation site built in $SITE_DIR"
