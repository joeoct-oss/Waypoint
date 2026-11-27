#!/usr/bin/env bash
#
#  apple-tests-ready.sh
#  Waypoint
#
#  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
#  Copyright © 2026 Yousef Mohamed. MIT License.
#
# Decides whether a pull request's Apple tests may start: the Linux gate passed on its head commit,
# and the head commit is approved or the pull request has the run-apple-checks label. Both the
# checks workflow (once the Linux gate passed) and the Apple tests workflow (on an approval or the
# label) ask it, so whichever of the two arrives last starts the tests. An approval counts while
# it is its reviewer's latest decision on the head commit: a push dismisses it, and a later
# comment-only review leaves it standing. Prints the reason, and writes ready=true or ready=false
# to $GITHUB_OUTPUT when that is set. Reads GitHub with gh, so it needs GH_TOKEN.
#
# Usage: scripts/apple-tests-ready.sh <owner/repo> <pull request number> <head commit>

set -euo pipefail

if [[ $# -ne 3 ]]; then
    echo "usage: scripts/apple-tests-ready.sh <owner/repo> <pull request number> <head commit>" >&2
    exit 2
fi
repo="$1"
number="$2"
head="$3"
label=run-apple-checks
linux_gate="Linux checks / Linux build and tests"

answer() {
    echo "$2"
    if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
        echo "ready=$1" >>"$GITHUB_OUTPUT"
    fi
    exit 0
}

linux=$(gh api -X GET "repos/$repo/commits/$head/check-runs" -f check_name="$linux_gate" \
    -f filter=latest --jq '[.check_runs[] | select(.status == "completed")][0].conclusion // ""')
if [[ "$linux" != "success" ]]; then
    answer false "Not yet: \"$linux_gate\" hasn't passed on $head (${linux:-not finished})."
fi

# Each reviewer's latest approval or change request decides; a comment-only review doesn't.
approved=$(gh api --paginate "repos/$repo/pulls/$number/reviews" --jq '.[]
    | select(.state == "APPROVED" or .state == "CHANGES_REQUESTED" or .state == "DISMISSED")
    | [.user.login, .state, .commit_id] | @tsv' |
    awk -F'\t' '{ latest[$1] = $2 "\t" $3 } END { for (user in latest) print user "\t" latest[user] }' |
    awk -F'\t' -v head="$head" '$2 == "APPROVED" && $3 == head { print $1 }' | sort | paste -sd, -)
if [[ -n "$approved" ]]; then
    answer true "Ready: the Linux gate passed and $approved approved $head."
fi

if gh api "repos/$repo/issues/$number/labels" --jq '.[].name' | grep -qx "$label"; then
    answer true "Ready: the Linux gate passed and the pull request has the $label label."
fi

answer false "Not yet: $head has no approval and no $label label."
