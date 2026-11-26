#!/usr/bin/env python3
#
#  ui-test-shards.py
#  Waypoint
#
#  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
#  Copyright © 2026 Yousef Mohamed. MIT License.
#
# Splits the example app's UI test classes into shards for CI, so each macOS runner tests a part
# with one simulator. Every class in Example/WaypointExampleUITests whose body has a `func test...`
# goes to exactly one shard: the classes are taken from the most tests to the fewest, each to the
# shard with the fewest tests so far (the lower shard on a tie), so the split is the same on every
# runner and a new class joins a shard without anyone listing it.
#
# Prints one `-only-testing:WaypointExampleUITests/<Class>` argument per line for xcodebuild.
# `--list` prints every shard with its classes and test counts instead. `--self-check` checks the
# split on a made-up set of classes and exits. It fails when a test sits outside the body of an
# XCTestCase class, such as in an extension, so no test is ever left out of every shard.
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
# Attributes such as `@MainActor` or `@objc` and access or `final` modifiers may come first.
ATTRIBUTES = r"(?:@[A-Za-z_][A-Za-z0-9_]*(?:\([^)\n]*\))?\s+)*"
CLASS = re.compile(
    r"^[ \t]*" + ATTRIBUTES + r"(?:(?:public|internal|private|fileprivate|open|final)\s+)*"
    r"class\s+([A-Za-z_][A-Za-z0-9_]*)\s*:\s*XCTestCase\b",
    re.M,
)
TEST = re.compile(
    r"^[ \t]*" + ATTRIBUTES
    + r"(?:(?:public|internal|private|fileprivate|open|override|final|nonisolated|dynamic)\s+)*"
    r"func\s+(test[A-Za-z0-9_]*)\s*\(",
    re.M,
)


def code_only(source):
    """The source with comments and string literals blanked out, so their braces and text don't
    count. Each blanked character becomes a space and line breaks stay, so positions still match."""
    out = list(source)
    i, n = 0, len(source)

    def blank(a, b):
        for k in range(a, b):
            if out[k] != "\n":
                out[k] = " "

    while i < n:
        if source.startswith("//", i):
            j = source.find("\n", i)
            j = n if j < 0 else j
            blank(i, j)
            i = j
        elif source.startswith("/*", i):
            depth, j = 1, i + 2
            while j < n and depth:
                if source.startswith("/*", j):
                    depth, j = depth + 1, j + 2
                elif source.startswith("*/", j):
                    depth, j = depth - 1, j + 2
                else:
                    j += 1
            blank(i, j)
            i = j
        elif source.startswith('"""', i):
            j = source.find('"""', i + 3)
            j = n if j < 0 else j + 3
            blank(i, j)
            i = j
        elif source[i] == '"':
            j = i + 1
            while j < n and source[j] not in '"\n':
                j += 2 if source[j] == "\\" else 1
            j = min(j + 1, n)
            blank(i, j)
            i = j
        else:
            i += 1
    return "".join(out)


def class_body(code, match):
    """Where the class's body starts and ends: its `{` and the `}` that closes it."""
    opening = code.find("{", match.end())
    if opening < 0:
        return match.end(), match.end()
    depth = 0
    for index in range(opening, len(code)):
        if code[index] == "{":
            depth += 1
        elif code[index] == "}":
            depth -= 1
            if depth == 0:
                return opening, index
    return opening, len(code)


def count_tests(code, match):
    """The test methods declared directly in the class's body. Tests in an extension, or in another
    type declared after it, belong to no class here, and the check in main() refuses them."""
    opening, closing = class_body(code, match)
    count = 0
    for test in TEST.finditer(code, opening, closing):
        depth = code.count("{", opening, test.start()) - code.count("}", opening, test.start())
        if depth == 1:
            count += 1
    return count


def test_classes(folder):
    """Each XCTestCase class with its number of tests, read from the Swift files."""
    classes = {}
    for path in sorted(folder.rglob("*.swift")):
        code = code_only(path.read_text(encoding="utf-8"))
        for match in CLASS.finditer(code):
            count = count_tests(code, match)
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
    found = {match.group(1): count_tests(sample, match) for match in CLASS.finditer(sample)}
    assert found == {"Foo": 2, "Baz": 1}, f"reads the test classes and their tests: {found}"
    hidden = (
        "final class Foo: XCTestCase {\n    func testOne() {}\n}\n"
        "class Bar: BaseTests {\n    func testTwo() {}\n}\n"
    )
    found = {match.group(1): count_tests(hidden, match) for match in CLASS.finditer(hidden)}
    assert found == {"Foo": 1}, f"a test in a class that isn't an XCTestCase counts for no class: {found}"
    marked = (
        "@MainActor\nfinal class Foo: XCTestCase {\n    @objc func testOne() {}\n"
        "    override func testTwo() {}\n    // func testNotOne() {}\n"
        "    let text = \"} func testNotTwo() {\"\n    func helper() { func testNested() {} }\n}\n"
    )
    code = code_only(marked)
    found = {match.group(1): count_tests(code, match) for match in CLASS.finditer(code)}
    assert found == {"Foo": 2}, f"reads marked tests, not comments, strings or nested functions: {found}"
    extended = (
        "final class A: XCTestCase {}\nfinal class B: XCTestCase {\n    func testB() {}\n}\n"
        "extension A {\n    func testA() {}\n}\n"
    )
    code = code_only(extended)
    found = {match.group(1): count_tests(code, match) for match in CLASS.finditer(code)}
    assert found == {"A": 0, "B": 1}, f"a test in an extension counts for no class: {found}"
    assert len(TEST.findall(code)) == 2, "the whole-folder count still sees the extension's test"
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
    # A test outside the body of an XCTestCase subclass, such as one in an extension or in a class
    # that subclasses a base test class, would run in no shard, so the split refuses to leave it out.
    every_test = sum(
        len(TEST.findall(code_only(path.read_text(encoding="utf-8")))) for path in FOLDER.rglob("*.swift")
    )
    if every_test != sum(classes.values()):
        print(
            f"error: {every_test} UI tests in {FOLDER}, but only {sum(classes.values())} sit in the "
            "body of a class that subclasses XCTestCase; the shards would leave the others out, so "
            "move each one into its class's body",
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
