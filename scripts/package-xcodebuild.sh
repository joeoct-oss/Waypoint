#!/usr/bin/env bash
#
#  package-xcodebuild.sh
#  Waypoint
#
#  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
#  Copyright © 2026 Yousef Mohamed. MIT License.
#
# Runs xcodebuild on the package's own `Waypoint-Package` scheme (planning #429). The example app takes the
# package through Tuist's package integration, so Tuist writes the package's project,
# `Waypoint.xcodeproj` and `Derived/`, into the package root whenever it generates the app. While
# that project sits next to `Package.swift`, xcodebuild opens it and finds no `Waypoint-Package`
# scheme. This moves both into `.build/tuist-package-project`, runs xcodebuild with the arguments
# given, and puts them back when it ends, pass, fail or stop. Putting them back matters: an app
# workspace whose package project is gone builds against stale package products.
#
# It also passes `-skipMacroValidation` (planning #506): the test targets take Understudy, whose
# macros xcodebuild refuses to build until someone trusts them in Xcode, which no script run can.
#
# Usage: scripts/package-xcodebuild.sh <xcodebuild arguments>
#        scripts/package-xcodebuild.sh --restore   (puts back what a stopped run left aside)

set -euo pipefail

cd "$(dirname "$0")/.."

GENERATED=(Waypoint.xcodeproj Derived)
ASIDE=.build/tuist-package-project

restore() {
    local path
    for path in "${GENERATED[@]}"; do
        if [[ -e "$ASIDE/$path" && ! -e "$path" ]]; then
            mv "$ASIDE/$path" "$path"
        fi
    done
}

if [[ "${1:-}" == --restore ]]; then
    restore
    exit 0
fi

for path in "${GENERATED[@]}"; do
    [[ -e "$path" ]] || continue
    if git ls-files --error-unmatch "$path" >/dev/null 2>&1; then
        echo "error: $path is committed; only Tuist's generated project may be moved aside" >&2
        exit 1
    fi
done

trap restore EXIT
trap 'exit 143' TERM
trap 'exit 130' INT
for path in "${GENERATED[@]}"; do
    [[ -e "$path" ]] || continue
    mkdir -p "$ASIDE"
    rm -rf "${ASIDE:?}/$path"
    mv "$path" "$ASIDE/$path"
done
xcodebuild -skipMacroValidation "$@"
