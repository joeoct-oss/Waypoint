#!/usr/bin/env bash
#
#  find-ci-simulator.sh
#  Waypoint
#
#  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
#  Copyright © 2026 Yousef Mohamed. MIT License.
#
# Prints the UDID of an available simulator on a CI runner: the device named `name` on the iOS
# runtime `os` (default: the newest iOS runtime the runner has). Runners come with their own
# simulators, so CI picks one by name instead of using the Mac's pool. It fails when there is
# none, naming what the runner has.
#
# Usage: scripts/find-ci-simulator.sh <name> [os]
#   for example scripts/find-ci-simulator.sh "iPhone 17" 27.2

set -euo pipefail

if [[ $# -lt 1 || $# -gt 2 ]]; then
    echo "usage: scripts/find-ci-simulator.sh <name> [os]" >&2
    exit 2
fi

xcrun simctl list devices available --json | /usr/bin/python3 -c '
import json, re, sys
name, wanted = sys.argv[1], (sys.argv[2] if len(sys.argv) > 2 else "")
runtimes = json.load(sys.stdin)["devices"]
# A key is like com.apple.CoreSimulator.SimRuntime.iOS-27-2; some runners add a suffix after the
# version (iOS-27-2-iPhone19...), so only the leading numbers count, and a plain key comes before
# a suffixed one of the same version.
VERSION = re.compile(r"\.iOS-([0-9]+(?:-[0-9]+)*)(.*)$")
def version(key):
    return [int(n) for n in VERSION.search(key).group(1).split("-")]
def order(key):
    return (version(key), VERSION.search(key).group(2) == "")
ios = sorted((key for key in runtimes if VERSION.search(key)), key=order, reverse=True)
# With no OS named, only the newest version counts, so a device missing there never falls back to
# an older iOS.
if wanted:
    ios = [key for key in ios if ".".join(map(str, version(key))) == wanted]
elif ios:
    ios = [key for key in ios if version(key) == version(ios[0])]
for key in ios:
    for device in runtimes[key]:
        if device["name"] == name:
            print(device["udid"])
            sys.exit(0)
print("error: no available %s simulator on iOS %s; the runner has:" % (name, wanted or "(newest)"),
      file=sys.stderr)
for key in sorted(runtimes):
    for device in runtimes[key]:
        print("  %s: %s" % (key, device["name"]), file=sys.stderr)
sys.exit(1)
' "$@"
