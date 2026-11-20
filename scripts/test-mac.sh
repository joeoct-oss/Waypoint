#!/usr/bin/env bash
#
#  test-mac.sh
#  Waypoint
#
#  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
#  Copyright © 2026 Yousef Mohamed. MIT License.
#
# Runs every test layer on a Mac: the concurrency guard rail and compile fixtures,
# a host build with warnings as errors, the package unit tests on the host, the
# unified log tests under the thread sanitizer, an iOS build with warnings as
# errors, then all unit test targets on the project simulator (including
# UIKit-only tests), then the example app's UI tests in a project generated with
# Tuist, and the system link and missing destination tests once more in the
# release configuration.
#
# Usage: scripts/test-mac.sh
# Environment: WAYPOINT_SIMULATOR overrides the simulator name (default waypoint-01).

set -euo pipefail

cd "$(dirname "$0")/.."

SIMULATOR_NAME="${WAYPOINT_SIMULATOR:-waypoint-01}"

# Prints the UDID of the named simulator, creating it on the newest iOS runtime
# with the newest iPhone device type when it does not exist yet.
simulator_udid() {
    local udid
    udid=$(xcrun simctl list devices available -j |
        /usr/bin/python3 -c 'import json,sys; name=sys.argv[1]; d=json.load(sys.stdin)["devices"]; print(next((x["udid"] for r in d.values() for x in r if x["name"]==name), ""))' "$SIMULATOR_NAME")
    if [[ -n "$udid" ]]; then
        echo "$udid"
        return
    fi
    local runtime device_type
    runtime=$(xcrun simctl list runtimes available -j |
        /usr/bin/python3 -c 'import json,sys; r=[x for x in json.load(sys.stdin)["runtimes"] if x["platform"]=="iOS"]; r.sort(key=lambda x: [int(p) for p in x["version"].split(".")]); print(r[-1]["identifier"] if r else "")')
    if [[ -z "$runtime" ]]; then
        echo "error: no iOS simulator runtime installed (Xcode > Settings > Components)" >&2
        exit 1
    fi
    device_type=$(xcrun simctl list runtimes available -j |
        /usr/bin/python3 -c '
import json, re, sys
rid = sys.argv[1]
runtime = next(x for x in json.load(sys.stdin)["runtimes"] if x["identifier"] == rid)
phones = [x for x in runtime.get("supportedDeviceTypes", []) if x.get("productFamily") == "iPhone"]
def rank(t):
    m = re.search(r"iPhone (\d+)", t["name"])
    return (int(m.group(1)) if m else 0, "Pro" in t["name"], "Max" not in t["name"])
print(max(phones, key=rank)["identifier"] if phones else "")' "$runtime")
    echo "Creating simulator $SIMULATOR_NAME ($device_type, $runtime)" >&2
    xcrun simctl create "$SIMULATOR_NAME" "$device_type" "$runtime"
}

echo "==> Checking the concurrency guard rail"
scripts/check-concurrency.sh

echo "==> Checking compile fixtures"
scripts/check-compile-failures.sh

echo "==> swift build --build-tests with warnings as errors (macOS host)"
swift build --build-tests -Xswiftc -warnings-as-errors --scratch-path .build/warnings-as-errors

echo "==> swift test (macOS host)"
swift test

echo "==> swift test WaypointOSLogTests under the thread sanitizer (macOS host)"
swift test --sanitize=thread --scratch-path .build/thread-sanitizer --filter WaypointOSLogTests

UDID=$(simulator_udid)
DESTINATION="platform=iOS Simulator,id=$UDID"

echo "==> xcodebuild build Waypoint-Package for iOS with warnings as errors"
xcodebuild build -quiet -scheme Waypoint-Package -destination generic/platform=iOS \
    SWIFT_TREAT_WARNINGS_AS_ERRORS=YES

echo "==> xcodebuild test Waypoint-Package on $SIMULATOR_NAME"
xcodebuild test -quiet -scheme Waypoint-Package -destination "$DESTINATION"

# Runs Tuist through mise when mise pins it, and the installed Tuist otherwise.
tuist_cmd() {
    if command -v mise >/dev/null && [[ -f .mise.toml ]]; then
        mise exec -- tuist "$@"
    else
        tuist "$@"
    fi
}

echo "==> tuist generate example app"
tuist_cmd generate --path Example --no-open

echo "==> xcodebuild test example app on $SIMULATOR_NAME"
xcodebuild test -quiet \
    -workspace Example/WaypointExample.xcworkspace \
    -scheme WaypointExample \
    -destination "$DESTINATION"

# A system link (#147) and a route with no destination in its stack (#166) must be reported in
# release builds too, so their UI tests run again with the app and the tests built in the release
# configuration.
echo "==> xcodebuild test release reports (Release) on $SIMULATOR_NAME"
xcodebuild test -quiet \
    -workspace Example/WaypointExample.xcworkspace \
    -scheme WaypointExample \
    -configuration Release \
    -destination "$DESTINATION" \
    -only-testing:WaypointExampleUITests/SystemLinkTests \
    -only-testing:WaypointExampleUITests/MissingDestinationTests

echo "All Mac tests passed."
