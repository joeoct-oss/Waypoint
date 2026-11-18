#!/usr/bin/env bash
#
#  check-compile-failures.sh
#  Waypoint
#
#  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
#  Copyright © 2026 Yousef Mohamed. MIT License.
#
# Checks that code Waypoint promises to refuse at compile time really fails to compile, such as
# pushing another flow's route through a `FlowNavigator` (#25). Each file in Tests/CompileFailures
# has one `// expected-error: <text>` line; the file must fail to type-check against WaypointCore
# with an error that contains that text.
#
# Usage: scripts/check-compile-failures.sh

set -euo pipefail

cd "$(dirname "$0")/.."

swift build --target WaypointCore > /dev/null
bin_path="$(swift build --show-bin-path)"
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

failed=0
for fixture in Tests/CompileFailures/*.swift; do
    expected="$(sed -n 's|^// expected-error: ||p' "$fixture")"
    if [ -z "$expected" ]; then
        echo "error: $fixture has no '// expected-error:' line" >&2
        failed=1
        continue
    fi
    if output="$(swiftc -typecheck -swift-version 6 "${target_flags[@]}" -I "$module_dir" "$fixture" 2>&1)"; then
        echo "error: $fixture compiled, but it must fail with: $expected" >&2
        failed=1
    elif ! grep -qF -- "$expected" <<< "$output"; then
        echo "error: $fixture failed with another error than: $expected" >&2
        echo "$output" >&2
        failed=1
    else
        echo "ok: $fixture"
    fi
done

exit "$failed"
