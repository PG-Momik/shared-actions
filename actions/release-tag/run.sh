#!/usr/bin/env bash
set -euo pipefail

branch=${RELEASE_BRANCH:?}
[[ $branch =~ ^release/([0-9]+\.[0-9]+\.[0-9]+(\.[0-9]+)?)$ ]] || { echo 'Invalid release branch' >&2; exit 1; }
tag="v${BASH_REMATCH[1]}"
git fetch --quiet origin '+refs/heads/*:refs/remotes/origin/*' --tags
sha=$(git rev-parse --verify "refs/remotes/origin/$branch^{commit}")
if git ls-remote --exit-code origin "refs/tags/$tag" >/dev/null 2>&1; then
  echo "Release tag already exists: $tag" >&2
  exit 1
fi
crane digest "${STAGING_REGISTRY:?}/${REPOSITORY:?}:$sha" >/dev/null
git config user.name 'github-actions[bot]'
git config user.email '41898282+github-actions[bot]@users.noreply.github.com'
git tag -a "$tag" "$sha" -m "Release $tag approved by ${GITHUB_ACTOR:-unknown}"
git push origin "refs/tags/$tag"
echo "tag=$tag" >> "$GITHUB_OUTPUT"
echo "sha=$sha" >> "$GITHUB_OUTPUT"
gh workflow run "${DEPLOY_WORKFLOW:?}" --ref "$tag"
