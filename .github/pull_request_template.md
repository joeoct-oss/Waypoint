Closes #

**Plan:** <link to plans/<issue>-<slug>.md in Waypoint-planning, or "not needed">

## What changed

## Tests

- [ ] Unit tests were written first and failed before the change
- [ ] UI tests added or updated for visible behaviour (or not needed, because ...)
- [ ] All tests pass locally
- [ ] `scripts/check-concurrency.sh` and `scripts/check-compile-failures.sh` pass (until CI runs them, #5)

## Checklist

- [ ] `scripts/lint.sh` passes (strict SwiftLint and swift-format, see #70); required before review
- [ ] Labels copied from the issue (type, area, priority, test, runs)
- [ ] Public symbols documented in DocC
- [ ] Code follows `CODE_STYLE.md`, including a reason for every protocol conformance
- [ ] Every doc that states what this changes is updated in this pull request (DocC, README, CONTRIBUTING, CODE_STYLE), or none does
- [ ] CHANGELOG updated under Unreleased
