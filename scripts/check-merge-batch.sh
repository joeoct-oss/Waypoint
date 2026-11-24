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
# - squash-merging the batch's branches one at a time, in its order, gives the batch's tree, and
#   so does merging them with merge commits (`--no-ff`); `--after-merge` passes after either and
#   tells that tree from another;
# - `--before-merge` stops the batch when a branch or `main` moved;
# - a branch that conflicts stops the batch, names the branch, and leaves the clone as it was;
# - a clone with changes, or one a Mac test run holds the run lock for, is refused;
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

# Its own run lock path, so a real Mac run's lock never changes what the check sees.
export WAYPOINT_RUN_LOCK="$WORK/run.lock"
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
    git push -q origin main 2>/dev/null
    git checkout -q -b one && printf 'a one\n' >a.txt && git commit -qam one && git push -q origin one 2>/dev/null
    git checkout -q main
    git checkout -q -b two && printf 'b two\n' >b.txt && git commit -qam two && git push -q origin two 2>/dev/null
    git checkout -q main
    git checkout -q -b clash && printf 'a clash\n' >a.txt && git commit -qam clash && git push -q origin clash 2>/dev/null
)

# The clone under test carries the scripts, as the Mac clone does.
git clone -q "$WORK/remote.git" "$WORK/clone" 2>/dev/null
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
    if ! { git merge -q --squash "origin/$branch" >/dev/null 2>&1 &&
        git commit -q -m "squash $branch"; }; then
        fail "squash-merging $branch"
        git reset -q --hard
        break
    fi
done
if [[ -n "${tree:-}" && "$(git rev-parse HEAD^{tree})" == "$tree" ]]; then
    pass "squash-merging the batch's branches in order gives the batch's tree"
else
    fail "squash-merging the batch's branches in order gives the batch's tree"
fi
git checkout -q main

# 2-merge. Merging in the batch's order with merge commits gives the batch's tree too.
git checkout -q -b merged origin/main
for branch in one two; do
    if ! git merge -q --no-ff -m "merge $branch" "origin/$branch" >/dev/null 2>&1; then
        fail "merging $branch with a merge commit"
        git merge --abort 2>/dev/null || git reset -q --hard
        break
    fi
done
if [[ -n "${tree:-}" && "$(git rev-parse HEAD^{tree})" == "$tree" ]]; then
    pass "merging the batch's branches in order with merge commits gives the batch's tree"
else
    fail "merging the batch's branches in order with merge commits gives the batch's tree"
fi
git checkout -q main

# 2a. --after-merge: main with the squashed branches holds the tested tree; main without them
# doesn't.
(cd "$WORK/seed" && git checkout -q main && git fetch -q origin &&
    for branch in one two; do git merge -q --squash "origin/$branch" >/dev/null 2>&1 &&
        git commit -q -m "squash $branch"; done && git push -q origin main 2>/dev/null)
if scripts/merge-batch.sh --after-merge "$tree" >/dev/null 2>&1; then
    pass "--after-merge passes when main holds the tested tree"
else
    fail "--after-merge passes when main holds the tested tree"
fi
(cd "$WORK/seed" && git reset -q --hard HEAD~2 && git push -q -f origin main 2>/dev/null)
if out=$(scripts/merge-batch.sh --after-merge "$tree" 2>&1); then
    fail "--after-merge fails when main doesn't hold the tested tree"
elif [[ "$out" == *"main holds untested code"* ]]; then
    pass "--after-merge fails when main doesn't hold the tested tree"
else
    fail "--after-merge says main holds untested code ($out)"
fi
git fetch -q origin
git checkout -q main
git reset -q --hard origin/main

# 2a-merge. --after-merge also passes when main took the branches as merge commits.
(cd "$WORK/seed" && git checkout -q main && git fetch -q origin &&
    for branch in one two; do git merge -q --no-ff -m "merge $branch" "origin/$branch" >/dev/null 2>&1;
    done && git push -q origin main 2>/dev/null)
if scripts/merge-batch.sh --after-merge "$tree" >/dev/null 2>&1; then
    pass "--after-merge passes when main took the batch as merge commits"
else
    fail "--after-merge passes when main took the batch as merge commits"
fi
(cd "$WORK/seed" && git reset -q --hard HEAD~2 && git push -q -f origin main 2>/dev/null)
git fetch -q origin
git checkout -q main
git reset -q --hard origin/main

# 2b. --before-merge lets the merge go when nothing moved, and stops the batch when the branch
# or main moved.
one_head=$(git rev-parse origin/one)
main_head=$(git rev-parse origin/main)
if scripts/merge-batch.sh --before-merge one "$one_head" "$main_head" >/dev/null 2>&1; then
    pass "--before-merge lets the merge go when nothing moved"
else
    fail "--before-merge lets the merge go when nothing moved"
fi
(cd "$WORK/seed" && git checkout -q one && printf 'late\n' >late.txt && git add late.txt &&
    git commit -q -m late && git push -q origin one 2>/dev/null)
if out=$(scripts/merge-batch.sh --before-merge one "$one_head" "$main_head" 2>&1); then
    fail "--before-merge stops the batch when the branch moved"
elif [[ "$out" == *"one moved"* ]]; then
    pass "--before-merge stops the batch when the branch moved"
else
    fail "--before-merge names the moved branch ($out)"
fi
(cd "$WORK/seed" && git checkout -q main && printf 'main moved\n' >m.txt && git add m.txt &&
    git commit -q -m moved && git push -q origin main 2>/dev/null)
two_head=$(git rev-parse origin/two)
if out=$(scripts/merge-batch.sh --before-merge two "$two_head" "$main_head" 2>&1); then
    fail "--before-merge stops the batch when main moved"
elif [[ "$out" == *"main moved"* ]]; then
    pass "--before-merge stops the batch when main moved"
else
    fail "--before-merge names the moved main ($out)"
fi
git fetch -q origin

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

# 3b. A batch is refused while a Mac test run holds the run lock.
cat >"$WORK/test-mac.sh" <<'EOF'
#!/usr/bin/env bash
sleep 10
EOF
chmod +x "$WORK/test-mac.sh"
"$WORK/test-mac.sh" &
run=$!
ln -s "$run" "$WORK/run.lock"
before=$(git rev-parse HEAD)
if out=$(scripts/merge-batch.sh one 2>&1); then
    fail "a batch is refused while a test run holds the run lock"
elif [[ "$out" == *"holds the run lock"* && "$(git rev-parse HEAD)" == "$before" ]]; then
    pass "a batch is refused while a test run holds the run lock, and the clone is untouched"
else
    fail "a batch is refused while a test run holds the run lock ($out)"
fi
kill "$run" 2>/dev/null || true
wait "$run" 2>/dev/null || true
rm -f "$WORK/run.lock"

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
