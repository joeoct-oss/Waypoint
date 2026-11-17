#!/usr/bin/env bash
#
#  deploy-docs.sh
#  Waypoint
#
#  Created by Yousef Mohamed <52625092+JoeOCT91@users.noreply.github.com>.
#  Copyright © 2026 Yousef Mohamed. MIT License.
#
# Uploads the documentation site from scripts/build-docs.sh to Cloudflare Pages,
# creating the Pages project the first time.
#
# Usage: scripts/deploy-docs.sh
# Environment:
#   WAYPOINT_DOCS_PROJECT  Pages project name (default waypoint-docs).
#   CLOUDFLARE_API_TOKEN   Token with Account > Cloudflare Pages > Edit, set in the
#                          cloud environment. On a Mac without it, read from the
#                          Keychain item waypoint-cloudflare-api-token.
#   CLOUDFLARE_ACCOUNT_ID  Account ID, set the same way (Keychain item
#                          waypoint-cloudflare-account-id).
# Needs Node.js (npx). Tokens never go in the repository.

set -euo pipefail

cd "$(dirname "$0")/.."

PROJECT="${WAYPOINT_DOCS_PROJECT:-waypoint-docs}"
SITE_DIR=.build/docs-site
WRANGLER=(npx --yes wrangler@4.161.0)

# Prints the Keychain item named by the first argument, or fails with a hint.
keychain_value() {
    if ! security find-generic-password -a "$USER" -s "$1" -w 2>/dev/null; then
        echo "error: Keychain item $1 not found." >&2
        echo "Add it with: security add-generic-password -a \"\$USER\" -s $1 -w" >&2
        exit 1
    fi
}

if [[ ! -f "$SITE_DIR/index.html" ]]; then
    echo "error: $SITE_DIR is missing; run scripts/build-docs.sh first" >&2
    exit 1
fi

if [[ -z "${CLOUDFLARE_API_TOKEN:-}" ]]; then
    CLOUDFLARE_API_TOKEN=$(keychain_value waypoint-cloudflare-api-token)
fi
if [[ -z "${CLOUDFLARE_ACCOUNT_ID:-}" ]]; then
    CLOUDFLARE_ACCOUNT_ID=$(keychain_value waypoint-cloudflare-account-id)
fi
export CLOUDFLARE_API_TOKEN CLOUDFLARE_ACCOUNT_ID

if ! "${WRANGLER[@]}" pages project list | grep -qw "$PROJECT"; then
    echo "==> Creating Pages project $PROJECT"
    # --force: newer wrangler versions otherwise expect a Workers project directory here.
    "${WRANGLER[@]}" pages project create "$PROJECT" --production-branch main --force
fi

echo "==> Deploying $SITE_DIR to $PROJECT"
"${WRANGLER[@]}" pages deploy "$SITE_DIR" \
    --project-name "$PROJECT" \
    --branch main \
    --commit-dirty=true

# Pages adds a suffix when the project name is taken as a subdomain, so ask for the real one.
SUBDOMAIN=$(curl -fsS \
    -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
    "https://api.cloudflare.com/client/v4/accounts/$CLOUDFLARE_ACCOUNT_ID/pages/projects/$PROJECT" |
    python3 -c 'import json, sys; print(json.load(sys.stdin)["result"]["subdomain"])')

echo "Documentation is live at https://$SUBDOMAIN/documentation"
