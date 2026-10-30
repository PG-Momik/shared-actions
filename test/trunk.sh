#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
TMP=$(mktemp -d)
export GITHUB_OUTPUT="$TMP/output"

expect_output() {
  local expected=$1
  grep -qx "$expected" "$GITHUB_OUTPUT"
}

: > "$GITHUB_OUTPUT"
TRUNK_BASED=true VERSION_SCHEME=calver GIT_REF=refs/heads/main bash "$ROOT/actions/action-1/resolve.sh"
expect_output environment=dev

: > "$GITHUB_OUTPUT"
TRUNK_BASED=true VERSION_SCHEME=calver GIT_REF=refs/heads/release/2026.11.1.2 bash "$ROOT/actions/action-1/resolve.sh"
expect_output environment=staging

: > "$GITHUB_OUTPUT"
TRUNK_BASED=true VERSION_SCHEME=calver GIT_REF=refs/tags/v2026.11.1.2 bash "$ROOT/actions/action-1/resolve.sh"
expect_output environment=production
expect_output release-branch=release/2026.11.1.2

if TRUNK_BASED=true VERSION_SCHEME=semver GIT_REF=refs/tags/v2026.11.1 bash "$ROOT/actions/action-1/resolve.sh"; then
  echo 'CalVer tag was accepted as SemVer' >&2
  exit 1
fi

if TRUNK_BASED=true VERSION_SCHEME=calver GIT_REF=refs/heads/typo bash "$ROOT/actions/action-1/resolve.sh"; then
  echo 'Unknown trunk ref was accepted' >&2
  exit 1
fi

: > "$GITHUB_OUTPUT"
TRUNK_BASED=false USE_MASTER=false DEFAULT_ENVIRONMENT=dev GIT_REF=refs/heads/main bash "$ROOT/actions/action-1/resolve.sh"
expect_output environment=production

git init -q --bare "$TMP/remote.git"
git init -q "$TMP/work"
git -C "$TMP/work" config user.name Demo
git -C "$TMP/work" config user.email demo@local
git -C "$TMP/work" commit -q --allow-empty -m base
git -C "$TMP/work" branch -M main
git -C "$TMP/work" remote add origin "$TMP/remote.git"
git -C "$TMP/work" push -q origin main
git -C "$TMP/work" tag v2026.11.1
git -C "$TMP/work" push -q origin v2026.11.1
mkdir -p "$TMP/bin"
cat > "$TMP/bin/gh" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$GH_CALLS"
EOF
chmod +x "$TMP/bin/gh"
export GH_CALLS="$TMP/gh-calls"

(
  cd "$TMP/work"
  : > "$GITHUB_OUTPUT"
  PATH="$TMP/bin:$PATH" VERSION_SCHEME=calver FROM_REF=main HOTFIX_FROM_TAG= PATCH_OF= DEPLOY_WORKFLOW=workflow-1.yml CUT_MONTH=2026.11 bash "$ROOT/actions/cut-release/run.sh"
  expect_output release-branch=release/2026.11.2
  git ls-remote --exit-code origin refs/heads/release/2026.11.2 >/dev/null
  grep -qx 'workflow run workflow-1.yml --ref release/2026.11.2' "$GH_CALLS"
)

echo 'Trunk action tests passed.'
