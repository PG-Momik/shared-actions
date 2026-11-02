#!/usr/bin/env bash
# Tags the release branch tip as a version tag and starts the production deploy on that tag.
set -euo pipefail

gh_cli() { "${GH_BIN:-gh}" "$@"; }

if [[ ! $RELEASE_BRANCH =~ ^release/(20[0-9]{2}\.[0-9]{2}\.[0-9]+(\.[0-9]+)?|[0-9]{1,3}\.[0-9]+\.[0-9]+(\.[0-9]+)?)$ ]]; then
  echo "Not a release branch: $RELEASE_BRANCH" >&2
  exit 1
fi
tag=v${RELEASE_BRANCH#release/}

git fetch --tags --force --quiet 2>/dev/null || true
tip=$(git rev-parse --verify "refs/remotes/origin/$RELEASE_BRANCH^{commit}" 2>/dev/null || git rev-parse --verify "refs/heads/$RELEASE_BRANCH^{commit}")

# Deployments come newest first. The first one with a success status is the last good staging deploy.
staged_sha=
while read -r id sha; do
  if gh_cli api "repos/$GITHUB_REPOSITORY/deployments/$id/statuses" | jq -e 'any(.[]; .state == "success")' >/dev/null; then
    staged_sha=$sha
    break
  fi
done < <(gh_cli api "repos/$GITHUB_REPOSITORY/deployments?environment=staging&per_page=10" | jq -r '.[] | "\(.id) \(.sha)"')

if [[ $staged_sha != "$tip" ]]; then
  echo "staging has not deployed $tip" >&2
  exit 1
fi

existing=$(git rev-parse -q --verify "refs/tags/$tag^{commit}" || true)
if [[ -n $existing && $existing != "$tip" ]]; then
  echo "Tag $tag already exists on a different commit ($existing)" >&2
  exit 1
fi
if [[ -z $existing ]]; then
  git tag "$tag" "$tip"
  git push origin "refs/tags/$tag"
else
  echo "Tag $tag already exists on $tip, restarting the deploy only"
fi

# Runner clock can be a few seconds ahead of GitHub's, so start the search window early.
since=$(( $(date +%s) - 10 ))
dispatched_at=$(date -u -d "@$since" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -r "$since" +%Y-%m-%dT%H:%M:%SZ)
gh_cli workflow run "$DEPLOY_WORKFLOW" --ref "$tag"

{
  echo "tag=$tag"
  echo "sha=$tip"
  echo "dispatched_at=$dispatched_at"
} >> "$GITHUB_OUTPUT"
echo "Shipped $tag ($tip)"
