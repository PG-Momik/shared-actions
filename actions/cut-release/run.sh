#!/usr/bin/env bash
set -euo pipefail

git fetch --quiet origin '+refs/heads/*:refs/remotes/origin/*' --tags
scheme=${VERSION_SCHEME:-calver}
hotfix=${HOTFIX_FROM_TAG:-}
patch_of=${PATCH_OF:-}
source_ref="origin/${FROM_REF:-main}"
refs=$(git for-each-ref --format='%(refname:short)' refs/remotes/origin refs/tags)

if [[ -n $hotfix ]]; then
  [[ $scheme == calver && $hotfix =~ ^v([0-9]{4}\.[0-9]{2}\.[0-9]+)(\.[0-9]+)?$ ]] || { echo 'Invalid hotfix tag' >&2; exit 1; }
  base=${BASH_REMATCH[1]}
  source_ref="refs/tags/$hotfix"
  if [[ -n $patch_of ]]; then
    [[ $patch_of =~ ^v([0-9]{4}\.[0-9]{2}\.[0-9]+)$ ]] || { echo 'Invalid patch-of tag' >&2; exit 1; }
    base=${BASH_REMATCH[1]}
    git rev-parse -q --verify "refs/tags/$patch_of" >/dev/null || { echo 'Patch-of tag does not exist' >&2; exit 1; }
  fi
  highest=0
  while IFS= read -r ref; do
    if [[ $ref =~ ^(origin/)?release/${base}\.([0-9]+)$ || $ref =~ ^v${base}\.([0-9]+)$ ]]; then
      patch=${BASH_REMATCH[2]:-${BASH_REMATCH[1]}}
      (( 10#$patch > highest )) && highest=$((10#$patch))
    fi
  done <<< "$refs"
  branch="release/$base.$((highest + 1))"
elif [[ $scheme == calver ]]; then
  month=${CUT_MONTH:-$(date -u +%Y.%m)}
  [[ $month =~ ^[0-9]{4}\.[0-9]{2}$ ]] || { echo 'Invalid release month' >&2; exit 1; }
  highest=0
  while IFS= read -r ref; do
    if [[ $ref =~ ^(origin/)?release/${month}\.([0-9]+)(\.[0-9]+)?$ ]]; then
      number=${BASH_REMATCH[2]}
    elif [[ $ref =~ ^v${month}\.([0-9]+)(\.[0-9]+)?$ ]]; then
      number=${BASH_REMATCH[1]}
    else
      continue
    fi
    (( 10#$number > highest )) && highest=$((10#$number))
  done <<< "$refs"
  branch="release/$month.$((highest + 1))"
elif [[ $scheme == semver ]]; then
  major=0 minor=0 patch=0
  while IFS= read -r ref; do
    if [[ $ref =~ ^(origin/)?release/([0-9]{1,3})\.([0-9]+)\.([0-9]+)$ ]]; then
      a=${BASH_REMATCH[2]} b=${BASH_REMATCH[3]} c=${BASH_REMATCH[4]}
    elif [[ $ref =~ ^v([0-9]{1,3})\.([0-9]+)\.([0-9]+)$ ]]; then
      a=${BASH_REMATCH[1]} b=${BASH_REMATCH[2]} c=${BASH_REMATCH[3]}
    else
      continue
    fi
    if (( 10#$a > major || (10#$a == major && 10#$b > minor) || (10#$a == major && 10#$b == minor && 10#$c > patch) )); then
      major=$((10#$a)) minor=$((10#$b)) patch=$((10#$c))
    fi
  done <<< "$refs"
  case ${SEMVER_BUMP:-patch} in
    major) major=$((major + 1)); minor=0; patch=0 ;;
    minor) minor=$((minor + 1)); patch=0 ;;
    patch) patch=$((patch + 1)) ;;
    *) echo 'Invalid semver bump' >&2; exit 1 ;;
  esac
  branch="release/$major.$minor.$patch"
else
  echo 'Invalid version scheme' >&2
  exit 1
fi

sha=$(git rev-parse --verify "$source_ref^{commit}")
if git ls-remote --exit-code origin "refs/heads/$branch" >/dev/null 2>&1; then
  echo "Release branch already exists: $branch" >&2
  exit 1
fi
git push origin "$sha:refs/heads/$branch"
echo "release-branch=$branch" >> "$GITHUB_OUTPUT"
echo "from-sha=$sha" >> "$GITHUB_OUTPUT"
gh workflow run "${DEPLOY_WORKFLOW:?}" --ref "$branch"
