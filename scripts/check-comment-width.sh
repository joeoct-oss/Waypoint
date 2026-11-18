#!/usr/bin/env bash
#
#  check-comment-width.sh
#  Waypoint
#
#  Created by Yousef Mohamed <52625092+JoeOCT91@users.noreply.github.com>.
#  Copyright © 2026 Yousef Mohamed. MIT License.
#
# Fails when a comment line is longer than 100 columns, indentation included (CODE_STYLE.md,
# "Comments wrap at 100 columns"). It checks `//` and `///` lines in Swift files, and the same
# lines inside the code blocks of DocC articles and the Markdown files at the root.
# Lines inside a ```text block and lines with a URL are allowed to run long.
#
# Usage: scripts/check-comment-width.sh [limit]

set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
limit="${1:-100}"

check() {
    # Perl with -CSD counts characters, not bytes, so `›` and `…` count as one column.
    LIMIT="$limit" MARKDOWN="$2" NAME="$1" perl -CSD -ne '
        BEGIN { $found = 0; $in_block = 0; $text_block = 0; }
        chomp;
        # Markdown: only lines inside code blocks count; a ```text block is sample output.
        if ($ENV{MARKDOWN} && /^```/) {
            $in_block = !$in_block;
            $text_block = $in_block && /^```text/;
            next;
        }
        next if $ENV{MARKDOWN} && !$in_block;
        # Swift: a ```text block inside a doc comment is sample output too.
        if (m{^\s*///\s*```}) {
            $text_block = !$text_block && /```text/;
            next;
        }
        next if $text_block || m{https?://};
        if (m{^\s*//} && length($_) > $ENV{LIMIT}) {
            printf "%s:%d: comment line is %d columns (limit %d)\n", $ENV{NAME}, $., length($_), $ENV{LIMIT};
            $found = 1;
        }
        END { exit $found; }
    ' "$root/$1"
}

failed=0
while IFS= read -r -d '' file; do
    check "${file#"$root"/}" 0 || failed=1
done < <(find "$root/Sources" "$root/Tests" "$root/Example" "$root/Package.swift" -name '*.swift' -not -path '*/.build/*' -print0)

while IFS= read -r -d '' file; do
    check "${file#"$root"/}" 1 || failed=1
done < <(find "$root/Sources" -name '*.md' -print0; find "$root" -maxdepth 1 -name '*.md' -print0)

if [ "$failed" -ne 0 ]; then
    echo "Wrap the comment lines above at $limit columns." >&2
    exit 1
fi
