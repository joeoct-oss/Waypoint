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
# Swift file of each package module and of the example app's parts, one at a time, and checks that
# each edit changes the hash of every test target that uses that part, and of no other. The module
# test targets (planning #445) run without the app, so an edit in a feature must leave the other
# features' tests alone, or selective testing would never skip them. A docs edit must change no
# hash.
#
# The same edits prove that Tuist's binary cache (planning #441) never hands a run a stale
# module, the package's or the example app's (planning #445): an edit in a module changes its
# cache key (`tuist hash cache`) and the keys of every module that depends on it, and no other, so
# a run builds them from source until a green run warms the new keys.
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
    Example/WaypointExample/App
    Example/WaypointExample/Catalog
    Example/WaypointExample/Services
    Example/WaypointExample/Flows/Auth
    Example/WaypointExample/Flows/Products
    Example/WaypointExample/Flows/Lab
    Example/WaypointExample/Flows/Cart
)
# The app and every unit test target, and the ones whose hashes an edit in each part must change:
# every target that uses the part, directly or through a module. The others must keep theirs.
APP_TARGETS="WaypointExample WaypointExampleTests"
FEATURE_TESTS="ExampleAuthTests ExampleProductsTests ExampleLabTests ExampleCartTests"
HASHED_TARGETS=(
    WaypointExample
    WaypointExampleTests
    ExampleCatalogTests
    ExampleServicesTests
    ExampleAuthTests
    ExampleProductsTests
    ExampleLabTests
    ExampleCartTests
)
hashes_moved_by() {
    case "$1" in
        Sources/WaypointCore | Sources/WaypointOSLog | Sources/Waypoint)
            echo $APP_TARGETS ExampleServicesTests $FEATURE_TESTS
            ;;
        Sources/WaypointUIKit | Example/WaypointExample/App) echo $APP_TARGETS ;;
        Example/WaypointExample/Catalog) echo "${HASHED_TARGETS[@]}" ;;
        Example/WaypointExample/Services) echo $APP_TARGETS ExampleServicesTests $FEATURE_TESTS ;;
        Example/WaypointExample/Flows/Auth) echo $APP_TARGETS ExampleAuthTests ;;
        Example/WaypointExample/Flows/Products) echo $APP_TARGETS ExampleProductsTests ;;
        Example/WaypointExample/Flows/Lab) echo $APP_TARGETS ExampleLabTests ;;
        Example/WaypointExample/Flows/Cart) echo $APP_TARGETS ExampleCartTests ;;
        *) echo "" ;;
    esac
}
# The modules the binary cache may take as binaries: the package's, and the example app's own
# (planning #445). An edit in a part must change the cache keys of the modules built from it and
# of every module that depends on them, and leave every other key alone.
CACHED_MODULES=(
    WaypointCore
    WaypointOSLog
    Waypoint
    WaypointUIKit
    ExampleCatalog
    ExampleStore
    ExampleServices
    ExampleDesignSystem
    ExampleNavigation
    ExampleAddresses
    ExampleAuth
    ExampleProducts
    ExampleLab
    ExampleCart
    ExampleAccount
)
# The example modules that use the package's Waypoint, directly or through another module: all but
# the catalog and the store.
USES_WAYPOINT="ExampleServices ExampleDesignSystem ExampleNavigation ExampleAddresses ExampleAuth
    ExampleProducts ExampleLab ExampleCart ExampleAccount"
cache_keys_moved_by() {
    case "$1" in
        Sources/WaypointCore) echo WaypointCore WaypointOSLog Waypoint WaypointUIKit $USES_WAYPOINT ;;
        Sources/WaypointOSLog) echo WaypointOSLog Waypoint WaypointUIKit $USES_WAYPOINT ;;
        Sources/Waypoint) echo Waypoint $USES_WAYPOINT ;;
        Sources/WaypointUIKit) echo WaypointUIKit ;;
        Example/WaypointExample/Catalog)
            echo ExampleCatalog ExampleDesignSystem ExampleNavigation ExampleAddresses ExampleAuth \
                ExampleProducts ExampleLab ExampleCart ExampleAccount
            ;;
        Example/WaypointExample/Services)
            echo ExampleServices ExampleAuth ExampleProducts ExampleLab ExampleCart ExampleAccount
            ;;
        Example/WaypointExample/Flows/Auth) echo ExampleAuth ;;
        Example/WaypointExample/Flows/Products) echo ExampleProducts ;;
        Example/WaypointExample/Flows/Lab) echo ExampleLab ExampleAccount ;;
        Example/WaypointExample/Flows/Cart) echo ExampleCart ;;
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

# Prints `module key` for each cached module, or fails when Tuist lists no key for one.
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
    hashed=" $(hashes_moved_by "$part") "
    for target in "${HASHED_TARGETS[@]}"; do
        changed=false
        if [[ "$(grep "^$target " <<<"$BASE")" != "$(grep "^$target " <<<"$after")" ]]; then
            changed=true
        fi
        if [[ "$hashed" == *" $target "* ]]; then
            if $changed; then
                pass "an edit in $part changes the hash of $target"
            else
                fail "an edit in $part changes the hash of $target ($file)"
            fi
        elif $changed; then
            fail "an edit in $part leaves the hash of $target alone ($file)"
        else
            pass "an edit in $part leaves the hash of $target alone"
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
