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
# comment-only review leaves it standing. A repeated approval of a head whose Apple tests are
# running or passed starts nothing, so it doesn't cancel or repeat them, and neither does a label
# left on the pull request; only adding the label (--label-added, from the Apple tests workflow's
# labeled event) starts another run. Prints the reason, and writes ready=true or ready=false
# to $GITHUB_OUTPUT when that is set. Reads GitHub with gh, so it needs GH_TOKEN.
#
# Usage: scripts/apple-tests-ready.sh <owner/repo> <pull request number> <head commit> [--label-added]

set -euo pipefail

if [[ $# -lt 3 || $# -gt 4 || ( $# -eq 4 && "$4" != "--label-added" ) ]]; then
    echo "usage: scripts/apple-tests-ready.sh <owner/repo> <pull request number> <head commit> [--label-added]" >&2
    exit 2
fi
repo="$1"
number="$2"
head="$3"
label=run-apple-checks
label_added=false
if [[ $# -eq 4 ]]; then
    label_added=true
fi
linux_gate="Linux checks / Linux build and tests"

answer() {
    echo "$2"
    if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
        echo "ready=$1" >>"$GITHUB_OUTPUT"
    fi
    exit 0
}

# A late event for an older commit starts nothing, so it can't cancel the current head's tests.
current=$(gh api "repos/$repo/pulls/$number" --jq '.head.sha')
if [[ "$current" != "$head" ]]; then
    answer false "Not the head: the pull request's head is now $current, not $head."
fi

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

# Read first, so a failed call stops the script instead of reading as no label.
labels=$(gh api --paginate "repos/$repo/issues/$number/labels" --jq '.[].name')
if [[ -n "$approved" ]]; then
    why="$approved approved $head"
elif grep -qx "$label" <<<"$labels"; then
    why="the pull request has the $label label"
else
    answer false "Not yet: $head has no approval and no $label label."
fi

# Adding the label always starts another run.
if [[ "$label_added" == "true" ]]; then
    answer true "Ready: the Linux gate passed and the $label label was just added."
fi

# The Apple test jobs of the head: one still going, or a gate that passed, means they ran.
apple=$(gh api --paginate -X GET "repos/$repo/commits/$head/check-runs" -f filter=latest \
    --jq '.check_runs[] | select(.name | startswith("Apple platform checks / "))
        | [.name, .status, .conclusion // ""] | @tsv')
if awk -F'\t' 'NF >= 2 && $2 != "completed" { found = 1 } END { exit !found }' <<<"$apple"; then
    answer false "Already running: the Apple tests of $head are still going, so this starts nothing."
fi
if awk -F'\t' '$1 == "Apple platform checks / Apple builds and tests" && $3 == "success" { found = 1 }
    END { exit !found }' <<<"$apple"; then
    answer false "Already passed: the Apple tests of $head passed, so this starts nothing."
fi
answer true "Ready: the Linux gate passed and $why."
