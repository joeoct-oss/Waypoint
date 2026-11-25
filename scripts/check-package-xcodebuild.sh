#!/usr/bin/env bash
#
#  check-package-xcodebuild.sh
#  Waypoint
#
#  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
#  Copyright © 2026 Yousef Mohamed. MIT License.
#
# Checks scripts/package-xcodebuild.sh (planning #429) with a stand-in xcodebuild, so it runs on Linux and
# on the Mac without Xcode:
#
# - xcodebuild runs with Tuist's package project (`Waypoint.xcodeproj` and `Derived/`) moved aside;
# - the project is back after a pass, a failure and a stop with TERM, and `--restore` puts back
#   what a stopped run left aside;
# - a committed `Waypoint.xcodeproj` is never moved, and xcodebuild doesn't run;
# - xcodebuild gets `-skipMacroValidation`, so Understudy's untrusted macros build (planning #506).
#
# Each case runs in a copy of the working tree with its own history, so the clone is never touched.
#
# Usage: scripts/check-package-xcodebuild.sh

set -euo pipefail

cd "$(dirname "$0")/.."

WORK=$(mktemp -d)
cleanup() {
    rm -rf "$WORK"
}
trap cleanup EXIT

STUBS="$WORK/bin"
mkdir -p "$STUBS"
# The stand-in notes whether Tuist's project was in the package root while it ran.
cat >"$STUBS/xcodebuild" <<'STUB'
#!/usr/bin/env bash
if [[ -e Waypoint.xcodeproj || -e Derived ]]; then
    echo "project present" >>"$STUB_CALLS"
else
    echo "project aside" >>"$STUB_CALLS"
fi
printf '%s\n' "$@" >>"$STUB_CALLS.args"
sleep "${STUB_SECONDS:-0}"
exit "${STUB_STATUS:-0}"
STUB
chmod +x "$STUBS/xcodebuild"
CALLS="$WORK/calls"

TREE="$WORK/tree"
mkdir -p "$TREE"
git ls-files -z --cached --others --exclude-standard |
    while IFS= read -r -d '' file; do
        if [[ -e "$file" ]]; then
            printf '%s\0' "$file"
        fi
    done |
    tar --null -T - -cf - | tar -xf - -C "$TREE"
git -C "$TREE" init -q
git -C "$TREE" add -A
git -C "$TREE" -c user.name=check -c user.email=check@example.invalid commit -q -m base

FAILURES=0
fail() {
    echo "FAIL: $1" >&2
    FAILURES=$((FAILURES + 1))
}
pass() {
    echo "ok: $1"
}

# Tuist's generated project, as Tuist leaves it after generating the example app.
generate() {
    mkdir -p "$TREE/Waypoint.xcodeproj" "$TREE/Derived/InfoPlists"
    echo project >"$TREE/Waypoint.xcodeproj/project.pbxproj"
}
project_back() {
    [[ -f "$TREE/Waypoint.xcodeproj/project.pbxproj" && -d "$TREE/Derived/InfoPlists" ]] &&
        [[ ! -e "$TREE/.build/tuist-package-project/Waypoint.xcodeproj" ]]
}
helper() {
    (cd "$TREE" && env PATH="$STUBS:$PATH" STUB_CALLS="$CALLS" "$@")
}

# 1. A pass: xcodebuild runs with the project aside, and it comes back.
generate
: >"$CALLS"
if helper scripts/package-xcodebuild.sh test -scheme Waypoint-Package >/dev/null 2>&1 &&
    grep -qx "project aside" "$CALLS" && project_back; then
    pass "xcodebuild runs with Tuist's project aside, and it comes back after a pass"
else
    fail "xcodebuild runs with Tuist's project aside, and it comes back after a pass"
fi

# 2. A failure keeps xcodebuild's status and puts the project back.
status=0
helper STUB_STATUS=65 scripts/package-xcodebuild.sh test >/dev/null 2>&1 || status=$?
if [[ $status -eq 65 ]] && project_back; then
    pass "a failing xcodebuild keeps its status, and the project comes back"
else
    fail "a failing xcodebuild keeps its status, and the project comes back (status $status)"
fi

# 3. A stop with TERM during xcodebuild puts the project back. As `scripts/test-mac.sh` stops a
# step, the TERM goes to the step's whole process group.
set -m
helper STUB_SECONDS=30 scripts/package-xcodebuild.sh test >/dev/null 2>&1 &
running=$!
set +m
for _ in $(seq 1 50); do
    [[ -e "$TREE/.build/tuist-package-project/Waypoint.xcodeproj" ]] && break
    sleep 0.1
done
kill -TERM -- "-$running" 2>/dev/null || true
wait "$running" 2>/dev/null || true
for _ in $(seq 1 50); do
    project_back && break
    sleep 0.1
done
if project_back; then
    pass "a stop with TERM puts the project back"
else
    fail "a stop with TERM puts the project back"
fi

# 4. --restore puts back what a stopped run left aside, and touches nothing else.
mkdir -p "$TREE/.build/tuist-package-project"
mv "$TREE/Waypoint.xcodeproj" "$TREE/Derived" "$TREE/.build/tuist-package-project/"
if helper scripts/package-xcodebuild.sh --restore && project_back; then
    pass "--restore puts back what a stopped run left aside"
else
    fail "--restore puts back what a stopped run left aside"
fi

# 5. A committed Waypoint.xcodeproj is never moved, and xcodebuild doesn't run.
git -C "$TREE" add -f Waypoint.xcodeproj
: >"$CALLS"
if ! helper scripts/package-xcodebuild.sh test >/dev/null 2>&1 && [[ ! -s "$CALLS" ]] &&
    [[ -f "$TREE/Waypoint.xcodeproj/project.pbxproj" ]]; then
    pass "a committed Waypoint.xcodeproj is never moved"
else
    fail "a committed Waypoint.xcodeproj is never moved"
fi

# 6. xcodebuild gets -skipMacroValidation beside the arguments given.
git -C "$TREE" rm -q --cached Waypoint.xcodeproj/project.pbxproj
: >"$CALLS.args"
if helper scripts/package-xcodebuild.sh test -scheme Waypoint-Package >/dev/null 2>&1 &&
    grep -qx -- "-skipMacroValidation" "$CALLS.args" && grep -qx -- "Waypoint-Package" "$CALLS.args"; then
    pass "xcodebuild gets -skipMacroValidation beside the arguments given"
else
    fail "xcodebuild gets -skipMacroValidation beside the arguments given"
fi

if [[ $FAILURES -gt 0 ]]; then
    echo "$FAILURES package xcodebuild checks failed." >&2
    exit 1
fi
echo "All package xcodebuild checks passed."
