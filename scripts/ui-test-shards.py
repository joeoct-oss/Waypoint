#!/usr/bin/env python3
#
#  ui-test-shards.py
#  Waypoint
#
#  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
#  Copyright © 2026 Yousef Mohamed. MIT License.
#
# Splits the example app's UI test classes into shards for CI, so each macOS runner tests a part
# with one simulator. Every class in Example/WaypointExampleUITests that has a `func test...` goes
# to exactly one shard: the classes are taken from the most tests to the fewest, each to the shard
# with the fewest tests so far (the lower shard on a tie), so the split is the same on every runner
# and a new class joins a shard without anyone listing it.
#
# Prints one `-only-testing:WaypointExampleUITests/<Class>` argument per line for xcodebuild.
# `--list` prints every shard with its classes and test counts instead. `--self-check` checks the
# split on a made-up set of classes and exits. It fails when a test sits in a class it can't see,
# so no test is ever left out of every shard.
#
# Usage: scripts/ui-test-shards.py <total> <index from 1>
#        scripts/ui-test-shards.py <total> --list
#        scripts/ui-test-shards.py --self-check

import re
import sys
from pathlib import Path

UI_BUNDLE = "WaypointExampleUITests"
ROOT = Path(__file__).resolve().parent.parent
FOLDER = ROOT / "Example" / UI_BUNDLE
CLASS = re.compile(r"^\s*(?:final\s+)?class\s+([A-Za-z_][A-Za-z0-9_]*)\s*:\s*XCTestCase\b", re.M)
TEST = re.compile(r"^\s*(?:@MainActor\s+)?func\s+(test[A-Za-z0-9_]*)\s*\(", re.M)


def test_classes(folder):
    """Each XCTestCase class with its number of tests, read from the Swift files."""
    classes = {}
    for path in sorted(folder.rglob("*.swift")):
        source = path.read_text(encoding="utf-8")
        matches = list(CLASS.finditer(source))
        for i, match in enumerate(matches):
            end = matches[i + 1].start() if i + 1 < len(matches) else len(source)
            count = len(TEST.findall(source, match.end(), end))
            if count:
                classes[match.group(1)] = classes.get(match.group(1), 0) + count
    return classes


def split(classes, total):
    """The shards, each a list of class names, balanced by test count."""
    shards = [[] for _ in range(total)]
    loads = [0] * total
    for name, count in sorted(classes.items(), key=lambda item: (-item[1], item[0])):
        index = min(range(total), key=lambda i: (loads[i], i))
        shards[index].append(name)
        loads[index] += count
    return shards


def self_check():
    classes = {"A": 11, "B": 8, "C": 7, "D": 4, "E": 3, "F": 3, "G": 2, "H": 1, "I": 1, "J": 1}
    shards = split(classes, 3)
    names = sorted(name for shard in shards for name in shard)
    assert names == sorted(classes), "every class goes to exactly one shard"
    loads = [sum(classes[name] for name in shard) for shard in shards]
    assert max(loads) - min(loads) <= 1, f"shards balanced by test count: {loads}"
    assert split(classes, 3) == shards, "the same split every time"
    assert split({"A": 1}, 3) == [["A"], [], []], "more shards than classes leaves shards empty"
    sample = (
        "final class Foo: XCTestCase {\n    func testOne() {}\n    @MainActor func testTwo() {}\n"
        "    func helper() {}\n}\nprivate final class Bar: NSObject {}\n"
        "class Baz: XCTestCase {\n    func testThree() async throws {}\n}\n"
    )
    found = {}
    matches = list(CLASS.finditer(sample))
    for i, match in enumerate(matches):
        end = matches[i + 1].start() if i + 1 < len(matches) else len(sample)
        found[match.group(1)] = len(TEST.findall(sample, match.end(), end))
    assert found == {"Foo": 2, "Baz": 1}, f"reads the test classes and their tests: {found}"
    print("ok: UI test shards take every class once, balanced and the same every time")


def main(argv):
    if argv == ["--self-check"]:
        self_check()
        return 0
    if len(argv) != 2 or not argv[0].isdigit() or int(argv[0]) < 1:
        print(__doc__ or "usage: scripts/ui-test-shards.py <total> <index>|--list", file=sys.stderr)
        return 2
    total = int(argv[0])
    classes = test_classes(FOLDER)
    if not classes:
        print(f"error: no UI test classes in {FOLDER}", file=sys.stderr)
        return 1
    # A test outside an XCTestCase subclass found here, such as one in a class that subclasses a
    # base test class, would run in no shard, so the split refuses to leave it out.
    every_test = sum(len(TEST.findall(path.read_text(encoding="utf-8"))) for path in FOLDER.rglob("*.swift"))
    if every_test != sum(classes.values()):
        print(
            f"error: {every_test} UI tests in {FOLDER}, but only {sum(classes.values())} sit in a "
            "class that subclasses XCTestCase; the shards would leave the others out",
            file=sys.stderr,
        )
        return 1
    shards = split(classes, total)
    if argv[1] == "--list":
        for number, shard in enumerate(shards, start=1):
            tests = sum(classes[name] for name in shard)
            listed = ", ".join(f"{name} ({classes[name]})" for name in shard)
            print(f"Shard {number}: {tests} tests: {listed}")
        return 0
    if not argv[1].isdigit() or not 1 <= int(argv[1]) <= total:
        print(f"error: the shard index must be 1 to {total}", file=sys.stderr)
        return 2
    for name in shards[int(argv[1]) - 1]:
        print(f"-only-testing:{UI_BUNDLE}/{name}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
