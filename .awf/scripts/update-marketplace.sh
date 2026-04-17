#!/usr/bin/env bash
# Update the resolved plugin's version in marketplace.json
# Does NOT touch .metadata.version — plugins bump independently.
set -euo pipefail

SKILL="{{.states.resolve_skill.Output}}"
NEW_VERSION="{{.states.read_and_bump_version.Output}}"

jq --arg s "$SKILL" --arg v "$NEW_VERSION" \
  '(.plugins[] | select(.name==$s)).version = $v' \
  .claude-plugin/marketplace.json > .claude-plugin/marketplace.json.tmp
mv .claude-plugin/marketplace.json.tmp .claude-plugin/marketplace.json
echo "Updated ${SKILL} to version ${NEW_VERSION}"
