#!/usr/bin/env bash
#
#  check-selective-testing-hashes.sh
#  Waypoint
#
#  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
#  Copyright © 2026 Yousef Mohamed. MIT License.
#
# Checks that Tuist's selective testing sees every part of the package (planning #429). Selective testing
# skips a test target that already passed with the same hash, so the hash must change whenever
# something the tests run changes. In a copy of the working tree, this adds a comment line to one
# Swift file of each package module and of the example app, one at a time, and checks that each
# edit changes the hashes of the example app and its unit tests. A docs edit must change neither.
#
# The same edits prove that Tuist's binary cache (planning #441) never hands a run a stale package
# module: an edit in a module changes its cache key (`tuist hash cache`) and the keys of every
# module that depends on it, so a run builds them from source until a green run warms the new keys.
#
# `tuist hash selective-testing` takes no destination, so it lists no hash for the UI tests: Tuist
# hashes a UI test target only for a run with a destination, which `tuist test --device` gives it.
# On 2026-11-24 the whole UI test target was skipped on a second run with nothing changed, and ran
# again after a `WaypointCore` edit, so its hash takes the package through the app it launches.
#
# Runs on a Mac with Tuist (pinned in .mise.toml). Part of `scripts/test-mac.sh full` and `release`.
#
# Usage: scripts/check-selective-testing-hashes.sh

set -euo pipefail

cd "$(dirname "$0")/.."

# One Swift file of each part that the example app's tests run.
PROBED_PARTS=(
    Sources/WaypointCore
    Sources/WaypointOSLog
    Sources/Waypoint
    Sources/WaypointUIKit
    Example/WaypointExample
)
# The targets whose hashes must change with each of them.
HASHED_TARGETS=(WaypointExample WaypointExampleTests)
# The package's modules, which the binary cache may take as binaries, and the modules whose cache
# keys an edit in each one must change: the module itself and every module that depends on it.
CACHED_MODULES=(WaypointCore WaypointOSLog Waypoint WaypointUIKit)
cache_keys_moved_by() {
    case "$1" in
        Sources/WaypointCore) echo WaypointCore WaypointOSLog Waypoint WaypointUIKit ;;
        Sources/WaypointOSLog) echo WaypointOSLog Waypoint WaypointUIKit ;;
        Sources/Waypoint) echo Waypoint ;;
        Sources/WaypointUIKit) echo WaypointUIKit ;;
        *) echo "" ;;
    esac
}

tuist_cmd() {
    if command -v mise >/dev/null && [[ -f .mise.toml ]]; then
        mise exec -- tuist "$@"
    else
        tuist "$@"
    fi
}

WORK=$(mktemp -d)
cleanup() {
    rm -rf "$WORK"
}
trap cleanup EXIT

# The working tree as it is, uncommitted and new files included, without what git ignores. Tuist
# runs from the clone, where mise trusts .mise.toml, and reads the copy through `--path`.
TREE="$WORK/tree"
mkdir -p "$TREE"
# A tracked file deleted but not committed is listed too, so only files that exist are copied.
git ls-files -z --cached --others --exclude-standard |
    while IFS= read -r -d '' file; do
        if [[ -e "$file" ]]; then
            printf '%s\0' "$file"
        fi
    done |
    tar --null -T - -cf - | tar -xf - -C "$TREE"

# Prints `target hash` for each hashed target, or fails when Tuist lists no hash for one.
hashes() {
    local out target hash
    out=$(tuist_cmd hash selective-testing --path "$TREE/Example" 2>&1) || {
        echo "$out" >&2
        return 1
    }
    for target in "${HASHED_TARGETS[@]}"; do
        hash=$(grep -w -- "$target" <<<"$out" | grep -oE '[0-9a-f]{16,}' | head -1 || true)
        if [[ -z "$hash" ]]; then
            echo "error: tuist hash selective-testing lists no hash for $target" >&2
            echo "$out" >&2
            return 1
        fi
        echo "$target $hash"
    done
}

# Prints `module key` for each package module, or fails when Tuist lists no key for one.
cache_keys() {
    local out module key lines
    out=$(tuist_cmd hash cache --path "$TREE/Example" 2>&1) || {
        echo "$out" >&2
        return 1
    }
    for module in "${CACHED_MODULES[@]}"; do
        # One line per target, the name first and then its key, such as `Waypoint - 6c2dc13f…`.
        # The name must be the line's whole first word, so `Waypoint` never matches
        # `WaypointCore`, `Waypoint-Package` or a path, and exactly one line may match.
        lines=$(grep -E "^[[:space:]*•-]*${module}[[:space:]]*[:-]?[[:space:]]+[0-9a-f]{16,}" <<<"$out" || true)
        if [[ -z "$lines" || $(wc -l <<<"$lines") -ne 1 ]]; then
            echo "error: tuist hash cache lists ${lines:+more than one key}${lines:-no key} for $module" >&2
            echo "$out" >&2
            return 1
        fi
        key=$(grep -oE '[0-9a-f]{16,}' <<<"$lines" | head -1)
        echo "$module $key"
    done
}

FAILURES=0
fail() {
    echo "FAIL: $1" >&2
    FAILURES=$((FAILURES + 1))
}
pass() {
    echo "ok: $1"
}

tuist_cmd install --path "$TREE/Example" >/dev/null
BASE=$(hashes)
BASE_KEYS=$(cache_keys)

# Adds a line to `file` in the copy, prints the hashes, and puts the file back.
hashes_after_edit() {
    local file="$TREE/$1" line="$2" saved="$WORK/saved"
    cp "$file" "$saved"
    echo "$line" >>"$file"
    local result status=0
    result=$(hashes && cache_keys) || status=$?
    cp "$saved" "$file"
    [[ $status -eq 0 ]] || return "$status"
    echo "$result"
}

for part in "${PROBED_PARTS[@]}"; do
    file=$(cd "$TREE" && find "$part" -name '*.swift' -type f | sort | head -1)
    if [[ -z "$file" ]]; then
        fail "$part has a Swift file to edit"
        continue
    fi
    after=$(hashes_after_edit "$file" "// selective testing probe")
    for target in "${HASHED_TARGETS[@]}"; do
        if [[ "$(grep "^$target " <<<"$BASE")" != "$(grep "^$target " <<<"$after")" ]]; then
            pass "an edit in $part changes the hash of $target"
        else
            fail "an edit in $part changes the hash of $target ($file)"
        fi
    done
    moved=" $(cache_keys_moved_by "$part") "
    for module in "${CACHED_MODULES[@]}"; do
        changed=false
        if [[ "$(grep "^$module " <<<"$BASE_KEYS")" != "$(grep "^$module " <<<"$after")" ]]; then
            changed=true
        fi
        if [[ "$moved" == *" $module "* ]]; then
            if $changed; then
                pass "an edit in $part changes the cache key of $module"
            else
                fail "an edit in $part changes the cache key of $module ($file)"
            fi
        elif $changed; then
            fail "an edit in $part leaves the cache key of $module alone ($file)"
        else
            pass "an edit in $part leaves the cache key of $module alone"
        fi
    done
done

after=$(hashes_after_edit README.md "Selective testing probe.")
if [[ "$after" == "$BASE"$'\n'"$BASE_KEYS" ]]; then
    pass "a docs edit changes no hash and no cache key"
else
    fail "a docs edit changes no hash and no cache key"
fi

if [[ $FAILURES -gt 0 ]]; then
    echo "$FAILURES selective testing hash checks failed." >&2
    exit 1
fi
echo "All selective testing hash checks passed."
