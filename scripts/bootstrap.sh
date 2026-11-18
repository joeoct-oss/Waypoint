#!/usr/bin/env bash
#
#  bootstrap.sh
#  Waypoint
#
#  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
#  Copyright © 2026 Yousef Mohamed. MIT License.
#
# Installs the developer tools at the versions pinned in .mise.toml.
# With mise on the PATH (the Mac), it trusts the file and runs `mise install`.
# Without mise on Linux (cloud threads, where mise's servers are blocked), it downloads the pinned
# SwiftLint release from GitHub into .tools/, checks its sha256, and links it as .tools/bin/swiftlint.
# Tuist and Periphery only run on macOS, so Linux skips them. swift-format needs no install.
#
# Usage: scripts/bootstrap.sh

set -euo pipefail

cd "$(dirname "$0")/.."

# Prints the value of `key = "value"` from .mise.toml.
pinned() {
    sed -n "s/^$1 *= *\"\(.*\)\"/\1/p" .mise.toml | head -n 1
}

if command -v mise > /dev/null 2>&1; then
    echo "==> mise install"
    mise trust --quiet .mise.toml
    mise install
    mise exec -- tuist version
    mise exec -- swiftlint version
    mise exec -- periphery version
    exit 0
fi

if [[ "$(uname -s)" == "Darwin" ]]; then
    echo "error: mise is not installed. Run 'brew install mise', then scripts/bootstrap.sh again." >&2
    exit 1
fi

version="$(pinned swiftlint)"
case "$(uname -m)" in
    x86_64)
        arch="amd64"
        checksum="$(pinned WAYPOINT_SWIFTLINT_LINUX_AMD64_SHA256)"
        ;;
    aarch64 | arm64)
        arch="arm64"
        checksum="$(pinned WAYPOINT_SWIFTLINT_LINUX_ARM64_SHA256)"
        ;;
    *)
        echo "error: no SwiftLint Linux release for $(uname -m)." >&2
        exit 1
        ;;
esac

install_dir=".tools/swiftlint-$version"
if [[ ! -x "$install_dir/swiftlint" ]]; then
    echo "==> Downloading SwiftLint $version ($arch)"
    zip_path="$(mktemp)"
    trap 'rm -f "$zip_path"' EXIT
    curl --fail --silent --show-error --location --output "$zip_path" \
        "https://github.com/realm/SwiftLint/releases/download/$version/swiftlint_linux_$arch.zip"
    echo "$checksum  $zip_path" | sha256sum --check --quiet - || {
        echo "error: SwiftLint $version download does not match the sha256 in .mise.toml." >&2
        exit 1
    }
    mkdir -p "$install_dir"
    unzip -q -o "$zip_path" -d "$install_dir"
fi

mkdir -p .tools/bin
ln -sf "../swiftlint-$version/swiftlint" .tools/bin/swiftlint
echo "==> SwiftLint $version is at .tools/bin/swiftlint (Tuist and Periphery are macOS only)"
