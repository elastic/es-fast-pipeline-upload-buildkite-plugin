#!/bin/bash

set -euo pipefail

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

# https://github.com/buildkite/agent/blob/main/internal/job/checkout.go#L817
# Use github api to build a git log output similar to what buildkite is looking for

COMMIT_JSON=$(curl -sSfH "Authorization: token $VAULT_GITHUB_TOKEN" \
  -H "Accept: application/vnd.github+json" \
  "https://api.github.com/repos/$ES_BUILDKITE_REPO_OWNER/$ES_BUILDKITE_REPO_NAME/git/commits/$ES_BUILDKITE_REF"
)

AUTHOR_NAME=$(echo "$COMMIT_JSON" | jq -r .author.name)
AUTHOR_EMAIL=$(echo "$COMMIT_JSON" | jq -r .author.email)
COMMIT_MESSAGE=$(echo "$COMMIT_JSON" | jq -r .message)

COMMIT_METADATA_FOR_BK=$(cat <<EOF
commit ${ES_BUILDKITE_REF}
abbrev-commit ${ES_BUILDKITE_REF:0:10}
Author: ${AUTHOR_NAME} <${AUTHOR_EMAIL}>

    ${COMMIT_MESSAGE}
EOF
)

buildkite-agent meta-data set buildkite:git:commit "$COMMIT_METADATA_FOR_BK" || true

export ES_BUILDKITE_REF
export ES_BUILDKITE_REPO_OWNER
export ES_BUILDKITE_REPO_NAME
