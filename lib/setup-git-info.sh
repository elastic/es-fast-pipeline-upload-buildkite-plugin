#!/bin/bash

set -euo pipefail

# TODO do we need to help buildkite resolve the commit?

REPO="${BUILDKITE_PULL_REQUEST_REPO:-}"
if [[ -z "$REPO" ]]; then
  REPO="$BUILDKITE_REPO"
fi

if [[ "$REPO" =~ github\.com[:/](.+)/(.+)\.git ]]; then
  ES_BUILDKITE_REPO_OWNER="${BASH_REMATCH[1]}"
  ES_BUILDKITE_REPO_NAME="${BASH_REMATCH[2]}"
else
  echo "Error: Could not parse '$REPO' into owner and repo" >&2
  exit 1
fi

# BUILDKITE_BRANCH might have "REPO_OWNER:" as a prefix (particularly for PRs), so we should remove it
BRANCH="${BUILDKITE_BRANCH#"${ES_BUILDKITE_REPO_OWNER}":}"

ES_BUILDKITE_REF="$BUILDKITE_COMMIT"
if [[ ! "$ES_BUILDKITE_REF" =~ ^[0-9a-f]{40}$ ]]; then
  if [[ "$ES_BUILDKITE_REF" == "HEAD" ]]; then
    ES_BUILDKITE_REF="heads/$BRANCH"
  fi

  echo "Getting sha for '$ES_BUILDKITE_REF'..."
  echo "https://api.github.com/repos/$ES_BUILDKITE_REPO_OWNER/$ES_BUILDKITE_REPO_NAME/git/ref/$ES_BUILDKITE_REF"
  REF_RESPONSE=$(curl -sSfH "Authorization: token $VAULT_GITHUB_TOKEN" \
    -H "Accept: application/vnd.github+json" \
    "https://api.github.com/repos/$ES_BUILDKITE_REPO_OWNER/$ES_BUILDKITE_REPO_NAME/git/ref/$ES_BUILDKITE_REF"
  )
  ES_BUILDKITE_REF=$(echo "$REF_RESPONSE" | jq -r .object.sha)
fi

buildkite-agent meta-data set buildkite:git:commit "$ES_BUILDKITE_REF" || true

export ES_BUILDKITE_REF
export ES_BUILDKITE_REPO_OWNER
export ES_BUILDKITE_REPO_NAME
