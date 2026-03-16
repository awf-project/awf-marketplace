#!/usr/bin/env bash
# Create or checkout the update branch based on update type and PR number
set -euo pipefail

case "{{.inputs.update_type}}" in
  bugfix)   PREFIX="fix" ;;
  breaking) PREFIX="breaking" ;;
  docs)     PREFIX="docs" ;;
  *)        PREFIX="feature" ;;
esac

BRANCH="${PREFIX}/awf-skill-pr-{{.inputs.pull_request}}"

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
