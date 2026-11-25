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
# something the tests run changes. In a copy of the working tree, this adds a line to one file of
# each part, one at a time: every package module, every folder of the example app (its modules,
# the app's own folders and its asset catalog) and every test folder. It checks that each edit
# changes the hash of every test target that uses that part, and of no other, and that a new file
# counts as an edit. The module test targets (planning #445) run without the app, so an edit in a
# feature must leave the other features' tests alone, or selective testing would never skip them.
# A docs edit must change no hash. Both directions matter: a hash that misses an edit lets a run
# skip a test that would now fail, and a hash that moves without one reruns tests for nothing.
#
# What this can't edit in a copy (the manifests, the tool versions, Xcode) is never trusted to the
# hashes: `scripts/test-mac.sh` turns selective testing and the binary cache off for a branch that
# changes a file the hashes don't cover, and after the tools change (TESTING.md, Trust the caches).
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

# One file of each part that the example app's tests run: every package module, every folder of
# the example app (its modules, the app's own folders and its resources), and every test folder.
PROBED_PARTS=(
    Sources/WaypointCore
    Sources/WaypointOSLog
    Sources/Waypoint
    Sources/WaypointUIKit
    Example/WaypointExample/App
    Example/WaypointExample/Resources
    Example/WaypointExample/Catalog
    Example/WaypointExample/Store
    Example/WaypointExample/Services
    Example/WaypointExample/DesignSystem
    Example/WaypointExample/Navigation
    Example/WaypointExample/Flows/Addresses
    Example/WaypointExample/Flows/Auth
    Example/WaypointExample/Flows/Products
    Example/WaypointExample/Flows/Lab
    Example/WaypointExample/Flows/Cart
    Example/WaypointExample/Flows/Account
    Example/WaypointExample/Flows/Main
    Example/WaypointExample/Flows/Splash
    Example/ModuleTests/Support
    Example/ModuleTests/Services
    Example/ModuleTests/Auth
    Example/ModuleTests/Products
    Example/ModuleTests/Lab
    Example/ModuleTests/Cart
    Example/WaypointExampleTests
)
# The app and every unit test target, and the ones whose hashes an edit in each part must change:
# every target that uses the part, directly or through a module. The others must keep theirs.
# `ExampleTestSupport` is under every module test target and the app's unit tests, and it uses the
# services, the design system and the navigation module, so an edit in any of those, or in what
# they use, moves every test target.
APP_TARGETS="WaypointExample WaypointExampleTests"
MODULE_TESTS="ExampleServicesTests ExampleAuthTests ExampleProductsTests ExampleLabTests ExampleCartTests"
HASHED_TARGETS=(
    WaypointExample
    WaypointExampleTests
    ExampleServicesTests
    ExampleAuthTests
    ExampleProductsTests
    ExampleLabTests
    ExampleCartTests
)
hashes_moved_by() {
    case "$1" in
        Sources/WaypointCore | Sources/WaypointOSLog | Sources/Waypoint) echo $APP_TARGETS $MODULE_TESTS ;;
        Sources/WaypointUIKit) echo $APP_TARGETS ;;
        Example/WaypointExample/App | Example/WaypointExample/Resources) echo $APP_TARGETS ;;
        Example/WaypointExample/Flows/Main | Example/WaypointExample/Flows/Splash) echo $APP_TARGETS ;;
        Example/WaypointExample/Catalog | Example/WaypointExample/Store) echo $APP_TARGETS $MODULE_TESTS ;;
        Example/WaypointExample/Services | Example/WaypointExample/DesignSystem) echo $APP_TARGETS $MODULE_TESTS ;;
        Example/WaypointExample/Navigation) echo $APP_TARGETS $MODULE_TESTS ;;
        Example/WaypointExample/Flows/Addresses) echo $APP_TARGETS ExampleCartTests ;;
        Example/WaypointExample/Flows/Auth) echo $APP_TARGETS ExampleAuthTests ;;
        Example/WaypointExample/Flows/Products) echo $APP_TARGETS ExampleProductsTests ;;
        Example/WaypointExample/Flows/Lab) echo $APP_TARGETS ExampleLabTests ;;
        Example/WaypointExample/Flows/Cart) echo $APP_TARGETS ExampleCartTests ;;
        Example/WaypointExample/Flows/Account) echo $APP_TARGETS ;;
        Example/ModuleTests/Support) echo WaypointExampleTests $MODULE_TESTS ;;
        Example/ModuleTests/Services) echo ExampleServicesTests ;;
        Example/ModuleTests/Auth) echo ExampleAuthTests ;;
        Example/ModuleTests/Products) echo ExampleProductsTests ;;
        Example/ModuleTests/Lab) echo ExampleLabTests ;;
        Example/ModuleTests/Cart) echo ExampleCartTests ;;
        Example/WaypointExampleTests) echo WaypointExampleTests ;;
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
    ExampleTestSupport
)
# The example modules that use the package's Waypoint, directly or through another module: all but
# the catalog and the store.
USES_WAYPOINT="ExampleServices ExampleDesignSystem ExampleNavigation ExampleAddresses ExampleAuth
    ExampleProducts ExampleLab ExampleCart ExampleAccount ExampleTestSupport"
# The modules above the design system: everything that uses it, the test support included.
ABOVE_DESIGN_SYSTEM="ExampleNavigation ExampleAddresses ExampleAuth ExampleProducts ExampleLab
    ExampleCart ExampleAccount ExampleTestSupport"
FEATURES="ExampleAuth ExampleProducts ExampleLab ExampleCart ExampleAccount"
cache_keys_moved_by() {
    case "$1" in
        Sources/WaypointCore) echo WaypointCore WaypointOSLog Waypoint WaypointUIKit $USES_WAYPOINT ;;
        Sources/WaypointOSLog) echo WaypointOSLog Waypoint WaypointUIKit $USES_WAYPOINT ;;
        Sources/Waypoint) echo Waypoint $USES_WAYPOINT ;;
        Sources/WaypointUIKit) echo WaypointUIKit ;;
        Example/WaypointExample/Catalog) echo ExampleCatalog ExampleDesignSystem $ABOVE_DESIGN_SYSTEM ;;
        Example/WaypointExample/Store)
            echo ExampleStore ExampleServices ExampleDesignSystem $ABOVE_DESIGN_SYSTEM
            ;;
        Example/WaypointExample/Services) echo ExampleServices $FEATURES ExampleTestSupport ;;
        Example/WaypointExample/DesignSystem) echo ExampleDesignSystem $ABOVE_DESIGN_SYSTEM ;;
        Example/WaypointExample/Navigation) echo ExampleNavigation $FEATURES ExampleTestSupport ;;
        Example/WaypointExample/Flows/Addresses) echo ExampleAddresses ExampleCart ExampleAccount ;;
        Example/WaypointExample/Flows/Auth) echo ExampleAuth ;;
        Example/WaypointExample/Flows/Products) echo ExampleProducts ;;
        Example/WaypointExample/Flows/Lab) echo ExampleLab ExampleAccount ;;
        Example/WaypointExample/Flows/Cart) echo ExampleCart ;;
        Example/WaypointExample/Flows/Account) echo ExampleAccount ;;
        Example/ModuleTests/Support) echo ExampleTestSupport ;;
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

# Checks one edit's hashes and keys against what the edit in `part` must move.
check_edit() {
    local part="$1" what="$2" after="$3" hashed moved target module changed
    hashed=" $(hashes_moved_by "$part") "
    for target in "${HASHED_TARGETS[@]}"; do
        changed=false
        if [[ "$(grep "^$target " <<<"$BASE")" != "$(grep "^$target " <<<"$after")" ]]; then
            changed=true
        fi
        if [[ "$hashed" == *" $target "* ]]; then
            if $changed; then
                pass "$what in $part changes the hash of $target"
            else
                fail "$what in $part changes the hash of $target"
            fi
        elif $changed; then
            fail "$what in $part leaves the hash of $target alone"
        else
            pass "$what in $part leaves the hash of $target alone"
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
                pass "$what in $part changes the cache key of $module"
            else
                fail "$what in $part changes the cache key of $module"
            fi
        elif $changed; then
            fail "$what in $part leaves the cache key of $module alone"
        else
            pass "$what in $part leaves the cache key of $module alone"
        fi
    done
}

for part in "${PROBED_PARTS[@]}"; do
    # A Swift file where the part has one, so the line is a comment; the resources have none.
    file=$(cd "$TREE" && find "$part" -name '*.swift' -type f | sort | head -1)
    line="// selective testing probe"
    if [[ -z "$file" ]]; then
        file=$(cd "$TREE" && find "$part" -type f | sort | head -1)
        line=" "
    fi
    if [[ -z "$file" ]]; then
        fail "$part has a file to edit"
        continue
    fi
    after=$(hashes_after_edit "$file" "$line")
    check_edit "$part" "an edit" "$after"
done

# A new file counts as much as an edit: Tuist reads the source folders again, so a file the
# manifests' globs pick up moves the same hashes and keys as an edit in that folder.
NEW_FILE="Example/WaypointExample/Flows/Cart/SelectiveTestingProbe.swift"
echo "// selective testing probe" >"$TREE/$NEW_FILE"
after=$(hashes && cache_keys)
rm "$TREE/$NEW_FILE"
check_edit Example/WaypointExample/Flows/Cart "a new file" "$after"

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
