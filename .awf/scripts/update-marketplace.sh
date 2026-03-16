#!/usr/bin/env bash
# Update plugins.version and metadata.version in marketplace.json
set -euo pipefail

NEW_VERSION="{{.states.read_and_bump_version.Output}}"
jq --arg v "$NEW_VERSION" '.plugins[0].version = $v | .metadata.version = $v' \
  .claude-plugin/marketplace.json > .claude-plugin/marketplace.json.tmp
mv .claude-plugin/marketplace.json.tmp .claude-plugin/marketplace.json
echo "Updated to version $NEW_VERSION"
