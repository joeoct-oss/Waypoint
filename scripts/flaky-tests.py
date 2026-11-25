#!/usr/bin/env python3
#
#  flaky-tests.py
#  Waypoint
#
#  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
#  Copyright © 2026 Yousef Mohamed. MIT License.
#
# Decides whether an example app test step passed, from the JSON that
# `xcrun xcresulttool get test-results tests --path <bundle>` writes, read from standard input, and
# the quarantine list in Example/quarantine.json. The step ran with
# `-retry-tests-on-failure -test-iterations 2`, so a failed test ran once more. See TESTING.md,
# "Flaky tests and quarantine".
#
# - A UI test that failed, then passed on its retry, is flaky: it doesn't block, and it is printed
#   as `Flaky: <test>` with its first failure line.
# - A UI test that failed every try blocks, unless it is in quarantine and its entry hasn't
#   expired: then it is printed as `Quarantined: <test>` and doesn't block.
# - A unit test that failed any try blocks: only UI tests may pass on a retry.
# - A step that failed with no failed test (a build error, a runner that never started) blocks, and
#   so does a failed step with a failure outside its tests (a runner that crashed between tests, a
#   build error the bundle records, given as `--other-errors`), whatever its tests did.
# - Without `--quarantine` nothing is quarantined: `test-mac.sh --only` passes none, so the one test
#   it runs always counts.
#
# Exit status: 0 when nothing blocks, 1 when something does, 2 when the quarantine file is wrong.
#
# Usage:
#   xcrun xcresulttool get test-results tests --path <bundle> |
#       scripts/flaky-tests.py --step-status <n> [--other-errors <n>] [--quarantine <file>]
#           [--today YYYY-MM-DD] [--out <json>]
#   scripts/flaky-tests.py --check-quarantine <file> [--today YYYY-MM-DD]
#   scripts/flaky-tests.py --list-quarantine <file> [--today YYYY-MM-DD]
#   xcrun xcresulttool get test-results tests --path <bundle> |
#       scripts/flaky-tests.py --stress <test> --repeats <n> --step-status <n> --results-dir <folder>
#           [--out <json>]
#   scripts/flaky-tests.py --summary <results folder>
#
# A stress run (`--stress`) judges one quarantined test that ran `--repeats` times in a row with
# no retry: it passed the stress run when it passed every one of those tries and didn't fail in
# the run's earlier steps, whose verdicts are in `--results-dir`. It prints `Stress passed: <test>`
# or `Stress failed: <test>` with why, and always exits 0: a stress run gates nothing.

import argparse
import datetime
import json
import os
import re
import sys

MAX_QUARANTINED = 3
QUARANTINE_DAYS = 7
UI_BUNDLE = "WaypointExampleUITests"
TEST_NAME = re.compile(r"^WaypointExampleUITests/[A-Za-z_][A-Za-z0-9_]*/[A-Za-z_][A-Za-z0-9_]*$")


class QuarantineError(Exception):
    pass


def read_quarantine(path, today):
    """The quarantine's entries as (active, expired) dictionaries keyed by test name.

    Raises QuarantineError with every reason the file breaks the rules."""
    if not path or not os.path.exists(path):
        return {}, {}
    try:
        with open(path, encoding="utf-8") as handle:
            data = json.load(handle)
    except ValueError as error:
        raise QuarantineError(f"{path} isn't valid JSON ({error})")
    tests = data.get("tests") if isinstance(data, dict) else None
    if not isinstance(tests, list):
        raise QuarantineError(f'{path} needs a "tests" list')
    problems = []
    if len(tests) > MAX_QUARANTINED:
        problems.append(f"{len(tests)} tests are quarantined; at most {MAX_QUARANTINED} may be")
    active, expired = {}, {}
    for index, entry in enumerate(tests, start=1):
        if not isinstance(entry, dict):
            problems.append(f"entry {index} isn't an object")
            continue
        name = entry.get("test")
        label = name if isinstance(name, str) else f"entry {index}"
        if not isinstance(name, str) or not TEST_NAME.match(name):
            problems.append(f"{label}: the test must read {UI_BUNDLE}/<Class>/<test>")
        elif name in active or name in expired:
            problems.append(f"{label}: listed twice")
        issue = entry.get("issue")
        if not isinstance(issue, int) or isinstance(issue, bool) or issue < 1:
            problems.append(f"{label}: needs the number of its open flaky-test issue")
        try:
            since = datetime.date.fromisoformat(str(entry.get("since")))
        except ValueError:
            problems.append(f"{label}: since must be a date like 2026-11-26")
            continue
        if since > today:
            problems.append(f"{label}: since {since} is in the future")
            continue
        if not isinstance(name, str):
            continue
        record = {"test": name, "issue": issue, "since": since.isoformat(),
                  "until": (since + datetime.timedelta(days=QUARANTINE_DAYS - 1)).isoformat()}
        if (today - since).days < QUARANTINE_DAYS:
            active[name] = record
        else:
            expired[name] = record
    if problems:
        raise QuarantineError("; ".join(problems))
    return active, expired


def descendants(node):
    for child in node.get("children", []) or []:
        yield child
        yield from descendants(child)


def first_failure(node):
    for child in descendants(node):
        if child.get("nodeType") == "Failure Message":
            return child.get("name", "").strip()
    return ""


def test_cases(nodes, bundle=None, suite=None):
    """Every test case as (name, is_ui, tries, first failure line), tries oldest first."""
    for node in nodes:
        kind = node.get("nodeType")
        if kind in ("Unit test bundle", "UI test bundle"):
            yield from test_cases(node.get("children", []), node, None)
        elif kind == "Test Suite":
            yield from test_cases(node.get("children", []), bundle, node.get("name"))
        elif kind == "Test Case":
            bundle_name = (bundle or {}).get("name", "")
            is_ui = (bundle or {}).get("nodeType") == "UI test bundle" or bundle_name.endswith("UITests")
            test = node.get("name", "?")
            if test.endswith("()"):
                test = test[:-2]
            name = "/".join(part for part in (bundle_name, suite, test) if part)
            tries = [child.get("result") for child in descendants(node)
                     if child.get("nodeType") == "Repetition"]
            if not tries:
                tries = [node.get("result")]
            yield name, is_ui, tries, first_failure(node)
        else:
            yield from test_cases(node.get("children", []), bundle, suite)


def loose_failures(nodes):
    """Failure messages outside every test case, such as a runner that crashed between tests."""
    for node in nodes:
        if node.get("nodeType") == "Test Case":
            continue
        if node.get("nodeType") == "Failure Message":
            yield node.get("name", "").strip()
        else:
            yield from loose_failures(node.get("children", []) or [])


def judge(data, step_status, active, expired, other_errors=0):
    """The step's verdict: (blocking lines, records for the report).

    A failed step passes only when its failed tests account for every failure: a failure outside
    the tests (`loose_failures`, or `other_errors` from the bundle's build results) keeps it failed.
    """
    blocking, records = [], []
    failed_any = False
    for name, is_ui, tries, failure in test_cases(data.get("testNodes", [])):
        failures = sum(1 for result in tries if result == "Failed")
        if failures == 0:
            continue
        failed_any = True
        passed = any(result == "Passed" for result in tries)
        detail = f" ({failure})" if failure else ""
        if passed and is_ui:
            print(f"Flaky: {name} failed {failures} of {len(tries)} tries, then passed{detail}")
            records.append({"test": name, "kind": "flaky", "tries": len(tries), "failures": failures,
                            "failure": failure})
        elif passed:
            blocking.append(f"{name} passed only on a retry, which only a UI test may{detail}")
            records.append({"test": name, "kind": "failed", "tries": len(tries),
                            "failures": failures, "failure": failure})
        elif is_ui and name in active:
            entry = active[name]
            print(f"Quarantined: {name} failed every try; it doesn't block until {entry['until']}, "
                  f"issue #{entry['issue']}{detail}")
            records.append({"test": name, "kind": "quarantined", "tries": len(tries),
                            "failures": failures, "failure": failure, "issue": entry["issue"]})
        else:
            if name in expired:
                print(f"Quarantine expired: {name} was quarantined until {expired[name]['until']}, "
                      "so it blocks again")
            blocking.append(f"{name} failed every try ({len(tries)}){detail}")
            records.append({"test": name, "kind": "failed", "tries": len(tries),
                            "failures": failures, "failure": failure})
    if step_status != 0:
        for line in loose_failures(data.get("testNodes", [])):
            blocking.append(f"the step failed outside its tests: {line}")
        if other_errors > 0:
            blocking.append(f"the step failed with {other_errors} error(s) outside its tests "
                            "(the bundle's build results)")
    if step_status != 0 and not failed_any:
        blocking.append(f"the step failed (status {step_status}) and no test failed: it isn't a "
                        "test result, so it fails as it is")
    return blocking, records


def earlier_failures(folder, test):
    """The steps in `folder` whose verdict lists `test` as flaky or quarantined."""
    steps = []
    for entry in sorted(os.listdir(folder)) if os.path.isdir(folder) else []:
        if entry.endswith("-flaky.json"):
            with open(os.path.join(folder, entry), encoding="utf-8") as handle:
                if any(record.get("test") == test for record in json.load(handle)):
                    steps.append(entry[:-len("-flaky.json")])
    return steps


def stress(data, test, repeats, step_status, folder):
    """A stress record for `test`: passed only when every try passed, here and earlier."""
    tries = []
    failure = ""
    for name, _, case_tries, case_failure in test_cases(data.get("testNodes", [])):
        if name == test:
            tries += case_tries
            failure = failure or case_failure
    passes = sum(1 for result in tries if result == "Passed")
    earlier = earlier_failures(folder, test)
    if earlier:
        why = f"it failed in {', '.join(earlier)}"
    elif not tries:
        why = "it didn't run"
    elif passes < len(tries):
        why = f"it failed {len(tries) - passes} of {len(tries)} tries" + (f" ({failure})" if failure else "")
    elif passes < repeats:
        why = f"it ran {passes} of {repeats} times"
    elif step_status != 0:
        why = f"its step failed (status {step_status})"
    else:
        why = ""
    if why:
        print(f"Stress failed: {test}: {why}")
    else:
        print(f"Stress passed: {test} passed {passes} of {passes} tries and the full run's")
    return {"test": test, "kind": "stress", "passed": not why, "why": why, "tries": len(tries)}


def summary(folder):
    lines = []
    for suffix in ("-flaky.json", "-stress.json"):
        for entry in sorted(os.listdir(folder)) if os.path.isdir(folder) else []:
            if not entry.endswith(suffix):
                continue
            with open(os.path.join(folder, entry), encoding="utf-8") as handle:
                records = json.load(handle)
            for record in records if isinstance(records, list) else [records]:
                if record["kind"] == "stress":
                    result = "Stress passed" if record["passed"] else "Stress failed"
                    why = f": {record['why']}" if record.get("why") else ""
                    lines.append(f"  {result}: {record['test']}{why}")
                    continue
                kind = {"flaky": "Flaky", "quarantined": "Quarantined"}.get(record["kind"], "Failed")
                failure = f": {record['failure']}" if record.get("failure") else ""
                lines.append(f"  {kind}: {record['test']} ({entry[:-len(suffix)]}){failure}")
    print("Flaky tests:")
    print("\n".join(lines) if lines else "  none")


def main():
    parser = argparse.ArgumentParser(add_help=True)
    parser.add_argument("--step-status", type=int)
    parser.add_argument("--other-errors", type=int, default=0)
    parser.add_argument("--quarantine")
    parser.add_argument("--today")
    parser.add_argument("--out")
    parser.add_argument("--check-quarantine")
    parser.add_argument("--summary")
    parser.add_argument("--list-quarantine")
    parser.add_argument("--stress")
    parser.add_argument("--repeats", type=int, default=5)
    parser.add_argument("--results-dir", default=".")
    args = parser.parse_args()
    today = datetime.date.fromisoformat(args.today) if args.today else datetime.date.today()

    if args.summary:
        summary(args.summary)
        return 0

    if args.list_quarantine:
        try:
            active, _ = read_quarantine(args.list_quarantine, today)
        except QuarantineError as error:
            print(f"error: the quarantine file is wrong: {error}", file=sys.stderr)
            return 2
        for name in active:
            print(name)
        return 0

    if args.stress:
        try:
            data = json.load(sys.stdin)
            if not isinstance(data, dict):
                raise ValueError("not an object")
        except ValueError:
            data = {}
        record = stress(data, args.stress, args.repeats, args.step_status or 0, args.results_dir)
        if args.out:
            with open(args.out, "w", encoding="utf-8") as handle:
                json.dump(record, handle, indent=2)
        return 0

    if args.check_quarantine:
        try:
            active, expired = read_quarantine(args.check_quarantine, today)
        except QuarantineError as error:
            print(f"error: {error}", file=sys.stderr)
            return 2
        for name, entry in expired.items():
            print(f"warning: {name} was quarantined until {entry['until']}; remove it "
                  f"(issue #{entry['issue']})")
        print(f"ok: {len(active)} quarantined test(s), {len(expired)} expired")
        return 0

    if args.step_status is None:
        parser.error("--step-status is required")
    try:
        active, expired = read_quarantine(args.quarantine, today)
    except QuarantineError as error:
        print(f"error: the quarantine file is wrong: {error}", file=sys.stderr)
        return 2
    try:
        data = json.load(sys.stdin)
        if not isinstance(data, dict):
            raise ValueError("not an object")
    except ValueError as error:
        # No readable results: the step's own status stands.
        print(f"note: no test results to judge ({error}); the step's own status stands")
        return 0 if args.step_status == 0 else 1
    blocking, records = judge(data, args.step_status, active, expired, args.other_errors)
    if args.out:
        with open(args.out, "w", encoding="utf-8") as handle:
            json.dump(records, handle, indent=2)
    for line in blocking:
        print(f"error: {line}", file=sys.stderr)
    return 1 if blocking else 0


if __name__ == "__main__":
    sys.exit(main())
