#!/bin/zsh
# Runs spike UI tests. Usage: ./run-tests.sh <simulator name> <log file> <-only-testing ...>
set -u
sim=$1
log=$2
shift 2
cd "$(dirname "$0")"
tuist generate --no-open > /dev/null 2>&1
export TEST_RUNNER_SPIKE_SHOTS=/Users/joe0ct/Dev/Waypoint/screenshots/spikes-2
xcodebuild test -project ProposalSpike.xcodeproj -scheme ProposalSpike \
    -destination "platform=iOS Simulator,$sim" -derivedDataPath Derived "$@" > "$log" 2>&1
grep -E "FINDING|error:|Test Case.*(passed|failed)|SPIKE " "$log" | cut -c1-420
