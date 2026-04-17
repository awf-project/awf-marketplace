#!/usr/bin/env bash
# Read current version of the resolved plugin and increment patch
set -euo pipefail

SKILL="{{.states.resolve_skill.Output}}"

CURRENT=$(jq -r --arg s "$SKILL" \
  '.plugins[] | select(.name==$s) | .version' \
  .claude-plugin/marketplace.json)

if [ -z "$CURRENT" ]; then
  echo "Plugin not found in marketplace.json: $SKILL" >&2
  exit 1
fi

MAJOR=$(echo "$CURRENT" | cut -d. -f1)
MINOR=$(echo "$CURRENT" | cut -d. -f2)
PATCH=$(echo "$CURRENT" | cut -d. -f3)
NEW_PATCH=$((PATCH + 1))
printf '%s' "${MAJOR}.${MINOR}.${NEW_PATCH}"
