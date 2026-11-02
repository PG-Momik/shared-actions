#!/usr/bin/env bash
# Creates or publishes the GitHub Release for a version. The notes start at the last successful
# production deployment, not the nearest tag, because cherry-picks break ancestry.
set -euo pipefail

gh_cli() { "${GH_BIN:-gh}" "$@"; }

mode=${GITHUB_RELEASE:?}
ref_name=${GITHUB_REF_NAME:?}
repo=${GITHUB_REPOSITORY:?}

if [[ $ref_name == release/* ]]; then
  tag=v${ref_name#release/}
  target=$ref_name
elif [[ $ref_name =~ ^v[0-9] ]]; then
  tag=$ref_name
  target=$(git rev-parse HEAD)
else
  echo "github-release runs on a release branch or a version tag, not $ref_name" >&2
  exit 1
fi
head_sha=$(git rev-parse HEAD)

# Deployments come newest first. The current deploy may already be successful, so skip HEAD itself.
base_sha=
while read -r id sha; do
  [[ $sha == "$head_sha" ]] && continue
  if gh_cli api "repos/$repo/deployments/$id/statuses" | jq -e 'any(.[]; .state == "success")' >/dev/null; then
    base_sha=$sha
    break
  fi
done < <(gh_cli api "repos/$repo/deployments?environment=production&per_page=10" | jq -r '.[] | "\(.id) \(.sha)"')

if [[ -z $base_sha ]] || ! git cat-file -e "$base_sha^{commit}" 2>/dev/null; then
  echo 'No successful production deployment is reachable to use as the release notes base' >&2
  exit 1
fi

body=$(git log "$base_sha..$head_sha" --format='- %s (%h)')

release_id=$(gh_cli api "repos/$repo/releases?per_page=100" | jq -r --arg t "$tag" '[.[] | select(.tag_name == $t)] | first | .id // empty')

if [[ $mode == draft ]]; then
  if [[ -n $release_id ]]; then
    gh_cli api -X PATCH "repos/$repo/releases/$release_id" -f target_commitish="$target" -f body="$body" -F draft=true >/dev/null
  else
    gh_cli api -X POST "repos/$repo/releases" -f tag_name="$tag" -f target_commitish="$target" -f name="$tag" -f body="$body" -F draft=true >/dev/null
  fi
else
  # make_latest is explicit so a rollback or an older-month hotfix still becomes latest.
  if [[ -n $release_id ]]; then
    gh_cli api -X PATCH "repos/$repo/releases/$release_id" -F draft=false -f make_latest=true >/dev/null
  else
    gh_cli api -X POST "repos/$repo/releases" -f tag_name="$tag" -f name="$tag" -f body="$body" -F draft=false -f make_latest=true >/dev/null
  fi
fi

echo "base_ref=$base_sha" >> "$GITHUB_OUTPUT"
echo "tag=$tag" >> "$GITHUB_OUTPUT"
echo "name=${tag#v}" >> "$GITHUB_OUTPUT"
echo "GitHub release $tag ($mode), notes from $base_sha"
