#!/usr/bin/env bash
set -euo pipefail

base=${1:?release branch required}
trunk=${2:-main}
if [[ $base != release/* ]]; then
  echo 'Expected a release branch' >&2
  exit 1
fi

if [[ -n $(git rev-list --merges "origin/$base..HEAD") ]]; then
  echo 'Release fixes must not contain merge commits' >&2
  exit 1
fi

# git cherry marks commits whose patch is missing from trunk with a leading +
if git cherry "origin/$trunk" HEAD "origin/$base" | grep -q '^+'; then
  echo "Release fix must land on $trunk first, then git cherry-pick -x it onto $base" >&2
  exit 1
fi
