#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
TMP=$(mktemp -d)
mkdir -p "$TMP/bin"
cat > "$TMP/bin/aws" <<'EOF'
#!/usr/bin/env bash
echo token
EOF
cat > "$TMP/bin/crane" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$CRANE_CALLS"
case $1 in
  auth) cat >/dev/null ;;
  digest)
    if [[ $2 == staging/* ]]; then echo sha256:staged; exit 0; fi
    if [[ -f $COPIED ]]; then echo sha256:staged; exit 0; fi
    echo 'not found' >&2; exit 1 ;;
  copy) touch "$COPIED" ;;
esac
EOF
chmod +x "$TMP/bin/aws" "$TMP/bin/crane"
export PATH="$TMP/bin:$PATH" CRANE_CALLS="$TMP/crane-calls" COPIED="$TMP/copied"
SOURCE_REGISTRY=staging TARGET_REGISTRY=prod REPOSITORY=demo SOURCE_TAG=abc123 TARGET_TAGS=v2026.11.1,latest REGION=us-east-1 bash "$ROOT/actions/promote-image/run.sh"
grep -qx 'copy staging/demo@sha256:staged prod/demo:abc123' "$CRANE_CALLS"
grep -qx 'tag prod/demo:abc123 v2026.11.1' "$CRANE_CALLS"
grep -qx 'tag prod/demo:abc123 latest' "$CRANE_CALLS"
before=$(grep -c '^copy ' "$CRANE_CALLS")
SOURCE_REGISTRY=staging TARGET_REGISTRY=prod REPOSITORY=demo SOURCE_TAG=abc123 TARGET_TAGS=v2026.11.1,latest REGION=us-east-1 bash "$ROOT/actions/promote-image/run.sh"
after=$(grep -c '^copy ' "$CRANE_CALLS")
[[ $before == "$after" ]]
echo 'Promotion tests passed.'
