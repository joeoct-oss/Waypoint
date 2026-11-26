#!/usr/bin/env bash
#
#  format.sh
#  Waypoint
#
#  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
#  Copyright © 2026 Yousef Mohamed. MIT License.
#
# Fixes what the lint tools can fix, before a commit: `swift format` rewrites the layout, then
# every `{}` it wrote in code goes back to `{ }` (CODE_STYLE.md, "Empty braces have one space
# inside"), at the places SwiftLint's `empty_braces_spaced` rule reports, so strings and comments
# are never touched. Last, `swiftlint lint --fix` applies SwiftLint's own fixes. Run
# scripts/lint.sh afterwards for what is left to fix by hand.
#
# Usage: scripts/format.sh

set -euo pipefail

cd "$(dirname "$0")/.."
# shellcheck source=scripts/lint-tools.sh
source scripts/lint-tools.sh

find_swiftlint
check_swift_format

echo "==> swift format format"
swift format format --in-place --recursive --parallel "${LINT_PATHS[@]}"

echo "==> {} to { }"
"$SWIFTLINT" lint --quiet --lenient --reporter json --only-rule empty_braces_spaced \
    | python3 -I -c '
import json, sys
places = {}
for finding in json.load(sys.stdin):
    places.setdefault(finding["file"], []).append((finding["line"], finding["character"]))
for path, spots in places.items():
    with open(path, encoding="utf-8") as source:
        lines = source.read().split("\n")
    # From the end of each line, so an earlier fix never moves a later column.
    for line, column in sorted(spots, reverse=True):
        text = lines[line - 1]
        # SwiftLint counts columns in UTF-16 units; find the string index they point at.
        units = 0
        index = 0
        while index < len(text) and units < column - 1:
            units += 2 if ord(text[index]) > 0xFFFF else 1
            index += 1
        if text[index:index + 2] == "{}":
            lines[line - 1] = text[:index] + "{ }" + text[index + 2:]
    with open(path, "w", encoding="utf-8") as source:
        source.write("\n".join(lines))
    print(f"{path}: {len(spots)}")
'

echo "==> swiftlint lint --fix"
"$SWIFTLINT" lint --fix --quiet
