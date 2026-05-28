#!/usr/bin/env bash
# Update the resolved plugin's Claude marketplace version and Codex manifest version.
# Does NOT touch .metadata.version — plugins bump independently.
set -euo pipefail

SKILL="{{.states.resolve_skill.Output}}"
NEW_VERSION="{{.states.read_and_bump_version.Output}}"
CLAUDE_MARKETPLACE=".claude-plugin/marketplace.json"
CODEX_MANIFEST="${SKILL}/.codex-plugin/plugin.json"

jq --arg s "$SKILL" --arg v "$NEW_VERSION" \
  '(.plugins[] | select(.name==$s)).version = $v' \
  "$CLAUDE_MARKETPLACE" > "${CLAUDE_MARKETPLACE}.tmp"
mv "${CLAUDE_MARKETPLACE}.tmp" "$CLAUDE_MARKETPLACE"

if [ ! -f "$CODEX_MANIFEST" ]; then
  echo "Missing Codex plugin manifest: $CODEX_MANIFEST" >&2
  exit 1
fi

jq --arg v "$NEW_VERSION" \
  '.version = $v' \
  "$CODEX_MANIFEST" > "${CODEX_MANIFEST}.tmp"
mv "${CODEX_MANIFEST}.tmp" "$CODEX_MANIFEST"

echo "Updated ${SKILL} to version ${NEW_VERSION} in ${CLAUDE_MARKETPLACE} and ${CODEX_MANIFEST}"
