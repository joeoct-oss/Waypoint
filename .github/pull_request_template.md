Closes joeoct-oss/Waypoint-planning#

**Plan:** <link to plans/planning-<issue>-<slug>.md in Waypoint-planning, or "not needed">

## What changed

## Tests

- [ ] Unit tests were written first and failed before the change
- [ ] UI tests added or updated for visible behaviour (or not needed, because ...)
- [ ] The merge gate in [TESTING.md](https://github.com/joeoct-oss/Waypoint/blob/main/TESTING.md#2-which-run-is-needed) passed: Linux on the head commit (CI's **Linux checks**, re-run when `main` moved), and the Mac `full` run on the pull request's [merge batch](https://github.com/joeoct-oss/Waypoint/blob/main/TESTING.md#merge-batches), with its report and batch line below

## Checklist

- [ ] `scripts/lint.sh` passes (strict SwiftLint and swift-format, see planning #324); required before review
- [ ] Labels copied from the issue (type, area, priority, test, runs)
- [ ] Public symbols documented in DocC
- [ ] Code follows `CODE_STYLE.md`, including a reason for every protocol conformance
- [ ] Every doc that states what this changes is updated in this pull request (DocC, README, CONTRIBUTING, CODE_STYLE), or none does
- [ ] CHANGELOG updated under Unreleased
