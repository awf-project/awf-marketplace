#!/usr/bin/env bash
# Read current plugin version from marketplace.json and increment patch
set -euo pipefail

CURRENT=$(jq -r '.plugins[0].version' .claude-plugin/marketplace.json)
MAJOR=$(echo "$CURRENT" | cut -d. -f1)
MINOR=$(echo "$CURRENT" | cut -d. -f2)
PATCH=$(echo "$CURRENT" | cut -d. -f3)
NEW_PATCH=$((PATCH + 1))
printf '%s' "${MAJOR}.${MINOR}.${NEW_PATCH}"
