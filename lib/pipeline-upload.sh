#!/bin/bash

set -euo pipefail

GH_URL="https://api.github.com/repos/${ES_BUILDKITE_REPO_OWNER}/${ES_BUILDKITE_REPO_NAME}/contents/$PIPELINE_FILE?ref=${ES_BUILDKITE_REF}"

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
