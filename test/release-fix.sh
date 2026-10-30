#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
TMP=$(mktemp -d)
git init -q --bare "$TMP/remote.git"
git init -q "$TMP/work"
cd "$TMP/work"
git config user.name Demo
git config user.email demo@local
echo base > file
git add file
git commit -q -m base
git branch -M main
git remote add origin "$TMP/remote.git"
git push -q origin main
git checkout -q -b release/2026.11.1
git push -q origin release/2026.11.1
git checkout -q main
echo fixed >> file
git commit -q -am fix
fix=$(git rev-parse HEAD)
git push -q origin main
git checkout -q -b feature/xp-207 release/2026.11.1
git cherry-pick -x "$fix" >/dev/null
BASE_BRANCH=release/2026.11.1 TRUNK_BRANCH=main bash "$ROOT/actions/check-release-fix/run.sh"
echo unrelated > other
git add other
git commit -q -m unrelated
if BASE_BRANCH=release/2026.11.1 TRUNK_BRANCH=main bash "$ROOT/actions/check-release-fix/run.sh"; then
  echo 'Release-only change was accepted' >&2
  exit 1
fi
echo 'Release fix tests passed.'
