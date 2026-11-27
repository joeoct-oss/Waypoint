# How to review a Waypoint pull request

Gitar reviews beside CodeRabbit and gives advice only: it never approves, never blocks a merge
and never writes commits or edits the pull request description.

- Report only blockers and should-fix items, each as one inline comment that names the rule it
  breaks and why. Breaking a code style rule is a should-fix item. No praise, no recaps and no
  nitpicks the code style doesn't ask for.
- Look hardest at what the linters and SonarQube Cloud can't see: logic and behaviour bugs,
  broken promises to the package's users, races, and tests that would pass with the bug.
- Code style, including docs and examples:

@CODE_STYLE.md

- What a test may and may not do:

@TESTING.md
