#!/usr/bin/env bash
#
#  sonar-scan.sh
#  Waypoint
#
#  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
#  Copyright © 2026 Yousef Mohamed. MIT License.
#
# Runs SonarQube Cloud's analysis and waits for its quality gate: exits non-zero when the gate
# fails, which fails the required "SonarQube Cloud quality gate" check. Settings are in
# sonar-project.properties.
# - The scanner comes from SonarSource's download site at a pinned version, and both the download
#   and the scanner jar in it are checked against their SHA-256.
# - A pull request is always compared with main. Waypoint has no release yet, so no version is
#   passed and new code on main is everything since the first analysis.
# - Needs SONAR_TOKEN and Java 17 or later (on GitHub's Ubuntu runners). Pull requests from forks
#   get no secrets, so they stop here.
#
# Usage: SONAR_TOKEN=... scripts/sonar-scan.sh

set -euo pipefail

cd "$(dirname "$0")/.."

scanner_version="8.5.0.16571"
scanner_sha256="900b76db8a0efb845ed45d7a44b522bda05c8059bcaa6864c9e969de3a8c05f9"
zip_sha256="4d0e8b2631974c90427a4085dd6ca8be7e3587de2055a69a96d020941e3a629e"
binaries="https://binaries.sonarsource.com/Distribution/sonar-scanner-cli"

if [[ -z "${SONAR_TOKEN:-}" ]]; then
    echo "::error::SONAR_TOKEN is not set. A pull request from a fork gets no secrets, so this scan can't run on it." >&2
    exit 1
fi

work_dir="${RUNNER_TEMP:-$(mktemp -d)}"
# The jar is kept in ~/.cache/sonar-scanner (the checks workflow caches it on pull requests) and
# used when its checksum matches, so most runs download nothing.
cache_dir="${SONAR_SCANNER_CACHE:-$HOME/.cache/sonar-scanner}"
mkdir -p "$cache_dir"
jar="$cache_dir/sonar-scanner-cli-$scanner_version.jar"
if ! echo "$scanner_sha256  $jar" | shasum -a 256 --check --status 2>/dev/null; then
    # From SonarSource's own download site, since Maven Central answers 429 (too many requests)
    # to shared runners. The download waits longer each time it fails: 15, 30, 60 and 120 s.
    zip=$(mktemp "$work_dir/sonar-scanner-cli.XXXXXX")
    for delay in 15 30 60 120 0; do
        if curl --fail --silent --show-error --location --proto '=https' \
            "$binaries/sonar-scanner-cli-$scanner_version.zip" --output "$zip"; then
            break
        fi
        if [[ "$delay" -eq 0 ]]; then
            echo "::error::Couldn't download the SonarQube scanner from binaries.sonarsource.com." >&2
            exit 1
        fi
        echo "::warning::The scanner download failed. Retrying in $delay seconds." >&2
        sleep "$delay"
    done
    echo "$zip_sha256  $zip" | shasum -a 256 --check --status
    unzip -p "$zip" "sonar-scanner-$scanner_version/lib/sonar-scanner-cli-$scanner_version.jar" >"$jar"
    echo "$scanner_sha256  $jar" | shasum -a 256 --check --status
fi

java -jar "$jar" \
    -Dsonar.qualitygate.wait=true \
    -Dsonar.qualitygate.timeout=300
