#!/bin/bash

set -euo pipefail

# TODO do we need to help buildkite resolve the commit?

REPO="${BUILDKITE_PULL_REQUEST_REPO:-}"
if [[ -z "$REPO" ]]; then
  REPO="$BUILDKITE_REPO"
fi

if [[ "$REPO" =~ github\.com[:/](.+)/(.+)\.git ]]; then
  REPO_OWNER="${BASH_REMATCH[1]}"
  REPO_NAME="${BASH_REMATCH[2]}"
else
  echo "Error: Could not parse '$REPO' into owner and repo" >&2
  exit 1
fi

# BUILDKITE_BRANCH might have "REPO_OWNER:" as a prefix (particularly for PRs), so we should remove it
BRANCH="${BUILDKITE_BRANCH#"${REPO_OWNER}":}"

REF="$BUILDKITE_COMMIT"
if [[ ! "$REF" =~ ^[0-9a-f]{40}$ ]]; then
  if [[ "$REF" == "HEAD" ]]; then
    REF="heads/$BRANCH"
  fi

  echo "Getting sha for '$REF'..."
  echo "https://api.github.com/repos/$REPO_OWNER/$REPO_NAME/git/ref/$REF"
  REF_RESPONSE=$(curl -sSfH "Authorization: token $VAULT_GITHUB_TOKEN" \
    -H "Accept: application/vnd.github+json" \
    "https://api.github.com/repos/$REPO_OWNER/$REPO_NAME/git/ref/$REF"
  )
  REF=$(echo "$REF_RESPONSE" | jq -r .object.sha)
fi

buildkite-agent meta-data set buildkite:git:commit "$REF" || true

GH_URL="https://api.github.com/repos/${REPO_OWNER}/${REPO_NAME}/contents/$PIPELINE_FILE?ref=${REF}"

echo "Checking for pipeline file..."
echo "$GH_URL"

PIPELINE_YAML=$(curl -sSfH "Authorization: token $VAULT_GITHUB_TOKEN" \
  -H "Accept: application/vnd.github.v3.raw" \
  "$GH_URL"
)

echo ""
echo "Will upload this pipeline:"
echo "$PIPELINE_YAML"
echo ""

echo "$PIPELINE_YAML" | buildkite-agent pipeline upload
