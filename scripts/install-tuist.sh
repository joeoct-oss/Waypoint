#!/usr/bin/env bash
#
#  install-tuist.sh
#  Waypoint
#
#  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
#  Copyright © 2026 Yousef Mohamed. MIT License.
#
# Installs the Tuist that .mise.toml pins, on a Mac without mise, such as GitHub's macOS runners:
# it downloads the release's tuist.zip over HTTPS only, checks it against
# WAYPOINT_TUIST_MACOS_SHA256 in .mise.toml, and unpacks it into the folder given. A version bump
# that forgets the checksum fails here instead of running an unchecked binary. In a GitHub
# workflow it also puts the folder on the PATH of the later steps.
#
# Usage: scripts/install-tuist.sh <folder>

set -euo pipefail

cd "$(dirname "$0")/.."

if [[ $# -ne 1 ]]; then
    echo "usage: scripts/install-tuist.sh <folder>" >&2
    exit 2
fi
folder="$1"

version=$(sed -n 's/^tuist = "\([^"]*\)"$/\1/p' .mise.toml)
sha256=$(sed -n 's/^WAYPOINT_TUIST_MACOS_SHA256 = "\([0-9a-f]*\)"$/\1/p' .mise.toml)
if [[ -z "$version" || ${#sha256} -ne 64 ]]; then
    echo "error: .mise.toml must pin tuist and WAYPOINT_TUIST_MACOS_SHA256" >&2
    exit 1
fi

mkdir -p "$folder"
archive="$folder/tuist.zip"
curl -fsSL --proto '=https' --tlsv1.2 --retry 3 -o "$archive" \
    "https://github.com/tuist/tuist/releases/download/$version/tuist.zip"
echo "$sha256  $archive" | shasum -a 256 --check --strict
unzip -q -o "$archive" -d "$folder"
rm -f "$archive"
"$folder/tuist" version
if [[ -n "${GITHUB_PATH:-}" ]]; then
    echo "$(cd "$folder" && pwd)" >>"$GITHUB_PATH"
fi
