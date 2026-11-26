#!/usr/bin/env bash
#
#  check-example-isolation.sh
#  Waypoint
#
#  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
#  Copyright © 2026 Yousef Mohamed. MIT License.
#
# Fails when the example app or its unit tests write `@MainActor`. Their targets are main actor by
# default (`SWIFT_DEFAULT_ACTOR_ISOLATION` in Example/Project.swift), so code there marks only what
# runs elsewhere, with `nonisolated` or `@concurrent`. The one allowed form is a task that
# nonisolated code sends back to the main actor, `Task { @MainActor in`. The package writes every
# isolation explicitly and isn't checked here. See CODE_STYLE.md. The custom SwiftLint rule
# `no_main_actor_in_example` (scripts/lint.sh) checks the same.
#
# Usage: scripts/check-example-isolation.sh [example-dir]

set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
example_dir="${1:-$root/Example}"
checked="WaypointExample WaypointExampleTests ModuleTests"

if [ ! -d "$example_dir" ]; then
    echo "error: $example_dir does not exist" >&2
    exit 2
fi

failed=0
for target in $checked; do
    while IFS= read -r found; do
        echo "${found#"$root"/}: write no @MainActor in the example app; it is main actor by default" >&2
        failed=1
    done < <(grep -rn --include='*.swift' '@MainActor' "$example_dir/$target" | grep -v 'Task { @MainActor in' || true)
done

if [ "$failed" -ne 0 ]; then
    exit 1
fi
echo "The example app writes no @MainActor"
