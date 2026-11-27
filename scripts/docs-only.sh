#!/usr/bin/env bash
#
#  docs-only.sh
#  Waypoint
#
#  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
#  Copyright © 2026 Yousef Mohamed. MIT License.
#
# Reads the paths a pull request changes, one per line, and prints "true" when every one is a file
# no build reads (TESTING.md's docs-only rule: a Markdown file, a DocC catalog file, a docs-theme
# file or Example/quarantine.json), "false" otherwise, and "false" for an empty list. A rename
# counts as both its paths, so a source file moved to Markdown isn't docs-only. The checks
# workflow and the Apple tests workflow both decide with it.
#
# Usage: <list of paths> | scripts/docs-only.sh

set -euo pipefail

paths=$(grep -v '^$' || true)
if [[ -n "$paths" ]] &&
    ! grep -qvE '(\.md$|\.docc/|^docs-theme/|^Example/quarantine\.json$)' <<<"$paths"; then
    echo true
else
    echo false
fi
