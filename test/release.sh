#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
TMP=$(mktemp -d)
git init -q --bare "$TMP/remote.git"
git init -q "$TMP/work"
git -C "$TMP/work" config user.name Demo
git -C "$TMP/work" config user.email demo@local
git -C "$TMP/work" commit -q --allow-empty -m base
git -C "$TMP/work" branch -M main
git -C "$TMP/work" remote add origin "$TMP/remote.git"
git -C "$TMP/work" push -q origin main
mkdir -p "$TMP/bin"
cat > "$TMP/bin/gh" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$GH_CALLS"
EOF
cat > "$TMP/bin/crane" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$CRANE_CALLS"
if [[ $1 == digest && ${CRANE_MISSING:-false} == true ]]; then exit 1; fi
echo sha256:staged
EOF
chmod +x "$TMP/bin/gh" "$TMP/bin/crane"
export PATH="$TMP/bin:$PATH" GITHUB_OUTPUT="$TMP/output" GH_CALLS="$TMP/gh-calls" CRANE_CALLS="$TMP/crane-calls"

(
  cd "$TMP/work"
  : > "$GITHUB_OUTPUT"
  VERSION_SCHEME=calver FROM_REF=main HOTFIX_FROM_TAG= PATCH_OF= DEPLOY_WORKFLOW=workflow-1.yml CUT_MONTH=2026.11 bash "$ROOT/actions/cut-release/run.sh" >/dev/null
  git checkout -q -b release/2026.11.1 main
  git commit -q --allow-empty -m staged
  git push -q origin release/2026.11.1
  if CRANE_MISSING=true RELEASE_BRANCH=release/2026.11.1 STAGING_REGISTRY=staging REPOSITORY=demo DEPLOY_WORKFLOW=workflow-1.yml bash "$ROOT/actions/release-tag/run.sh"; then
    echo 'Missing staging image was accepted' >&2
    exit 1
  fi
  if git ls-remote --exit-code origin refs/tags/v2026.11.1 >/dev/null 2>&1; then
    echo 'Tag was pushed without a staging image' >&2
    exit 1
  fi
  : > "$GITHUB_OUTPUT"
  RELEASE_BRANCH=release/2026.11.1 STAGING_REGISTRY=staging REPOSITORY=demo DEPLOY_WORKFLOW=workflow-1.yml GITHUB_ACTOR=Demo bash "$ROOT/actions/release-tag/run.sh"
  grep -qx 'tag=v2026.11.1' "$GITHUB_OUTPUT"
  git ls-remote --tags origin refs/tags/v2026.11.1 | grep -q v2026.11.1
  grep -qx 'workflow run workflow-1.yml --ref v2026.11.1' "$GH_CALLS"
  if RELEASE_BRANCH=release/2026.11.1 STAGING_REGISTRY=staging REPOSITORY=demo DEPLOY_WORKFLOW=workflow-1.yml bash "$ROOT/actions/release-tag/run.sh"; then
    echo 'Existing tag was accepted' >&2
    exit 1
  fi
  git tag v2026.10.4 main
  git push -q origin v2026.10.4
  : > "$GITHUB_OUTPUT"
  VERSION_SCHEME=calver HOTFIX_FROM_TAG=v2026.10.4 PATCH_OF= DEPLOY_WORKFLOW=workflow-1.yml bash "$ROOT/actions/cut-release/run.sh" >/dev/null
  grep -qx 'release-branch=release/2026.10.4.1' "$GITHUB_OUTPUT"
  : > "$GITHUB_OUTPUT"
  VERSION_SCHEME=calver HOTFIX_FROM_TAG=v2026.10.4 PATCH_OF=v2026.11.1 DEPLOY_WORKFLOW=workflow-1.yml bash "$ROOT/actions/cut-release/run.sh" >/dev/null
  grep -qx 'release-branch=release/2026.11.1.1' "$GITHUB_OUTPUT"
  git tag v1.2.3 main
  git push -q origin v1.2.3
  : > "$GITHUB_OUTPUT"
  VERSION_SCHEME=semver FROM_REF=main HOTFIX_FROM_TAG= PATCH_OF= SEMVER_BUMP=patch DEPLOY_WORKFLOW=workflow-1.yml bash "$ROOT/actions/cut-release/run.sh" >/dev/null
  grep -qx 'release-branch=release/1.2.4' "$GITHUB_OUTPUT"
  : > "$GITHUB_OUTPUT"
  EXISTING_TAG=true GIT_REF=refs/tags/v2026.11.1 bash "$ROOT/actions/action-3/record.sh"
  grep -qx 'tag=v2026.11.1' "$GITHUB_OUTPUT"
)

echo 'Release action tests passed.'
