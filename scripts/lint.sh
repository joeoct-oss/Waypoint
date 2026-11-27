#!/usr/bin/env bash
#
#  lint.sh
#  Waypoint
#
#  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
#  Copyright © 2026 Yousef Mohamed. MIT License.
#
# Checks every Swift file against CODE_STYLE.md with the two tools that enforce it: swift-format
# (.swift-format) for layout, and SwiftLint (.swiftlint.yml) for the house rules. Any finding of
# either tool fails, with one exception: swift-format always writes empty braces as `{}`, and
# CODE_STYLE.md asks for `{ }`, so its "remove 1 space" finding at the space inside `{ }` is
# dropped. SwiftLint's `empty_braces_spaced` rule catches `{}` instead.
# Runs in the cloud while working, and in CI's fast checks. scripts/format.sh fixes what the
# tools can fix.
#
# CI runs the two halves apart: swift-format in the pinned Swift image, and SwiftLint on the
# runner host, because the Linux SwiftLint needs libxml2.so.2, which that image doesn't ship, and
# finds the host toolchain's SourceKit there.
#
# Usage: scripts/lint.sh [--swift-format-only | --swiftlint-only]

set -euo pipefail

cd "$(dirname "$0")/.." || exit 1
# shellcheck source=scripts/lint-tools.sh
source scripts/lint-tools.sh

part=all
case "${1:-}" in
    --swift-format-only) part=swift-format ;;
    --swiftlint-only) part=swiftlint ;;
    "") ;;
    *)
        echo "usage: scripts/lint.sh [--swift-format-only | --swiftlint-only]" >&2
        exit 2
        ;;
esac

failed=0

if [[ "$part" != swiftlint ]]; then
    check_swift_format
    echo "==> swift format lint"
    # Strict findings exit non-zero too, so only a failure that prints nothing is a failure here.
    format_status=0
    findings="$(swift format lint --strict --recursive --parallel "${LINT_PATHS[@]}" 2>&1)" ||
        format_status=$?
    if [[ "$format_status" -ne 0 && -z "$findings" ]]; then
        echo "error: swift format exited with status $format_status and printed nothing." >&2
        failed=1
    fi
    # Keeps every finding except "remove 1 space" at the space inside `{ }`. Bash only, since CI
    # runs this script in the Swift image, which has no Python or Perl.
    remaining=""
    while IFS= read -r finding; do
        if [[ "$finding" == *"[Spacing] remove 1 space"* ]]; then
            IFS=: read -r path line column _ <<< "$finding"
            if [[ -f "$path" && "$line" =~ ^[0-9]+$ && "$column" =~ ^[0-9]+$ && "$column" -ge 2 ]]; then
                text="$(sed -n "${line}p" "$path")"
                # swift-format counts columns in bytes, so slice bytes too.
                snippet="$(LC_ALL=C; printf '%s' "${text:column-2:3}")"
                if [[ "$snippet" == "{ }" ]]; then
                    continue
                fi
            fi
        fi
        remaining+="$finding"$'\n'
    done <<< "$findings"
    remaining="${remaining%$'\n'}"
    remaining="${remaining#$'\n'}"
    if [[ -n "$remaining" ]]; then
        echo "$remaining" >&2
        failed=1
fi

fi

if [[ "$part" != swift-format ]]; then
    find_swiftlint
    echo "==> swiftlint lint"
    output="$("$SWIFTLINT" lint --strict --quiet --baseline .swiftlint-baseline.json 2>&1)" || failed=1
    if [[ -n "$output" ]]; then
        echo "$output" >&2
    fi
    # Without SourceKit, SwiftLint skips the custom rules with only a warning.
    if grep -q "requires SourceKit" <<< "$output"; then
        echo "error: SwiftLint can't reach SourceKit; put a Swift toolchain's swift on the PATH." >&2
        failed=1
    fi
fi

if [[ "$failed" -ne 0 ]]; then
    echo "error: lint failed. scripts/format.sh fixes the layout findings; CODE_STYLE.md explains the rest." >&2
    exit 1
fi
echo "==> Lint passed"
