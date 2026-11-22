#!/usr/bin/env bash
#
#  merge-batch.sh
#  Waypoint
#
#  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
#  Copyright © 2026 Yousef Mohamed. MIT License.
#
# Builds a merge batch (#295): the latest `main` with each branch merged in, in the order given,
# checked out detached in this clone, so one `scripts/test-mac.sh full` run covers every pull
# request in it. Nothing is pushed. It prints the batch's commit and tree; after the batch's pull
# requests merge, `main`'s tree must equal that tree (TESTING.md, Merge batches).
#
# It stops on the first branch that doesn't merge cleanly, names it, and puts the clone back on
# the commit it was on. It refuses to start when the clone has changes.
#
# Usage: scripts/merge-batch.sh <branch> [<branch>...]
#   WAYPOINT_REMOTE  the remote to fetch from (default origin)

set -euo pipefail

cd "$(dirname "$0")/.."

if [[ $# -eq 0 ]]; then
    sed -n 's/^# \{0,1\}//; /^Usage:/,/^$/p' "$0" >&2
    exit 2
fi
REMOTE="${WAYPOINT_REMOTE:-origin}"

if [[ -n "$(git status --porcelain)" ]]; then
    echo "error: the clone has changes; merge-batch never touches them" >&2
    exit 1
fi

START=$(git symbolic-ref -q --short HEAD || git rev-parse HEAD)
git fetch -q "$REMOTE" main "$@"
git checkout -q --detach "$REMOTE/main"
MAIN=$(git rev-parse --short HEAD)

for branch in "$@"; do
    if ! git -c user.name="Merge batch" -c user.email="merge-batch@localhost" \
        merge -q --no-ff --no-edit "$REMOTE/$branch" >/dev/null 2>&1; then
        git merge --abort 2>/dev/null || true
        git checkout -q "$START"
        echo "error: $branch doesn't merge cleanly into the batch; nothing else was merged" >&2
        exit 1
    fi
done

echo "batch $(git rev-parse --short HEAD) tree $(git rev-parse HEAD^{tree}) main $MAIN branches $*"
