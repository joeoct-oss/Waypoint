#!/usr/bin/env bash
#
#  check-merge-batch.sh
#  Waypoint
#
#  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
#  Copyright © 2026 Yousef Mohamed. MIT License.
#
# Checks scripts/merge-batch.sh and scripts/slowest-tests.py (#295) in a temporary repository, so
# it runs on Linux and on the Mac without touching this clone:
#
# - two branches that merge cleanly make a batch with both and `main`;
# - squash-merging the batch's branches one at a time, in its order, gives the batch's tree;
# - a branch that conflicts stops the batch, names the branch, and leaves the clone as it was;
# - a clone with changes is refused;
# - the slowest-test list reads a sample `xcresulttool` answer, slowest first, and a bad one is
#   only a note.
#
# Usage: scripts/check-merge-batch.sh

set -euo pipefail

cd "$(dirname "$0")/.."
SCRIPTS="$(pwd)/scripts"

WORK=$(mktemp -d)
cleanup() {
    rm -rf "$WORK"
}
trap cleanup EXIT

FAILURES=0
fail() {
    echo "FAIL: $1" >&2
    FAILURES=$((FAILURES + 1))
}
pass() {
    echo "ok: $1"
}

export GIT_AUTHOR_NAME="Check" GIT_AUTHOR_EMAIL="check@localhost"
export GIT_COMMITTER_NAME="Check" GIT_COMMITTER_EMAIL="check@localhost"

# A remote with `main` and three branches: `one` and `two` change different files, `clash`
# changes the same line as `one`.
git init -q --bare "$WORK/remote.git"
git clone -q "$WORK/remote.git" "$WORK/seed" 2>/dev/null
(
    cd "$WORK/seed"
    git checkout -q -b main
    printf 'a\n' >a.txt
    printf 'b\n' >b.txt
    git add . && git commit -q -m base
    git push -q origin main
    git checkout -q -b one && printf 'a one\n' >a.txt && git commit -qam one && git push -q origin one
    git checkout -q main
    git checkout -q -b two && printf 'b two\n' >b.txt && git commit -qam two && git push -q origin two
    git checkout -q main
    git checkout -q -b clash && printf 'a clash\n' >a.txt && git commit -qam clash && git push -q origin clash
)

# The clone under test carries the scripts, as the Mac clone does.
git clone -q "$WORK/remote.git" "$WORK/clone"
mkdir -p "$WORK/clone/scripts"
cp "$SCRIPTS/merge-batch.sh" "$WORK/clone/scripts/"
printf 'scripts/\n' >>"$WORK/clone/.git/info/exclude"
cd "$WORK/clone"
git checkout -q main

# 1. A clean batch.
if out=$(scripts/merge-batch.sh one two 2>&1); then
    tree=$(sed -n 's/.* tree \([0-9a-f]*\) .*/\1/p' <<<"$out")
    if [[ "$(cat a.txt b.txt)" == $'a one\nb two' && "$tree" == "$(git rev-parse HEAD^{tree})" ]]; then
        pass "two clean branches make a batch with both, and it prints the batch's tree"
    else
        fail "two clean branches make a batch with both ($out)"
    fi
else
    fail "two clean branches make a batch ($out)"
fi
git checkout -q main

# 2. Squash-merging in the batch's order gives the batch's tree.
git checkout -q -b squashed origin/main
for branch in one two; do
    git merge -q --squash "origin/$branch" >/dev/null && git commit -q -m "squash $branch"
done
if [[ -n "${tree:-}" && "$(git rev-parse HEAD^{tree})" == "$tree" ]]; then
    pass "squash-merging the batch's branches in order gives the batch's tree"
else
    fail "squash-merging the batch's branches in order gives the batch's tree"
fi
git checkout -q main

# 3. A conflicting branch stops the batch and leaves the clone as it was.
before=$(git rev-parse HEAD)
if out=$(scripts/merge-batch.sh one clash 2>&1); then
    fail "a conflicting branch stops the batch"
elif [[ "$out" == *"clash doesn't merge cleanly"* && "$(git rev-parse HEAD)" == "$before" &&
    "$(git symbolic-ref -q --short HEAD)" == main && -z "$(git status --porcelain)" ]]; then
    pass "a conflicting branch stops the batch, is named, and the clone is as it was"
else
    fail "a conflicting branch leaves the clone as it was ($out)"
fi

# 4. A clone with changes is refused.
printf 'local\n' >>a.txt
if out=$(scripts/merge-batch.sh one 2>&1); then
    fail "a clone with changes is refused"
elif [[ "$out" == *"the clone has changes"* && "$(cat a.txt)" == $'a\nlocal' ]]; then
    pass "a clone with changes is refused and its changes are kept"
else
    fail "a clone with changes is refused ($out)"
fi
git checkout -q -- a.txt

# 5. The slowest-test list.
sample='{"testNodes":[{"name":"WaypointExample","nodeType":"Test Plan","children":[
  {"name":"WaypointExampleUITests","nodeType":"UI test bundle","children":[
    {"name":"StackTests","nodeType":"Test Suite","children":[
      {"name":"testPushAndBack()","nodeType":"Test Case","durationInSeconds":4.5},
      {"name":"testLinkMidTransition()","nodeType":"Test Case","duration":"12s"}]},
    {"name":"LabTests","nodeType":"Test Suite","children":[
      {"name":"testTabsChangeAtRunTime()","nodeType":"Test Case","durationInSeconds":8.25}]}]}]}]}'
out=$("$SCRIPTS/slowest-tests.py" 2 <<<"$sample")
expected=$'Slowest 2 of 3 tests:\n    12.0s  StackTests/testLinkMidTransition()\n     8.2s  LabTests/testTabsChangeAtRunTime()'
if [[ "$out" == "$expected" ]]; then
    pass "the slowest-test list reads xcresulttool's answer, slowest first"
else
    fail "the slowest-test list reads xcresulttool's answer ($out)"
fi
if out=$("$SCRIPTS/slowest-tests.py" <<<"not json") && [[ "$out" == note:* ]]; then
    pass "an answer it can't read is only a note"
else
    fail "an answer it can't read is only a note ($out)"
fi

if [[ $FAILURES -gt 0 ]]; then
    echo "$FAILURES merge batch check(s) failed" >&2
    exit 1
fi
echo "All merge batch checks passed."
