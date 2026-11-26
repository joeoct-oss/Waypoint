#!/usr/bin/env bash
#
#  lint-tools.sh
#  Waypoint
#
#  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
#  Copyright © 2026 Yousef Mohamed. MIT License.
#
# Shared by scripts/lint.sh and scripts/format.sh, which source it: finds SwiftLint at the version
# pinned in .mise.toml (installing it with scripts/bootstrap.sh on Linux when it is missing), and
# checks that the toolchain's `swift format` is the pinned major.minor. On a version mismatch it
# stops, because two versions can format the same file two ways.
# - SwiftLint comes from $SWIFTLINT, then .tools/bin/swiftlint, then the PATH (mise on the Mac).
# - The linted paths are LINT_PATHS: the example app's folders by name, so Tuist's generated
#   Example/Derived is never formatted or linted.

set -euo pipefail

LINT_PATHS=(
    Sources
    Tests
    Example/ModuleTests
    Example/WaypointExample
    Example/WaypointExampleTests
    Example/WaypointExampleUITests
    Example/Project.swift
    Example/Tuist.swift
    Example/Tuist/Package.swift
    Package.swift
)

# Prints the value of `key = "value"` from .mise.toml.
pinned() {
    local key="$1"
    sed -n "s/^$key *= *\"\(.*\)\"/\1/p" .mise.toml | head -n 1
}

find_swiftlint() {
    local wanted
    wanted="$(pinned swiftlint)"
    if [[ -z "${SWIFTLINT:-}" ]]; then
        if [[ -x .tools/bin/swiftlint ]]; then
            SWIFTLINT=.tools/bin/swiftlint
        elif command -v swiftlint > /dev/null 2>&1; then
            SWIFTLINT="$(command -v swiftlint)"
        elif [[ "$(uname -s)" == "Linux" ]]; then
            scripts/bootstrap.sh > /dev/null
            SWIFTLINT=.tools/bin/swiftlint
        else
            echo "error: SwiftLint is not installed. Run scripts/bootstrap.sh." >&2
            exit 1
        fi
    fi
    local found
    found="$("$SWIFTLINT" version)"
    if [[ "$found" != "$wanted" ]]; then
        echo "error: SwiftLint $found found, .mise.toml pins $wanted. Run scripts/bootstrap.sh." >&2
        exit 1
    fi
}

check_swift_format() {
    local wanted found
    wanted="$(pinned WAYPOINT_SWIFT_FORMAT)"
    found="$(swift format --version)"
    if [[ "$found" != "$wanted" && "$found" != "$wanted".* ]]; then
        echo "error: swift format $found found, .mise.toml expects $wanted." >&2
        exit 1
    fi
}
