#!/usr/bin/env bash
#
#  check-public-text.sh
#  Waypoint
#
#  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
#  Copyright © 2026 Yousef Mohamed. MIT License.
#
# Fails when a tracked file cites something a reader of this public repo can't open: an issue
# of the private planning repo ("planning" followed by "#" and a number, also across a comment's
# line break), that repo's name, or a numbered decision ("decision" followed by four digits).
# Say the reason in words instead, such as "so a second tap pushes nothing".
#
# It also fails on any name listed in the PRIVATE_NAMES environment variable (one per line or
# comma separated, matched as whole words, any case), so the list itself is never in the repo.
# CI passes it from a repository secret, which keeps it out of the public logs; a hit names
# the file and line, never the name. With PRIVATE_NAMES empty, as on a fork's pull request,
# that part is skipped.
#
# Before the tree, it checks itself on a temporary repo: each pattern must fail and plain text
# must pass.
#
# Usage: scripts/check-public-text.sh [root]

set -euo pipefail

script="$(cd "$(dirname "$0")" && pwd)/$(basename "$0")"
root="${1:-$(cd "$(dirname "$0")/.." && pwd)}"

# Prints each hit as "<file>:<line>: <what>" and exits 1 when there is one. Reads every tracked
# text file of the git repo in the current folder.
scan() {
    git ls-files -z | PRIVATE_NAMES="${PRIVATE_NAMES:-}" perl -0 -ne '
        BEGIN {
            # The repo name and the reference patterns, written so this file doesn'"'"'t match them.
            my $repo = "Waypoint-" . "planning";
            @rules = (
                [qr/\bplanning[ \t]*(?:\n[ \t]*(?:\/\/+|#+|\*+|<!--)?[ \t]*)?#[0-9]+/i,
                    "cites a planning issue"],
                [qr/\Q$repo\E/i, "names the private planning repo"],
                [qr/\bdecisions?[ \t-]+(?:\n[ \t]*(?:\/\/+|#+|\*+)?[ \t]*)?0[0-9]{3}\b/i,
                    "cites a numbered decision"],
            );
            for my $name (split /[,\n]/, $ENV{PRIVATE_NAMES}) {
                $name =~ s/^\s+|\s+$//g;
                push @rules, [qr/(?<![\w-])\Q$name\E(?![\w-])/i, "names a private name"]
                    if length $name;
            }
            $failed = 0;
        }
        chomp(my $file = $_);
        next unless -f $file && -T $file;
        open my $fh, "<", $file or next;
        local $/;
        my $text = <$fh>;
        close $fh;
        for my $rule (@rules) {
            my ($pattern, $what) = @$rule;
            while ($text =~ /$pattern/g) {
                my $line = (substr($text, 0, $-[0]) =~ tr/\n//) + 1;
                print STDERR "$file:$line: $what\n";
                $failed = 1;
            }
        }
        END { exit $failed }
    '
}

# Runs the check on a temporary repo holding one file with `$2`, and fails unless the result is
# `$1` ("passes" or "fails"). The test text is assembled here, so this file holds none of it.
expect() {
    local want="$1" text="$2" names="${3:-}" work got
    work="$(mktemp -d)"
    git -C "$work" init -q
    printf '%s\n' "$text" > "$work/file.swift"
    git -C "$work" add file.swift
    if (cd "$work" && PRIVATE_NAMES="$names" scan 2> "$work/log"); then got=passes; else got=fails; fi
    rm -rf "$work"
    if [[ "$got" != "$want" ]]; then
        echo "error: check-public-text self-check: expected '$text' to $want, it ${got%s}ed" >&2
        exit 1
    fi
}

p="plan""ning"
d="deci""sion"
expect fails "/// Pushes once ($p #344)."
expect fails "// Pushes once (Plan""ning #344)."
expect fails "/// Pushes once ($p
/// #344)."
expect fails "# See https://github.com/joeoct-oss/Waypoint-${p}/issues/1"
expect fails "// The one UI product ($d 0017)."
expect fails "// Same as ${d}s 0004 and 0007."
expect fails "// Built for Acme." "Acme, Other Co"
expect fails "// Built for other co." "Acme
Other Co"
expect passes "/// Pushes once, so a second tap pushes nothing."
expect passes "// Planned with tabs; issue #12 in this repo; $d made in 2026."
expect passes "// Built for Acmeville." "Acme"
expect passes "// Built for Acme." ""

cd "$root"
if ! scan; then
    echo "Say the reason in words instead of citing private planning issues, decisions or names." >&2
    exit 1
fi
echo "ok: no private references in the public text"
