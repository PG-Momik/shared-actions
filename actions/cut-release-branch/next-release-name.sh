#!/usr/bin/env bash
# Prints release_branch=<name> and from_sha=<sha> for the next release branch.
set -euo pipefail

scheme=${VERSION_SCHEME:-calver}
from_ref=${FROM_REF:-main}
hotfix_tag=${HOTFIX_FROM_TAG:-}
patch_of=${PATCH_OF:-}
bump=${SEMVER_BUMP:-minor}

refs=$(git for-each-ref --format='%(refname)' refs/heads refs/remotes/origin refs/tags | sed -E 's#^refs/(heads|remotes/origin|tags)/##')
tags=$(git for-each-ref --format='%(refname:strip=2)' refs/tags)

if [[ -n $patch_of && -z $hotfix_tag ]]; then
  echo 'patch-of needs hotfix-from-tag (the tag to roll back to)' >&2
  exit 1
fi

if [[ -n $hotfix_tag ]]; then
  git rev-parse -q --verify "refs/tags/$hotfix_tag" >/dev/null || { echo "Tag not found: $hotfix_tag" >&2; exit 1; }
  if [[ -n $patch_of ]]; then
    git rev-parse -q --verify "refs/tags/$patch_of" >/dev/null || { echo "Tag not found: $patch_of" >&2; exit 1; }
  fi
  # A hotfix of a hotfix stays in the same family (first three parts), never a fifth part.
  family=$(cut -d. -f1-3 <<<"${patch_of:-$hotfix_tag}")
  family=${family#v}
  last=$(sed -nE "s#^(release/|v)${family//./\\.}\.([0-9]+)\$#\2#p" <<<"$refs" | sort -n | tail -n1)
  name=release/$family.$((${last:-0} + 1))
  from_sha=$(git rev-parse "refs/tags/$hotfix_tag^{commit}")
elif [[ $scheme == semver ]]; then
  latest=$(grep -Ex 'v[0-9]+\.[0-9]+\.[0-9]+' <<<"$tags" | sed 's/^v//' | sort -V | tail -n1 || true)
  IFS=. read -r major minor patch <<<"${latest:-0.0.0}"
  case $bump in
    major) major=$((major + 1)); minor=0; patch=0 ;;
    minor) minor=$((minor + 1)); patch=0 ;;
    patch) patch=$((patch + 1)) ;;
    *) echo "Unknown semver-bump: $bump" >&2; exit 1 ;;
  esac
  name=release/$major.$minor.$patch
fi

if [[ -z ${name:-} ]]; then
  ym=${RELEASE_YM:-$(date -u +%Y.%m)}
  # Highest existing number plus one, so a deleted branch or skipped number never collides.
  last=$(sed -nE "s#^(release/|v)?${ym//./\\.}\.([0-9]+)(\.[0-9]+)?\$#\2#p" <<<"$refs" | sort -n | tail -n1)
  name=release/$ym.$((${last:-0} + 1))
fi

if [[ -z ${from_sha:-} ]]; then
  from_sha=$(git rev-parse --verify -q "refs/remotes/origin/$from_ref^{commit}" || git rev-parse --verify "$from_ref^{commit}")
fi

if grep -Fxq "$name" <<<"$refs"; then
  echo "Branch already exists: $name" >&2
  exit 1
fi

echo "release_branch=$name"
echo "from_sha=$from_sha"
