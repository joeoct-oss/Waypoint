#!/usr/bin/env bash
#
#  merge-batch.sh
#  Waypoint
#
#  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
#  Copyright © 2026 Yousef Mohamed. MIT License.
#
# Builds a merge batch (planning #421): the latest `main` with each branch merged in, in the order given,
# checked out detached in this clone, so one `scripts/test-mac.sh full` run covers every pull
# request in it. A batch of one branch that already contains `main` is the branch's own head. Nothing is pushed. It prints the batch's commit and tree; after the batch's pull
# requests merge, `main`'s tree must equal that tree (TESTING.md, Merge batches).
#
# It stops on the first branch that doesn't merge cleanly, names it, and puts the clone back on
# the commit it was on. It refuses to start when the clone has changes.
#
# Before each of the batch's pull requests merges, `--before-merge` checks that nothing moved: the
# branch's head is still the tested one, and `main` is still the batch's `main` (the first pull
# request) or the commit the pull request before it merged as. It exits 1 when either moved, and
# the batch stops there. After the last one merges, `--after-merge` checks that `main` holds the
# batch's tested tree, and exits 1 when it doesn't. Neither changes anything in the clone.
#
# Usage: scripts/merge-batch.sh <branch> [<branch>...]
#        scripts/merge-batch.sh --before-merge <branch> <tested head> <expected main>
#        scripts/merge-batch.sh --after-merge <batch tree>
#   WAYPOINT_REMOTE    the remote to fetch from (default origin)
#   WAYPOINT_RUN_LOCK  the Mac test run lock (default /tmp/waypoint-test-mac.lock)

set -euo pipefail

cd "$(dirname "$0")/.."

if [[ $# -eq 0 ]]; then
    sed -n 's/^# \{0,1\}//; /^Usage:/,/^$/p' "$0" >&2
    exit 2
fi
REMOTE="${WAYPOINT_REMOTE:-origin}"

if [[ "$1" == --after-merge ]]; then
    if [[ $# -ne 2 ]]; then
        sed -n 's/^# \{0,1\}//; /^Usage:/,/^$/p' "$0" >&2
        exit 2
    fi
    git fetch -q "$REMOTE" main
    tree=$(git rev-parse "$REMOTE/main^{tree}")
    if [[ "$tree" != "$2" ]]; then
        echo "error: main's tree is ${tree:0:12}, not the tested ${2:0:12}; main holds untested code" >&2
        exit 1
    fi
    echo "ok: main holds the batch's tested tree"
    exit 0
fi

if [[ "$1" == --before-merge ]]; then
    if [[ $# -ne 4 ]]; then
        sed -n 's/^# \{0,1\}//; /^Usage:/,/^$/p' "$0" >&2
        exit 2
    fi
    branch="$2" tested="$3" expected_main="$4"
    git fetch -q "$REMOTE" main "$branch"
    head=$(git rev-parse "$REMOTE/$branch")
    main=$(git rev-parse "$REMOTE/main")
    if [[ "$head" != "$(git rev-parse "$tested")" ]]; then
        echo "error: $branch moved to ${head:0:7} since the batch tested ${tested:0:7}; stop the batch" >&2
        exit 1
    fi
    if [[ "$main" != "$(git rev-parse "$expected_main")" ]]; then
        echo "error: main moved to ${main:0:7}, not ${expected_main:0:7}; stop the batch" >&2
        exit 1
    fi
    echo "ok: $branch is still ${head:0:7} and main is still ${main:0:7}; merge it"
    exit 0
fi

# A Mac test run uses this clone while it holds the run lock (scripts/test-mac.sh); a batch
# built under it would change the commit the run tests.
RUN_LOCK="${WAYPOINT_RUN_LOCK:-/tmp/waypoint-test-mac.lock}"
holder=$(readlink "$RUN_LOCK" 2>/dev/null || true)
if [[ -n "$holder" ]] && ps -p "$holder" -o command= 2>/dev/null | grep -q "test-mac.sh"; then
    echo "error: a Mac test run (pid $holder) holds the run lock; build the batch after its teardown" >&2
    exit 1
fi

if [[ -n "$(git status --porcelain)" ]]; then
    echo "error: the clone has changes; merge-batch never touches them" >&2
    exit 1
fi

START=$(git symbolic-ref -q --short HEAD || git rev-parse HEAD)
git fetch -q "$REMOTE" main "$@"
git checkout -q --detach "$REMOTE/main"
MAIN=$(git rev-parse --short HEAD)

# A batch of one branch that already contains `main` is that branch's own head, not a merge
# commit on top of it: the run then tests, and reports to Tuist, a commit GitHub has, so the
# commit links in Tuist's run report on the pull request open.
if [[ $# -eq 1 ]] && git merge-base --is-ancestor "$REMOTE/main" "$REMOTE/$1"; then
    git checkout -q --detach "$REMOTE/$1"
else
    for branch in "$@"; do
        if ! git -c user.name="Merge batch" -c user.email="merge-batch@localhost" \
            merge -q --no-ff --no-edit "$REMOTE/$branch" >/dev/null 2>&1; then
            git merge --abort 2>/dev/null || true
            git checkout -q "$START"
            echo "error: $branch doesn't merge cleanly into the batch; nothing else was merged" >&2
            exit 1
        fi
    done
fi

heads=()
for branch in "$@"; do
    heads+=("$branch@$(git rev-parse --short "$REMOTE/$branch")")
done
echo "batch $(git rev-parse --short HEAD) tree $(git rev-parse HEAD^{tree}) main $MAIN branches ${heads[*]}"
