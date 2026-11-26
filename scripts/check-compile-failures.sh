#!/usr/bin/env bash
#
#  check-compile-failures.sh
#  Waypoint
#
#  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
#  Copyright © 2026 Yousef Mohamed. MIT License.
#
# Checks the promises the compiler keeps:
#
# - Each file in Tests/CompileFailures must fail to type-check against WaypointCore, in the Swift 6
#   language mode, with an error containing the text of its `// expected-error: <text>` line.
#   A `// swift-5: fails` line checks the same error in the Swift 5 mode too; `// swift-5: warns`
#   checks that the Swift 5 mode at least warns with that text.
# - Each file in Tests/CompileSuccesses must type-check cleanly in the Swift 6 mode.
#
# Usage: scripts/check-compile-failures.sh

set -euo pipefail

cd "$(dirname "$0")/.."

# Extra `swift build` flags from WAYPOINT_SWIFT_BUILD_FLAGS. scripts/test-mac.sh passes the flags
# its `swift test` builds with, so the core built here is the one the tests reuse, not a second
# build.
build_flags=()
if [ -n "${WAYPOINT_SWIFT_BUILD_FLAGS:-}" ]; then
    read -r -a build_flags <<< "$WAYPOINT_SWIFT_BUILD_FLAGS"
fi

swift build --target WaypointCore ${build_flags[@]+"${build_flags[@]}"} > /dev/null
bin_path="$(swift build --show-bin-path ${build_flags[@]+"${build_flags[@]}"})"
module="$(find "$bin_path" -maxdepth 3 -name WaypointCore.swiftmodule -print -quit)"
if [ -z "$module" ]; then
    echo "error: WaypointCore.swiftmodule not found under $bin_path" >&2
    exit 2
fi
module_dir="$(dirname "$module")"

# On a Mac the package's minimum macOS (14, for Observation) must be named, or the module won't
# load.
target_flags=()
if [ "$(uname -s)" = "Darwin" ]; then
    target_flags=(-target "$(uname -m)-apple-macosx14.0")
fi

# Type-checks one file in a language mode, printing the compiler's output.
typecheck() {
    swiftc -typecheck -swift-version "$2" "${target_flags[@]}" -I "$module_dir" "$1" 2>&1
}

failed=0
for fixture in Tests/CompileFailures/*.swift; do
    expected="$(sed -n 's|^// expected-error: ||p' "$fixture")"
    swift5="$(sed -n 's|^// swift-5: ||p' "$fixture")"
    if [ -z "$expected" ]; then
        echo "error: $fixture has no '// expected-error:' line" >&2
        failed=1
        continue
    fi
    if output="$(typecheck "$fixture" 6)"; then
        echo "error: $fixture compiled, but it must fail with: $expected" >&2
        failed=1
        continue
    elif ! grep -qF -- "$expected" <<< "$output"; then
        echo "error: $fixture failed with another error than: $expected" >&2
        echo "$output" >&2
        failed=1
        continue
    fi
    case "$swift5" in
        fails)
            if output="$(typecheck "$fixture" 5)" || ! grep -qF -- "error: $expected" <<< "$output"; then
                echo "error: $fixture must also fail in the Swift 5 mode with: $expected" >&2
                echo "$output" >&2
                failed=1
                continue
            fi
            ;;
        warns)
            output="$(typecheck "$fixture" 5 || true)"
            if ! grep -qF -- "warning: $expected" <<< "$output"; then
                echo "error: $fixture must at least warn in the Swift 5 mode with: $expected" >&2
                echo "$output" >&2
                failed=1
                continue
            fi
            ;;
        "") ;;
        *)
            echo "error: $fixture has an unknown '// swift-5:' value: $swift5" >&2
            failed=1
            continue
            ;;
    esac
    echo "ok: $fixture${swift5:+ (Swift 5: $swift5)}"
done

for fixture in Tests/CompileSuccesses/*.swift; do
    if ! output="$(typecheck "$fixture" 6)"; then
        echo "error: $fixture must compile, but failed:" >&2
        echo "$output" >&2
        failed=1
    elif grep -q "warning:" <<< "$output"; then
        echo "error: $fixture must compile without warnings:" >&2
        echo "$output" >&2
        failed=1
    else
        echo "ok: $fixture compiles"
    fi
done

exit "$failed"
