#!/usr/bin/env bash
#
#  build-docs.sh
#  Waypoint
#
#  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
#  Copyright © 2026 Yousef Mohamed. MIT License.
#
# Builds the documentation site: the WaypointCore, Waypoint and WaypointUIKit
# catalogs, built for iOS so the renderer pages have their symbols, merged into
# one archive and made ready for static hosting.
#
# The Waypoint theme (colors, fonts, mark, favicon and landing page) comes from docs-theme.
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

THEME_DIR=docs-theme
FONTS_URL="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600&family=JetBrains+Mono:wght@400;500&family=Unbounded:wght@500;600;700&display=swap"

# Adds the Waypoint look from docs-theme: DocC colors and fonts, the mark and favicon, the
# stylesheet on every DocC page, and the landing page at the site root with its motion script.
apply_theme() {
    cp "$THEME_DIR/theme-settings.json" "$SITE_DIR/theme-settings.json"
    mkdir -p "$SITE_DIR/images/waypoint"
    cp "$THEME_DIR"/images/*.svg "$THEME_DIR"/images/*.png "$SITE_DIR/images/waypoint/"
    cp "$THEME_DIR/images/favicon.svg" "$THEME_DIR/images/favicon.ico" "$SITE_DIR/"
    cp "$THEME_DIR/waypoint.css" "$SITE_DIR/css/waypoint.css"
    mkdir -p "$SITE_DIR/js"
    cp "$THEME_DIR/waypoint.js" "$SITE_DIR/js/waypoint.js"

    local head_links="<link rel=\"preconnect\" href=\"https://fonts.gstatic.com\" crossorigin><link rel=\"stylesheet\" href=\"$FONTS_URL\"><link rel=\"stylesheet\" href=\"/css/waypoint.css\"><script defer src=\"/js/waypoint.js\"></script>"
    find "$SITE_DIR" -name index.html -print0 |
        HEAD_LINKS="$head_links" xargs -0 perl -pi -e 's|</head>|$ENV{HEAD_LINKS}</head>|'

    cp "$THEME_DIR/index.html" "$SITE_DIR/index.html"
    cp "$THEME_DIR/landing.js" "$SITE_DIR/js/landing.js"
    mkdir -p "$SITE_DIR/js/vendor/gsap"
    cp "$THEME_DIR"/vendor/gsap/*.min.js "$SITE_DIR/js/vendor/gsap/"
    mkdir -p "$SITE_DIR/js/vendor/lenis"
    cp "$THEME_DIR"/vendor/lenis/*.min.js "$SITE_DIR/js/vendor/lenis/"
}

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

echo "==> Waypoint theme"
apply_theme

echo "Documentation site built in $SITE_DIR"
