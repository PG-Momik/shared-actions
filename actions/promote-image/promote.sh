#!/usr/bin/env bash
set -euo pipefail

ecr_password() {
  if [[ -n ${REGION:-} ]]; then
    aws --region "$REGION" ecr get-login-password
  else
    aws ecr get-login-password
  fi
}

login() {
  ecr_password | crane auth login "$1" -u AWS --password-stdin
}

login "$SOURCE_REGISTRY"
if [[ "$TARGET_REGISTRY" != "$SOURCE_REGISTRY" ]]; then
  login "$TARGET_REGISTRY"
fi

source_ref=$SOURCE_REGISTRY/$REPOSITORY:$SOURCE_TAG
if ! digest=$(crane digest "$source_ref" 2>&1); then
  echo "::error::No image tagged $SOURCE_TAG in $SOURCE_REGISTRY/$REPOSITORY. Was this commit deployed to staging?"
  # crane's own message tells a missing image apart from a denied cross-account pull.
  echo "$digest" >&2
  exit 1
fi

# Skip the copy when prod already has this digest, so a re-run is quick and safe.
target_ref=$TARGET_REGISTRY/$REPOSITORY:$SOURCE_TAG
promoted=false
if target_digest=$(crane digest "$target_ref" 2>/dev/null) && [[ $target_digest == "$digest" ]]; then
  promoted=true
  echo "Already promoted: $target_ref has digest $digest, skipping the copy"
fi

IFS=, read -ra tags <<<"$TARGET_TAGS"
for tag in "${tags[@]}"; do
  tag=${tag//[[:space:]]/}
  [[ -z $tag ]] && continue
  if [[ $promoted == true ]]; then
    [[ $tag != "$SOURCE_TAG" ]] && crane tag "$target_ref" "$tag"
  else
    crane copy "$source_ref" "$TARGET_REGISTRY/$REPOSITORY:$tag"
  fi
  echo "Wrote $TARGET_REGISTRY/$REPOSITORY:$tag"
done
echo "Source digest: $digest"
