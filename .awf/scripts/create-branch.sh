#!/usr/bin/env bash
# Create or checkout the update branch based on skill, update type, and PR number
set -euo pipefail

SKILL="{{.states.resolve_skill.Output}}"

case "{{.inputs.update_type}}" in
  bugfix)   PREFIX="fix" ;;
  breaking) PREFIX="breaking" ;;
  docs)     PREFIX="docs" ;;
  *)        PREFIX="feature" ;;
esac

BRANCH="${PREFIX}/${SKILL}-skill-pr-{{.inputs.pull_request}}"

CURRENT=$(git branch --show-current)
if [ "$CURRENT" = "$BRANCH" ]; then
  echo "$BRANCH"
  exit 0
fi

if git show-ref --verify --quiet "refs/heads/$BRANCH"; then
  git checkout "$BRANCH"
else
  git checkout -b "$BRANCH"
fi

echo "$BRANCH"
