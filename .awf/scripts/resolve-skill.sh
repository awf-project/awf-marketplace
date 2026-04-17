#!/usr/bin/env bash
# Resolve skill name from workflow inputs.repository using skill-map.json
set -euo pipefail

MAP_FILE=".awf/scripts/skill-map.json"
REPO="{{.inputs.repository}}"

if [ ! -f "$MAP_FILE" ]; then
  echo "Missing skill map: $MAP_FILE" >&2
  exit 1
fi

SKILL=$(jq -r --arg r "$REPO" '.[$r] // empty' "$MAP_FILE")

if [ -z "$SKILL" ]; then
  echo "Unknown repository: $REPO" >&2
  echo "Known repositories: $(jq -r 'keys | join(", ")' "$MAP_FILE")" >&2
  exit 1
fi

printf '%s' "$SKILL"
