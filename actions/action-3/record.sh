#!/usr/bin/env bash
set -euo pipefail

if [[ ${EXISTING_TAG:-false} == true ]]; then
  [[ ${GIT_REF:-} == refs/tags/v* ]] || { echo 'Expected a release tag' >&2; exit 1; }
  tag=${GIT_REF#refs/tags/}
  echo "Recording successful production deploy for $tag"
else
  git fetch --tags --force --quiet
  git config user.name 'github-actions[bot]'
  git config user.email '41898282+github-actions[bot]@users.noreply.github.com'
  base="v$(date -u +'%Y.%m.%d')"
  tag=$base
  n=1
  while git rev-parse -q --verify "refs/tags/$tag" >/dev/null; do
    tag="$base.$n"
    n=$((n + 1))
  done
  git tag -a "$tag" -m "Release $tag"
  git push origin "$tag"
  echo "Cut $tag"
fi
echo "tag=$tag" >> "$GITHUB_OUTPUT"
