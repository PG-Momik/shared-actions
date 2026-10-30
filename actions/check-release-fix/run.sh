#!/usr/bin/env bash
set -euo pipefail

base=${BASE_BRANCH:?}
trunk=${TRUNK_BRANCH:-main}
[[ $base == release/* && $trunk =~ ^[A-Za-z0-9._/-]+$ ]] || { echo 'Invalid branch' >&2; exit 1; }
git fetch --quiet origin "+refs/heads/$base:refs/remotes/origin/$base" "+refs/heads/$trunk:refs/remotes/origin/$trunk"
commits=$(git rev-list "origin/$base..HEAD")
[[ -n $commits ]] || { echo 'Release PR has no commits' >&2; exit 1; }
while IFS= read -r commit; do
  parents=$(git rev-list --parents -n 1 "$commit")
  [[ $(wc -w <<< "$parents") -eq 2 ]] || { echo 'Release PR contains a merge commit' >&2; exit 1; }
done <<< "$commits"
if git cherry -v "origin/$trunk" HEAD "origin/$base" | grep -q '^+'; then
  echo 'Fix main first, then cherry-pick to the release branch' >&2
  exit 1
fi
echo 'Every release patch is on main.'
