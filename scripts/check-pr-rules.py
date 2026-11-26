#!/usr/bin/env python3
#
#  check-pr-rules.py
#  Waypoint
#
#  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
#  Copyright © 2026 Yousef Mohamed. MIT License.
#

"""Fails a pull request that breaks one of the yes-or-no pull request rules.

The rules (Yousef, 2026-11-26), each as one check:
- Template: every section of .github/pull_request_template.md is in the body, and "What changed
  and why", "Merge method" and "Tests" hold text of the author's own. The merge method names
  squash or a merge commit, never a rebase.
- One issue: at most one "Closes", "Fixes" or "Resolves" line, with one reference, and at least
  one closing or "Part of" line.
- CHANGELOG: an added line under "## Unreleased" (or a new version heading, for a release). With
  no CHANGELOG change, nothing under Sources/ or in Package.swift may change, and the body's
  "Docs and CHANGELOG" section says why in a line of its own.
- No attribution: no AI or tool credit in the body, the commit messages or the added lines, and
  no added line citing a private planning issue, a planning repo or a numbered decision.

Pull requests Dependabot opened from its own dependabot/ branch carry no template and pass.
CodeRabbit's pre-merge checks of the same names explain a failure in words; this script decides.

Usage: check-pr-rules.py             reads PR_BODY, PR_AUTHOR, HEAD_REF, BASE_SHA, HEAD_SHA
       check-pr-rules.py --self-check  runs its own cases and exits
"""

import os
import re
import subprocess
import sys

TEMPLATE = ".github/pull_request_template.md"
CHANGELOG = "CHANGELOG.md"
UNRELEASED = "## Unreleased"
WHAT = "What changed and why"
MERGE = "Merge method"
TESTS = "Tests"
DOCS = "Docs and CHANGELOG"
SECTIONS = [WHAT, MERGE, TESTS, DOCS, "Checklist"]
AUTHOR_TEXT_SECTIONS = [WHAT, MERGE, TESTS]
# These files hold the patterns below, so their own lines would always match.
PATTERN_FILES = {"scripts/check-pr-rules.py", "scripts/check-public-text.sh", ".coderabbit.yaml"}

AI_TOOLS = r"(claude|anthropic|copilot|codex|cursor|chatgpt|openai|gemini|devin)"
ATTRIBUTION = [
    re.compile(r"co-authored-by:.*" + AI_TOOLS, re.IGNORECASE),
    re.compile(r"^\s*claude-session:", re.IGNORECASE),
    re.compile(r"generated (with|by)\W*" + AI_TOOLS, re.IGNORECASE),
    re.compile(r"claude\.ai/code/session", re.IGNORECASE),
]
# The two credit lines at the top of a body: an HTML comment and a "Requested by" line.
CREDIT_LINE = re.compile(r"^\s*(<!-- claude-projects-attribution:.*-->|_Requested by .*_)\s*$")
PRIVATE_REFS = [
    re.compile(r"planning\s*#\s*\d+", re.IGNORECASE),
    re.compile(r"\b[A-Za-z]+-planning\b"),
    re.compile(r"\bdecisions?\s+\d{3,4}\b", re.IGNORECASE),
]
CLOSING = re.compile(r"^\s*(closes|fixes|resolves)\b", re.IGNORECASE)
PART_OF = re.compile(r"^\s*part of\b", re.IGNORECASE)
# A reference is "#n" or "owner/repo#n"; counting the "#n" part is enough.
REFERENCE = re.compile(r"#\d+")


def strip_comments(text):
    return re.sub(r"<!--.*?-->", "", text, flags=re.DOTALL)


def sections(markdown):
    """Maps each "## " heading to the lines under it, HTML comments removed."""
    found = {}
    current = None
    for line in strip_comments(markdown).splitlines():
        if line.startswith("## "):
            current = line[3:].strip()
            found[current] = []
        elif current is not None:
            found[current].append(line)
    return found


def normalized(line):
    return re.sub(r"^\s*- \[[ xX]\]", "- [ ]", line).strip()


def author_lines(body_lines, template_lines):
    template = {normalized(line) for line in template_lines}
    return [line for line in body_lines if line.strip() and normalized(line) not in template]


def template_errors(body, template):
    errors = []
    body_sections = sections(body)
    template_sections = sections(template)
    for name in SECTIONS:
        if name not in body_sections:
            errors.append(f'the "## {name}" section is missing')
    for name in AUTHOR_TEXT_SECTIONS:
        if name in body_sections:
            own = author_lines(body_sections[name], template_sections.get(name, []))
            if not own:
                errors.append(f'"## {name}" holds no text of your own')
    method = " ".join(body_sections.get(MERGE, [])).lower()
    if MERGE in body_sections and method.strip():
        if "rebase" in method:
            errors.append(f'"## {MERGE}" names a rebase merge, which is never used')
        elif "squash" not in method and "merge commit" not in method:
            errors.append(f'"## {MERGE}" names neither squash nor a merge commit')
    return errors


def issue_errors(body):
    errors = []
    lines = strip_comments(body).splitlines()
    closing = [line for line in lines if CLOSING.match(line) and REFERENCE.search(line)]
    part_of = [line for line in lines if PART_OF.match(line) and REFERENCE.search(line)]
    if len(closing) > 1:
        errors.append(f"{len(closing)} closing lines: a pull request closes one issue")
    for line in closing:
        if len(REFERENCE.findall(line)) > 1:
            errors.append(f'"{line.strip()}" closes more than one issue')
    if not closing and not part_of:
        errors.append('no "Closes <owner/repo>#<n>" or "Part of <owner/repo>#<n>" line')
    return errors


def heading_above(lines, number):
    """The line number of the nearest "## " heading at or above a line, or None."""
    return next((n for n in range(number, 0, -1) if lines[n - 1].startswith("## ")), None)


def added_changelog_errors(changelog, added_lines):
    lines = changelog.splitlines()
    new_headings = {number for number in added_lines if lines[number - 1].startswith("## ")}
    headings = [
        heading_above(lines, number) for number in added_lines if lines[number - 1].strip()
    ]
    unreleased = any(
        heading is not None and lines[heading - 1].strip() == UNRELEASED
        for heading in headings
    )
    errors = [
        f'{CHANGELOG} adds a line under "{lines[heading - 1].strip()}", which is already released'
        for heading in sorted(set(headings))
        if heading is not None
        and lines[heading - 1].strip() != UNRELEASED
        and heading not in new_headings
    ]
    if not unreleased and not new_headings:
        errors.append(f'{CHANGELOG} gains no line under "{UNRELEASED}"')
    return errors


def changelog_errors(changelog, added_lines, changed_files, body, template):
    """added_lines are the 1-based numbers of the lines the PR adds to the changelog."""
    if added_lines:
        return added_changelog_errors(changelog, added_lines)
    package = [f for f in changed_files if f.startswith("Sources/") or f == "Package.swift"]
    if package:
        return [f"{CHANGELOG} has no entry, and the package changes ({package[0]})"]
    own = author_lines(sections(body).get(DOCS, []), sections(template).get(DOCS, []))
    if not own:
        return [f'{CHANGELOG} has no entry, and "## {DOCS}" doesn\'t say why']
    return []


def credits_a_tool(line):
    return any(pattern.search(line) for pattern in ATTRIBUTION)


def attribution_errors(body, commit_messages, added):
    """added maps each changed file to its added lines."""
    errors = [
        f'the body credits an AI or tool: "{line.strip()[:80]}"'
        for line in body.splitlines()
        if not CREDIT_LINE.match(line) and credits_a_tool(line)
    ]
    errors += [
        f'a commit message credits an AI or tool: "{line.strip()[:80]}"'
        for message in commit_messages
        for line in message.splitlines()
        if credits_a_tool(line)
    ]
    for path, lines in added.items():
        if path in PATTERN_FILES:
            continue
        if any(credits_a_tool(line) for line in lines):
            errors.append(f"{path} adds AI or tool attribution")
        if any(pattern.search(line) for line in lines for pattern in PRIVATE_REFS):
            errors.append(f"{path} adds a private planning or decision reference")
    return sorted(set(errors))


def git(*args):
    return subprocess.run(["git", *args], check=True, capture_output=True, text=True).stdout


def added_by_file(base, head):
    added = {}
    added_numbers = {}
    path = None
    number = 0
    for line in git("diff", "--unified=0", "--no-color", f"{base}...{head}").splitlines():
        if line.startswith("+++ "):
            path = line[6:] if line.startswith("+++ b/") else None
        elif line.startswith("@@"):
            number = int(re.match(r"@@ -\S+ \+(\d+)", line).group(1))
        elif line.startswith("+") and path is not None:
            added.setdefault(path, []).append(line[1:])
            added_numbers.setdefault(path, []).append(number)
            number += 1
    return added, added_numbers


def run():
    author = os.environ.get("PR_AUTHOR", "")
    head_ref = os.environ.get("HEAD_REF", "")
    if author == "dependabot[bot]" and head_ref.startswith("dependabot/"):
        print("Opened by Dependabot from its own branch, which carries no template.")
        return 0
    body = os.environ.get("PR_BODY", "")
    base = os.environ["BASE_SHA"]
    head = os.environ["HEAD_SHA"]
    try:
        template = git("show", f"{base}:{TEMPLATE}")
    except subprocess.CalledProcessError:
        with open(TEMPLATE, encoding="utf-8") as file:
            template = file.read()
    changed = git("diff", "--name-only", f"{base}...{head}").split()
    added, numbers = added_by_file(base, head)
    messages = git("log", "--format=%B%x00", f"{base}..{head}").split("\0")
    changelog = git("show", f"{head}:{CHANGELOG}") if CHANGELOG in changed else ""
    checks = {
        "PR template filled in": template_errors(body, template),
        "One issue per PR": issue_errors(body),
        "CHANGELOG under Unreleased": changelog_errors(
            changelog, numbers.get(CHANGELOG, []), changed, body, template
        ),
        "No attribution or private refs": attribution_errors(body, messages, added),
    }
    failed = False
    for name, errors in checks.items():
        if errors:
            failed = True
            for error in errors:
                print(f"::error title={name}::{error}")
        else:
            print(f"{name}: passes")
    if failed:
        print(f"Fix the body or the branch, as {TEMPLATE} asks. Editing the body reruns this.")
    return 1 if failed else 0


SAMPLE_TEMPLATE = """<!-- Fill in every section. -->

Closes <owner/repo>#<issue>

## What changed and why

<!-- Each change and why. -->

## Merge method

<!-- Squash or merge commit. Never rebase. -->

## Tests

- [ ] Each test names its promise

## Docs and CHANGELOG

- [ ] `CHANGELOG.md` updated under **Unreleased**, or no entry because ...

## Checklist

- [ ] Code follows `CODE_STYLE.md`
"""

FILLED = """<!-- claude-projects-attribution: {"github_login":"someone"} -->
_Requested by **Someone** · [project thread](https://claude.ai/code/project/x)_

Closes owner/repo#12
Part of owner/repo#10

## What changed and why

Adds a check, because nothing held the merge.

## Merge method

Squash, because it has one purpose.

## Tests

- [x] Each test names its promise
The new case pins that an empty body fails.

## Docs and CHANGELOG

- [x] `CHANGELOG.md` updated under **Unreleased**, or no entry because ...

## Checklist

- [x] Code follows `CODE_STYLE.md`
"""

# The private reference samples are built in pieces, so this file doesn't match them itself.
PLANNING_ISSUE = "planning" + " #12"
PLANNING_REPO = "Waypoint-" + "planning"
DECISION = "decision" + " 0012"

CHANGELOG_SAMPLE = """# Changelog

## Unreleased

### Added

- New thing.

## 1.0.0 - 2026-11-26

- Old thing.
"""


def self_check():
    cases = [
        ("a filled-in body passes the template", template_errors(FILLED, SAMPLE_TEMPLATE), 0),
        ("the bare template fails", template_errors(SAMPLE_TEMPLATE, SAMPLE_TEMPLATE), 3),
        (
            "a missing section fails",
            template_errors(FILLED.replace("## Checklist", "## Notes"), SAMPLE_TEMPLATE),
            1,
        ),
        (
            "a rebase merge fails",
            template_errors(FILLED.replace("Squash, because", "Rebase, because"), SAMPLE_TEMPLATE),
            1,
        ),
        ("one Closes and a Part of pass", issue_errors(FILLED), 0),
        ("Part of alone passes", issue_errors("Part of #3\n"), 0),
        ("two closing lines fail", issue_errors("Closes #1\nFixes #2\n"), 1),
        ("one line closing two issues fails", issue_errors("Closes #1, closes #2\n"), 1),
        ("the template's placeholder fails", issue_errors(SAMPLE_TEMPLATE), 1),
        (
            "a line under Unreleased passes",
            changelog_errors(CHANGELOG_SAMPLE, [7], [CHANGELOG], FILLED, SAMPLE_TEMPLATE),
            0,
        ),
        (
            "a line under a released version fails",
            changelog_errors(CHANGELOG_SAMPLE, [11], [CHANGELOG], FILLED, SAMPLE_TEMPLATE),
            2,
        ),
        (
            "a release heading passes",
            changelog_errors(
                CHANGELOG_SAMPLE.replace("## Unreleased", "## 1.1.0 - 2026-12-01"),
                [3, 7],
                [CHANGELOG],
                FILLED,
                SAMPLE_TEMPLATE,
            ),
            0,
        ),
        (
            "no entry with a package change fails",
            changelog_errors("", [], ["Sources/A.swift"], FILLED, SAMPLE_TEMPLATE),
            1,
        ),
        (
            "no entry and no reason fails",
            changelog_errors("", [], ["scripts/a.sh"], FILLED, SAMPLE_TEMPLATE),
            1,
        ),
        (
            "no entry with a reason passes",
            changelog_errors(
                "",
                [],
                ["scripts/a.sh"],
                FILLED.replace("## Checklist", "No entry: CI only.\n\n## Checklist"),
                SAMPLE_TEMPLATE,
            ),
            0,
        ),
        ("the credit lines pass", attribution_errors(FILLED, ["Add a check"], {}), 0),
        (
            "a footer in the body fails",
            attribution_errors(FILLED + "\n_Generated by [Claude Code](https://x)_\n", [], {}),
            1,
        ),
        (
            "a co-author trailer fails",
            attribution_errors("", ["Fix\n\nCo-Authored-By: Claude <noreply@anthropic.com>"], {}),
            1,
        ),
        ("a session line fails", attribution_errors("", ["Fix\n\nClaude-Session: x"], {}), 1),
        (
            "a planning reference in a file fails",
            attribution_errors("", [], {"README.md": [f"See {PLANNING_ISSUE}."]}),
            1,
        ),
        (
            "a planning repo name in a file fails",
            attribution_errors("", [], {"a.swift": [f"// in {PLANNING_REPO}"]}),
            1,
        ),
        (
            "a numbered decision in a file fails",
            attribution_errors("", [], {"a.md": [f"As {DECISION} says."]}),
            1,
        ),
        (
            "plain text passes",
            attribution_errors("", [], {"a.md": ["Plan the route, then decide."]}),
            0,
        ),
    ]
    failed = 0
    for name, errors, expected in cases:
        if len(errors) != expected:
            failed += 1
            print(f"self-check failed: {name}: expected {expected} errors, got {errors}")
    if failed:
        return 1
    print(f"self-check: {len(cases)} cases pass")
    return 0


if __name__ == "__main__":
    sys.exit(self_check() if "--self-check" in sys.argv else run())
