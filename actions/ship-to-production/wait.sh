#!/usr/bin/env bash
# Finds the deploy run that ship.sh started (gh workflow run does not return its id) and waits for it.
set -euo pipefail

gh_cli() { "${GH_BIN:-gh}" "$@"; }

deadline=$((SECONDS + ${WAIT_TIMEOUT:-300}))
run_id=
while [[ -z $run_id ]]; do
  run_id=$(gh_cli run list --workflow "$DEPLOY_WORKFLOW" --event workflow_dispatch --branch "$TAG" --json databaseId,createdAt |
    jq -r --arg t "$DISPATCHED_AT" '[.[] | select(.createdAt >= $t)] | sort_by(.createdAt) | first | .databaseId // empty')
  [[ -n $run_id ]] && break
  if (( SECONDS >= deadline )); then
    echo "No $DEPLOY_WORKFLOW run for $TAG appeared after $DISPATCHED_AT" >&2
    exit 1
  fi
  sleep "${POLL_INTERVAL:-5}"
done

echo "deploy_run_url=${GITHUB_SERVER_URL:-https://github.com}/$GITHUB_REPOSITORY/actions/runs/$run_id" >> "$GITHUB_OUTPUT"
gh_cli run watch "$run_id" --exit-status
