#!/usr/bin/env bash
#
#  check-concurrency.sh
#  Waypoint
#
#  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
#  Copyright © 2026 Yousef Mohamed. MIT License.
#
# The concurrency guard rail (#24). Fails when:
#
# - Sources/ uses an unsafe concurrency escape: `@unchecked Sendable`, `nonisolated(unsafe)`,
#   `@preconcurrency`, `assumeIsolated`, `unsafeBitCast`, `unsafeDowncast`, `Unmanaged`,
#   `Unsafe…Pointer` or `@_unsafeInheritExecutor`;
# - Sources/WaypointCore uses a lock or a queue: `NSLock`, `Mutex`, `DispatchQueue`,
#   `Task.detached` or `import Synchronization`. The main actor is the core's only writer;
# - Package.swift lowers the language mode to Swift 5 or uses `unsafeFlags`;
# - a test in Tests/WaypointCoreTests/Concurrency uses `@testable` or a `package` symbol of
#   WaypointCore. Those tests use the public API only, like an app.
#
# Patterns allow any whitespace or line break inside them. Comments are skipped. The only
# exception is a use with `// concurrency-escape: <reason> (<issue link>)` on the line right above
# it that is also listed in ALLOWED below, so adding one is a reviewed change.
#
# Usage: scripts/check-concurrency.sh [root]

set -euo pipefail

root="${1:-$(cd "$(dirname "$0")/.." && pwd)}"
cd "$root"

# Allowed escapes, one per line: <file>|<pattern name>.
ALLOWED='Sources/WaypointOSLog/OSLogHandler.swift|@unchecked Sendable'

export ALLOWED

perl -e '
use strict;
use warnings;

my %allowed = map { $_ => 1 } split /\n/, $ENV{ALLOWED};

my @escapes = (
    ["\@unchecked Sendable", qr/\@unchecked\s+Sendable\b/],
    ["nonisolated(unsafe)", qr/\bnonisolated\s*\(\s*unsafe\s*\)/],
    ["\@preconcurrency", qr/\@preconcurrency\b/],
    ["assumeIsolated", qr/\bassumeIsolated\b/],
    ["unsafeBitCast", qr/\bunsafeBitCast\b/],
    ["unsafeDowncast", qr/\bunsafeDowncast\b/],
    ["Unmanaged", qr/\bUnmanaged\b/],
    ["Unsafe pointer", qr/\bUnsafe(?:Mutable)?(?:Raw)?(?:Buffer)?Pointer\b/],
    ["\@_unsafeInheritExecutor", qr/\@_unsafeInheritExecutor\b/],
);
my @locks = (
    ["NSLock", qr/\bNSLock\b/],
    ["Mutex", qr/\bMutex\b/],
    ["DispatchQueue", qr/\bDispatchQueue\b/],
    ["Task.detached", qr/\bTask\s*\.\s*detached\b/],
    ["import Synchronization", qr/\bimport\s+Synchronization\b/],
);
my @manifest = (
    ["Swift 5 language mode", qr/swiftLanguageMode\s*\(\s*\.v5\b|swiftLanguageModes\s*:\s*\[[^\]]*\.v5\b/],
    ["unsafeFlags", qr/\bunsafeFlags\b/],
);

my $failed = 0;

# The file with comments blanked, keeping line numbers, and its original lines.
sub load {
    my ($file) = @_;
    open my $fh, "<", $file or die "$file: $!";
    my @lines = <$fh>;
    close $fh;
    my @code = map { my $l = $_; $l =~ s{//.*$}{}; $l } @lines;
    return (join("", @code), \@lines);
}

sub check {
    my ($file, $rules) = @_;
    my ($code, $lines) = load($file);
    for my $rule (@$rules) {
        my ($name, $pattern) = @$rule;
        while ($code =~ /$pattern/g) {
            my $line = (substr($code, 0, $-[0]) =~ tr/\n//) + 1;
            my $above = $line >= 2 ? $lines->[$line - 2] : "";
            my $tagged = $above =~ m{^\s*//\s*concurrency-escape:\s*\S.*\(\S+\)\s*$};
            next if $tagged && $allowed{"$file|$name"};
            my $why = $tagged ? "is tagged but not in the allowlist of scripts/check-concurrency.sh"
                : "needs a // concurrency-escape: <reason> (<issue link>) line above it and an allowlist entry";
            print STDERR "$file:$line: $name $why\n";
            $failed = 1;
        }
    }
}

my @sources = split /\n/, `find Sources -name "*.swift" | sort`;
for my $file (@sources) {
    check($file, \@escapes);
    check($file, \@locks) if $file =~ m{^Sources/WaypointCore/};
}
check("Package.swift", [@escapes, @manifest]);

# The package symbols of WaypointCore, which public-API-only tests may not use.
my %symbols;
for my $file (grep { m{^Sources/WaypointCore/} } @sources) {
    my ($code) = load($file);
    while ($code =~ /\bpackage\s+(?:static\s+|final\s+|nonisolated\s+)*(struct|class|enum|protocol|actor|typealias|func|var|let|init)\b\s*([A-Za-z_]\w*)?(?:<[^>]*>)?\s*(\(\s*(\w+))?/g) {
        my ($kind, $name, $label) = ($1, $2, $4);
        if ($kind eq "init") {
            $symbols{"init($label:"} = qr/\(\s*\Q$label\E\s*:/ if defined $label && $label ne "_";
        } elsif ($kind eq "func") {
            next unless defined $name;
            $symbols{"$name("} = (defined $label && $label ne "_")
                ? qr/\b\Q$name\E\s*\(\s*\Q$label\E\s*:/ : qr/\.\Q$name\E\s*\(/;
        } elsif ($kind eq "var" || $kind eq "let") {
            $symbols{".$name"} = qr/\.\Q$name\E\b/ if defined $name;
        } else {
            $symbols{$name} = qr/\b\Q$name\E\b/ if defined $name;
        }
    }
}

for my $file (split /\n/, `find Tests/WaypointCoreTests/Concurrency -name "*.swift" | sort`) {
    my ($code) = load($file);
    if ($code =~ /\@testable\b/) {
        print STDERR "$file: uses \@testable; concurrency tests use the public API only\n";
        $failed = 1;
    }
    for my $symbol (sort keys %symbols) {
        if ($code =~ $symbols{$symbol}) {
            my $line = (substr($code, 0, $-[0]) =~ tr/\n//) + 1;
            print STDERR "$file:$line: uses the package symbol $symbol of WaypointCore; use the public API\n";
            $failed = 1;
        }
    }
}

exit $failed;
'

echo "ok: no unsafe concurrency escapes, locks or package symbols in public-API tests"
