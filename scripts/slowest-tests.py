#!/usr/bin/env python3
#
#  slowest-tests.py
#  Waypoint
#
#  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
#  Copyright © 2026 Yousef Mohamed. MIT License.
#
# Prints the slowest tests of a test run (#295), slowest first, from the JSON that
# `xcrun xcresulttool get test-results tests --path <bundle>` writes, read from standard input.
# It only reports: any input it can't read prints a note and exits 0, so it never fails a run.
#
# Usage: xcrun xcresulttool get test-results tests --path <bundle> | scripts/slowest-tests.py [count]

import json
import re
import sys

DEFAULT_COUNT = 10


def seconds(node):
    """A test case's duration in seconds, from `durationInSeconds` or a `duration` like `1.5s`."""
    value = node.get("durationInSeconds")
    if isinstance(value, (int, float)):
        return float(value)
    match = re.match(r"^\s*([\d.]+)\s*s\s*$", str(node.get("duration", "")))
    return float(match.group(1)) if match else None


def test_cases(nodes, parents=()):
    """Every test case under `nodes`, as (seconds, name), with its class in front of its name."""
    for node in nodes:
        names = parents + (node.get("name", "?"),)
        if node.get("nodeType") == "Test Case":
            duration = seconds(node)
            if duration is not None:
                suite = next((n for n in reversed(parents) if n), "")
                yield duration, f"{suite}/{node.get('name', '?')}" if suite else names[-1]
        else:
            yield from test_cases(node.get("children", []), names)


def main():
    count = int(sys.argv[1]) if len(sys.argv) > 1 else DEFAULT_COUNT
    try:
        data = json.load(sys.stdin)
        cases = sorted(test_cases(data.get("testNodes", [])), reverse=True)
    except (ValueError, AttributeError, TypeError) as error:
        print(f"note: no test times ({error})")
        return
    if not cases:
        print("note: no test times in the result bundle")
        return
    print(f"Slowest {min(count, len(cases))} of {len(cases)} tests:")
    for duration, name in cases[:count]:
        print(f"  {duration:6.1f}s  {name}")


if __name__ == "__main__":
    main()
