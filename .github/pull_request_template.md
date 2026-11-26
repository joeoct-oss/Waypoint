<!--
Fill in every section. CodeRabbit's pre-merge checks hold the merge while a section is missing
or still holds only this template's text. Write "not needed, because ..." instead of deleting a
section or a line. The comments can stay; they don't show on the page.
-->

Closes <owner/repo>#<issue>
<!-- One issue per pull request: one "Closes" line, plus a "Part of <owner/repo>#<n>" line for
each larger issue this is a step of. A step of a larger issue may have only "Part of" lines. -->

**Plan:** <link to the plan, or "not needed">

## What changed and why

<!-- Each change and the reason for it, so the diff needs no guessing. Flag any public API
change, and say whether it is breaking. -->

## Merge method

<!-- "Squash, because ..." for a single-purpose change or one with review-fix rounds.
"Merge commit, because ..." when the commits record why; tidy them into meaningful steps
first. Never rebase. -->

## Tests

<!-- The promise each new or changed test pins, by its display name, or why no test is
needed. -->

- [ ] Each new or changed test names the promise it pins and reaches the code only the way its user does: no `@testable`, private state, internal counts or sleeps
- [ ] The tests were written first and failed before the change, or no test is needed (say why above)
- [ ] UI tests added or updated for visible behaviour, or not needed, because ...
- [ ] The merge gate in [TESTING.md](https://github.com/joeoct-oss/Waypoint/blob/main/TESTING.md#2-which-run-is-needed) passed: Linux on the head commit (CI's **Linux checks**, re-run when `main` moved), and the Mac `full` run on the pull request's [merge batch](https://github.com/joeoct-oss/Waypoint/blob/main/TESTING.md#merge-batches), with its report and batch line below

## Docs and CHANGELOG

- [ ] `CHANGELOG.md` updated under **Unreleased**, or no entry because ... (only when nothing under `Sources/` or `Package.swift` changes)
- [ ] Every doc that states what this changes is updated in this pull request, or none does
- [ ] Every new public symbol has a doc comment

## Checklist

- [ ] Code follows `CODE_STYLE.md`
- [ ] No tool or AI attribution in this body, the commits or the files
- [ ] `scripts/lint.sh` passes (strict SwiftLint and swift-format, once the lint setup lands); required before review
- [ ] Labels copied from the issue (type, area, priority, test, runs)
