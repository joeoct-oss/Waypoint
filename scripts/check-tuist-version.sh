#!/usr/bin/env bash
#
#  check-tuist-version.sh
#  Waypoint
#
#  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
#  Copyright © 2026 Yousef Mohamed. MIT License.
#
# Says whether a newer stable Tuist than the one `.mise.toml` pins is out (#334). The project runs
# the latest stable Tuist unless the new version is breaking: a newer minor or patch version gets a
# bump pull request with the usual Mac gate, and a new major version goes to Yousef first
# (TESTING.md). Canaries and release candidates never count.
#
# It only reports: it exits 0 whatever it finds, and when it can't reach GitHub. The daily
# `scripts/test-mac.sh coverage` run prints its answer.
#
# WAYPOINT_TUIST_TAGS_FILE reads the tag names from a file, one per line, instead of GitHub (the
# checks in scripts/check-test-mac-lock.sh use it).

set -uo pipefail

cd "$(dirname "$0")/.."

pinned=$(sed -n 's/^tuist *= *"\([^"]*\)".*/\1/p' .mise.toml | head -1)
if [[ -z "$pinned" ]]; then
    echo "Tuist version check: .mise.toml pins no Tuist"
    exit 0
fi

if [[ -n "${WAYPOINT_TUIST_TAGS_FILE:-}" ]]; then
    tags=$(cat "$WAYPOINT_TUIST_TAGS_FILE" 2>/dev/null || true)
else
    tags=$(git ls-remote --tags --refs https://github.com/tuist/tuist 2>/dev/null |
        sed 's#.*refs/tags/##' || true)
fi
latest=$(printf '%s\n' "$tags" | sed 's/^v//' | grep -E '^[0-9]+\.[0-9]+\.[0-9]+$' | sort -V | tail -1)
if [[ -z "$latest" ]]; then
    echo "Tuist version check: pinned $pinned, couldn't read Tuist's releases"
    exit 0
fi

newest=$(printf '%s\n%s\n' "$pinned" "$latest" | sort -V | tail -1)
if [[ "$latest" == "$pinned" || "$newest" == "$pinned" ]]; then
    echo "Tuist version check: pinned $pinned is the latest stable Tuist"
elif [[ "${latest%%.*}" != "${pinned%%.*}" ]]; then
    echo "Tuist version check: pinned $pinned, Tuist $latest is out, a new major version: ask Yousef before bumping"
else
    echo "Tuist version check: pinned $pinned, Tuist $latest is out: open a pull request that bumps the pin"
fi
exit 0
